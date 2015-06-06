# Kong Benchmark Dockerfile

A simple docker based benchmarking system for [Kong](https://github.com/mashape/kong) that is based on Debian. It installs Java, Cassandra and Kong and then runs benchmarks against Kong including common plugin configurations. Ideally it would be built into the Kong release process.

### Usage

```
git clone git@github.com:montanaflynn/kong-benchmarks.git
cd kong-benchmarks
docker build -t "kong-benchmarks" .  
docker run kong-benchmarks
```
