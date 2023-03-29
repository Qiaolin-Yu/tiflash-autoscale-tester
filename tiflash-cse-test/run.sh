#!/usr/bin/env bash

# install minio
if ! command -v minio; then
    sudo pacman -S --noconfirm minio
fi
# install mysql client
if ! command -v mysql; then
    sudo pacman -S --noconfirm mariadb-clients
fi

#rm ~/.tiup/data/tiflash-test -rf
#rm ./s3 -rf
#rm ./config -rf


PD_PATH=/home/ubuntu/pd-cse/bin/pd-server

TIDB_BASE=/home/ubuntu/tidb-cse/
TIDB_PATH=$TIDB_BASE/bin/tidb-server

TIKV_PATH=/home/ubuntu/cloud-storage-engine/target/debug/tikv-server


TIFLASH_PATH=/home/ubuntu/tiflash-cse-storage/cmake-build-debug/dbms/src/Server/tiflash
TIFLASH_PROXY_PATH=/home/ubuntu/tiflash-cse-storage/contrib/tiflash-proxy/target/release

for so in $(ls $TIFLASH_PROXY_PATH/*.so); do
    ln -sf $so ./bin
done
rm ./bin/tiflash
ln -sf $TIFLASH_PATH ./bin/tiflash

function clean() {
    echo "Exiting"
    for i in $(ps ax | grep tiflash | awk '{print $1}'); do
        kill -9 $i
    done

    echo "Stop minio"
    pkill -9 minio
    exit
}

trap "{ clean; }" SIGINT

function start_minio() {
    mkdir -p ./s3/cse
    minio server --quiet ./s3 --console-address ":19090" --address ":19000" &
}

function create_configs() {
    mkdir -p ./config
    cp ./template/pd.toml ./config
    for i in "$@"; do
        if [ -n "$i" ]; then
            if [ -z "$tenants" ]; then
                tenants="\"$i\""
            else
                tenants="$tenants, \"$i\""
            fi
        fi

        echo "Creating config for $i"
        mkdir -p ./config/$i
        cp ./template/tidb.toml template/tiflash.toml "./config/$i"
        sed -i "s/{{TENANT}}/$i/g" "./config/$i/tidb.toml"
        sed -i "s/{{TENANT}}/$i/g" "./config/$i/tiflash.toml"
    done

    sed -i "s/{{TENANTS}}/$tenants/g" ./config/pd.toml
}

function start_cluster() {
    tiup playground v6.2.0 \
        --host 0.0.0.0 \
        --tag tiflash-test \
        --pd 1 \
        --pd.binpath $PD_PATH \
        --pd.config ./config/pd.toml \
        --db 1 \
        --db.binpath $TIDB_PATH \
        --db.config ./config/$1/tidb.toml \
        --kv 1 \
        --kv.config ./template/tikv.toml \
        --kv.binpath $TIKV_PATH \
        --tiflash 1 \
        --tiflash.config ./config/$1/tiflash.toml \
        --tiflash.binpath ./bin/tiflash &
    while ! mysql -h 127.0.0.1 -P 4000 -u root -e "use test"  >/dev/null 2>&1; do
        sleep 0.2
    done
}

start_minio

create_configs "$@"

start_cluster "$1"

while ! tiup playground display 2>&1 > /dev/null; do
    sleep 0.2
done

#for i in "${@:2}"; do
#    tiup playground scale-out \
#        --tag tiflash-test \
#        --db 1 \
#        --db.binpath $TIDB_PATH \
#        --db.config ./config/$i/tidb.toml \
#        --tiflash 0 \
#        --tiflash.config ./config/$i/tiflash.toml \
#        --tiflash.binpath ./bin/tiflash &
#done

read -r -d '' _ </dev/tty
