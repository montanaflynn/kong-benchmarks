#!/bin/sh

# Set variables using ENV or defaults
TIME=${TIME:="10s"}
UPSTREAM=${UPSTREAM:="http://127.0.0.1:8001/robots.txt"}
WARMUP=${WARMUP:=true}
PLUGINS=${PLUGINS:=true}
RUN_CASSANDRA=${RUN_CASSANDRA:=true}
CONCURRENCY=${CONCURRENT:=100}
MAX_CONCURRENT=${MAX_CONCURRENT:=500}

start_kong()
{
	if [ "$RUN_CASSANDRA" = true ] ; then
		echo "Starting Cassandra"
		mkdir /var/log/cassandra
		cassandra > /var/log/cassandra/start.log
		# @todo replace sleep with wait
		sleep 15
	fi

	echo "Starting Kong"
	kong start
	echo "Adding API"
	curl -s -X POST \
		--url http://localhost:8001/apis/ \
		--data "name=benchmark" \
		--data "target_url=$UPSTREAM" \
		--data "public_dns=benchmark.api"

	echo "Adding Consumer"
	curl -s -X POST http://localhost:8001/consumers/ \
		--data "username=kong_user" 

	curl -s -X POST http://localhost:8001/consumers/kong_user/keyauth \
		--data "key=secure_token"
}

run_siege()
{
	# Get Kong version from api pass to jq and trim quotes with sed
	local NAME="Kong $(curl -s http://localhost:8001/ | jq .version | sed "s/\"//g")"
	local HOST="benchmark.api"
	local PROXY="http://localhost:8000"
	
	if [ -z "4" ]
	  then
	   	local HEADER="-H \"$4\""
	   else
	    local HEADER=""
	fi

	if [ "$WARMUP" = true ] ; then
		echo "Siege Warming up $NAME $1 $2 $3"
 		siege -m "$NAME $1 Warmup $2" -c "$2" -t "$3" -H "host: $HOST" $HEADER $PROXY
	fi

	echo "Siege $NAME $1 $2 $3" 
	siege -m "$NAME $1 $2" -c "$2" -t "$3" -H "host: $HOST" $HEADER $PROXY
}

del_plugin()
{
	curl -s -X DELETE http://localhost:8001/apis/benchmark/plugins/"$1"
}

run_benchmarks()
{
	run_siege "Core" $CONCURRENCY $TIME

	if [ "$PLUGINS" = true ] ; then

		curl -s -X POST http://localhost:8001/apis/benchmark/plugins \
			--data "name=cors" \
			--data "value.origin=mockbin.com" \
			--data "value.methods=GET,POST" \
			--data "value.headers=Accept, Accept-Version, Content-Length" \
			--data "value.exposed_headers=X-Auth-Token" \
			--data "value.credentials=true" \
			--data "value.max_age=3600"

		run_siege "CORS" $CONCURRENCY $TIME
		del_plugin cors

		curl -s -X POST http://localhost:8001/apis/benchmark/plugins \
			--data "name=request_transformer" \
			--data "value.add.headers=x-new-header:some_value, x-another-header:some_value" \
			--data "value.add.querystring=new-param:some_value, another-param:some_value" \
			--data "value.add.form=new-form-param:some_value, another-form-param:some_value" \
			--data "value.remove.headers=x-toremove, x-another-one" \
			--data "value.remove.querystring=param-toremove, param-another-one" \
			--data "value.remove.form=formparam-toremove, formparam-another-one"

		run_siege "Request Transformer" $CONCURRENCY $TIME
		del_plugin request_transformer

		curl -s -X POST http://localhost:8001/apis/benchmark/plugins \
			--data "name=response_transformer" \
			--data "value.add.headers=x-new-header:some_value, x-another-header:some_value" \
			--data "value.add.json=new-json-key:some_value, another-json-key:some_value" \
			--data "value.remove.headers=x-toremove, x-another-one" \
			--data "value.remove.json=json-key-toremove, another-json-key"
		
		run_siege "Response Transformer" $CONCURRENCY $TIME
		del_plugin response_transformer

		curl -s -X POST http://localhost:8001/apis/benchmark/plugins \
			--data "name=keyauth" \
			--data "value.key_names=apikey"

		run_siege "Key Authentication" $CONCURRENCY $TIME '-H "apikey: secure_token"'
		del_plugin keyauth
	fi

	CONCURRENCY=$(($CONCURRENCY + $CONCURRENT))

	if [ $CONCURRENCY -le $MAX_CONCURRENT ]; 
	then
		run_benchmarks
	else
		cat /var/log/benchmarks/siege.log
	fi
}

start_kong
run_benchmarks
