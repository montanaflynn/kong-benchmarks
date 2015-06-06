FROM debian:jessie
MAINTAINER Montana Flynn <montana@montanaflynn.me>

# Bare necessities
RUN apt-get update
RUN apt-get install -y sudo curl siege wget netcat ca-certificates

# Basic Optimizations
ADD sysctl.conf /etc/sysctl.conf
ADD limits.conf /etc/security/limits.conf

# Java 8
ENV VERSION 8
ENV UPDATE 45
ENV JAVA_HOME /usr/lib/jvm/java-${VERSION}-oracle

RUN curl --silent --location --retry 3 --cacert /etc/ssl/certs/GeoTrust_Global_CA.pem \
    --header "Cookie: oraclelicense=accept-securebackup-cookie;" \
    http://download.oracle.com/otn-pub/java/jdk/"${VERSION}"u"${UPDATE}"-b14/jre-"${VERSION}"u"${UPDATE}"-linux-x64.tar.gz \
    | tar xz -C /tmp && mkdir -p /usr/lib/jvm && mv /tmp/jre1.${VERSION}.0_${UPDATE} "${JAVA_HOME}" 

RUN update-alternatives --install "/usr/bin/java" "java" "${JAVA_HOME}/bin/java" 1 && \
    update-alternatives --set java "${JAVA_HOME}/bin/java"

# Cassandra
RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 514A2AD631A57A16DD0047EC749D6EEC0353B12C
RUN echo 'deb http://www.apache.org/dist/cassandra/debian 20x main' >> /etc/apt/sources.list.d/cassandra.list
RUN apt-get update && apt-get install -y cassandra=2.0.15 

# Kong
RUN apt-get install -y lua5.1 openssl dnsmasq libpcre3
RUN wget https://github.com/Mashape/kong/releases/download/0.3.0/kong-0.3.0.wheezy_all.deb
RUN sudo dpkg -i kong-0.3.0.*.deb

# Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN echo 'show-logfile false\ncsv = true' >> ~/.siegerc

# Benchmark
ADD ./benchmark.sh /usr/local/bin/benchmark
CMD ["benchmark"]
