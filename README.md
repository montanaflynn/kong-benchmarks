# Kong Benchmark Dockerfile

A docker benchmarking framework for [Kong](https://github.com/mashape/kong) that runs a series of load tests to determine performance under various conditions such as with plugins enabled and a large number of concurrent connections. 

The benchmarks are performed by [Siege](https://www.joedog.org/siege-home/) and results are written to `/usr/local/kong/siege.log` so you can just add `-v /local/path:/usr/local/kong` when running a container to expose it as a persistent volume containing the log file. If you're running boot2docker you'll have to use a local path inside the `/Users` directory. 

If you [format Siege's log](https://gist.github.com/montanaflynn/a13f9d5461409b6c39c4) it's possible to get a nice [CSV file](https://github.com/montanaflynn/kong-benchmarks/blob/master/samples/metrics.csv) that you can [chart](http://www.charted.co/c/58acf6d). 

## Usage

```
# build it
git clone git@github.com:montanaflynn/kong-benchmarks.git
cd kong-benchmarks
docker build -t "kong-benchmarks" .  

# run it
docker run kong-benchmarks
```

There are some parameters you can modify by passing environment variables to `docker run`:

 name          | default                            | description
---------------|------------------------------------|------------
TIME           | "60S"                              | Time to siege for
UPSTREAM       | "http://127.0.0.1:8001/robots.txt" | Upstream target to siege
VERBOSE_LOGS   | false                              | Maximum concurrency
DEBUG          | false                              | Maximum concurrency
WARMUP         | true                               | Benchmark Kong plugins 
PLUGINS        | true                               | Benchmark Kong plugins 
RUN_CASSANDRA  | true                               | Run Cassandra
CONCURRENT     | 100                                | Starting concurrency
MAX_CONCURRENT | 500                                | Maximum concurrency

## Examples

Use external Cassandra by replacing the `kong.yml` file and not running Cassandra:

```
docker run -e "RUN_CASSANDRA=false" -v $PWD/kong-config/:/etc/kong/ kong-benchmarks
```

Using [mockbin](http://mockbin.com/status/418) as the upstream API up to 100 concurrent connections in increments of 20:

```
docker run -e "CONCURRENT=20" -e "MAX_CUNCURRENT=100" -e "UPSTREAM=http://mockbin.com/status/418" kong-benchmarks
```

Here's how you can run a short test of 50 concurrent connections without plugins:

```
docker run -e "CONCURRENT=50" -e "MAX_CUNCURRENT=50" -e "PLUGINS=false" kong-benchmarks
```

Have a persistent log file on your docker host, subsequent runs will append to the same file:

```
docker run -v /logs/kong-benchmarks/:/usr/local/kong kong-benchmarks
```
