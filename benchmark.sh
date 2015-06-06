#!/bin/sh

# Set variables using ENV or defaults
concurrency=${c:=100}
timer=${t:="10s"}
limit=${l:=500}
api=${a:="http://127.0.0.1:8001/robots.txt"}

start_cassandra()
{
	# @todo allow for external Cassandra
	echo "Starting Cassandra"
	mkdir /var/run/cassandra
	/usr/sbin/cassandra -p /var/run/cassandra/cassandra.pid > /var/log/cassandra/start.log
	# @todo replace sleep with wait
	sleep 15
}

start_kong()
{
	echo "Starting Kong"
	kong start
	echo "Adding API"
	curl -s -X POST \
		--url http://localhost:8001/apis/ \
		--data 'name=benchmark' \
		--data 'target_url=http://127.0.0.1:8001/robots.txt' \
		--data 'public_dns=benchmark.api'

	echo "Adding Consumer"
	curl -s -X POST http://localhost:8001/consumers/ \
		--data "username=kong_user" 

	curl -s -X POST http://localhost:8001/consumers/kong_user/keyauth \
		--data "key=secure_token"
}

del_plugin()
{
	curl -s -X DELETE http://localhost:8001/apis/benchmark/plugins/"$1"
}

run_siege()
{
	local name="Kong 0.3.0"
	local host="benchmark.api"
	local proxy="http://localhost:8000"
	
	if [ -z "4" ]
	  then
	   	local header="-H \"$4\""
	   else
	    local header=""
	fi

	echo "$1 Siege $2 $3" 
	siege -m "$name $1 $2" -bl -c "$2" -t "$3" -H "host: $host" $header $proxy
}

run_benchmarks()
{

	run_siege "Warmup" $concurrency $timer

	run_siege "Vanilla" $concurrency $timer

	curl -s -X POST http://localhost:8001/apis/benchmark/plugins \
		--data "name=cors" \
		--data "value.origin=mockbin.com" \
		--data "value.methods=GET,POST" \
		--data "value.headers=Accept, Accept-Version, Content-Length" \
		--data "value.exposed_headers=X-Auth-Token" \
		--data "value.credentials=true" \
		--data "value.max_age=3600"

	run_siege "CORS" $concurrency $timer
	del_plugin cors

	curl -s -X POST http://localhost:8001/apis/benchmark/plugins \
		--data "name=request_transformer" \
		--data "value.add.headers=x-new-header:some_value, x-another-header:some_value" \
		--data "value.add.querystring=new-param:some_value, another-param:some_value" \
		--data "value.add.form=new-form-param:some_value, another-form-param:some_value" \
		--data "value.remove.headers=x-toremove, x-another-one" \
		--data "value.remove.querystring=param-toremove, param-another-one" \
		--data "value.remove.form=formparam-toremove, formparam-another-one"

	run_siege "Request Transformer" $concurrency $timer
	del_plugin request_transformer

	curl -s -X POST http://localhost:8001/apis/benchmark/plugins \
		--data "name=response_transformer" \
		--data "value.add.headers=x-new-header:some_value, x-another-header:some_value" \
		--data "value.add.json=new-json-key:some_value, another-json-key:some_value" \
		--data "value.remove.headers=x-toremove, x-another-one" \
		--data "value.remove.json=json-key-toremove, another-json-key"
	
	run_siege "Response Transformer" $concurrency $timer
	del_plugin response_transformer

	curl -s -X POST http://localhost:8001/apis/benchmark/plugins \
		--data "name=keyauth" \
		--data "value.key_names=apikey"

	run_siege "Key Authentication" $concurrency $timer "apikey: secure_token"
	del_plugin keyauth

	# curl -s -X POST http://localhost:8001/apis/benchmark/plugins \
	# 	--data "name=requestsizelimiting" \
	# 	--data "value.allowed_payload_size=10"

	# run_siege "Request Size Limit" $concurrency $timer
	# del_plugin requestsizelimiting

	concurrency=$(($concurrency + $c))

	if [ $concurrency -le $limit ]; 
	then
		run_benchmarks
	else
		cat /var/log/siege.log
	fi

}

start_cassandra
start_kong
run_benchmarks
