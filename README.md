# Kong Benchmark Dockerfile

A docker benchmarking framework for [Kong](https://github.com/mashape/kong) that runs a series of load tests to determine performance under various conditions such as with plugins enabled and a large number of concurrent connections. The benchmarks are performed by [Siege](https://www.joedog.org/siege-home/) and results are written to `/var/log/benchmarks/siege.log` so you can just add `-v /local/path:/var/log/benchmarks/` when running a container to expose it as a persistent volume containing the log file. If you're running boot2docker you'll have to use a local path inside the `/Users` directory. 

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
time           | "10S"                              | Time to siege for
upstream       | "http://127.0.0.1:8001/robots.txt" | Upstream target to siege
plugins        | true                               | Benchmark Kong plugins 
run_cassandra  | true                               | Run Cassandra
concurrent     | 100                                | Starting concurrency
max_concurrent | 500                                | Maximum concurrency

## Examples

Use external Cassandra by replacing the `kong.yml` file and adding the `rc` environment variable.

```
docker run -e "rc=false" -v $PWD/kong-config/:/etc/kong/ montanaflynn/kong-debian-benchmark
```

Here's Kong using [mockbin](http://mockbin.com/status/418) as the upstream API up to 100 concurrent connections in increments of 20:

```
docker run -e "c=20" -e "m=100" -e "a=http://mockbin.com/status/418" kong-benchmarks
```

Here's how you can run a short test of 50 concurrent connections without plugins:

```
docker run -e "c=50" -e "m=50" -e "p=false" kong-benchmarks
```

Keeping a persistent log file on your docker host, subsequent runs append to the file:

```
docker run -v /logs/kong-benchmarks/:/var/log/benchmarks/ kong-benchmarks
```
