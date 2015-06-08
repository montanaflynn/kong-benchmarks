FROM debian:jessie
MAINTAINER Montana Flynn <montana@montanaflynn.me>

# Necessities
RUN apt-get update
RUN apt-get install -y sudo curl siege wget jq ca-certificates

# Java 8
RUN mkdir -p /usr/lib/jvm/
RUN curl --silent --location --retry 3 --cacert /etc/ssl/certs/GeoTrust_Global_CA.pem \
    --header "Cookie: oraclelicense=accept-securebackup-cookie;" \
    http://download.oracle.com/otn-pub/java/jdk/8u45-b14/jre-8u45-linux-x64.tar.gz \
    | tar xz -C /usr/lib/jvm/
ENV JAVA_HOME /usr/lib/jvm/jre1.8.0_45
ENV PATH $JAVA_HOME/bin:$PATH

# Cassandra
RUN mkdir -p /usr/lib/cassandra/
RUN curl --silent http://ftp.wayne.edu/apache/cassandra/2.1.5/apache-cassandra-2.1.5-bin.tar.gz \
    | tar xz -C /usr/lib/cassandra/
ENV CASS_HOME /usr/lib/cassandra/apache-cassandra-2.1.5
ENV PATH $CASS_HOME/bin:$PATH

# Kong
RUN apt-get install -y lua5.1 openssl dnsmasq netcat libpcre3
RUN wget https://github.com/Mashape/kong/releases/download/0.3.0/kong-0.3.0.wheezy_all.deb
RUN sudo dpkg -i kong-0.3.0.*.deb

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Optimizations
ADD config/server/sysctl.conf /etc/sysctl.conf
ADD config/server/limits.conf /etc/security/limits.conf

# Benchark
RUN mkdir -p /var/log/benchmarks
RUN touch /var/log/benchmarks/siege.log
ADD config/server/.siegerc /root/.siegerc
ADD benchmark.sh /usr/local/bin/benchmark

CMD ["benchmark"]
