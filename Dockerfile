FROM ubuntu:20.04
ENV RUST_BACKTRACE=1
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
RUN echo $TZ > /etc/timezone && \
    apt-get update && apt-get install -y tzdata && \
    rm /etc/localtime && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get clean
RUN apt-get update

RUN curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
RUN mkdir /autoscale-tester
COPY . /autoscale-tester
WORKDIR /autoscale-tester


RUN tiup playground nightly --tag qiaolin-test --host 0.0.0.0 --db.config /home/ubuntu/qiaolin_test/tidb.toml