#!/bin/bash

# clean old images
docker images --no-trunc | grep serviceproxy_envoy-front | awk '{ print $3 }' | xargs -r docker rmi -f

script_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
build_time=`date +%Y%m%d-%H%M%S-%Z`

#rm -rf $script_folder/../host_volume/envoy-ingress/ssl/*
#cp -f $script_folder/docker-build/jwt-sig-certs/*.json $script_folder/../host_volume/envoy-ingress/ssl/
#cp -f $script_folder/docker-build/mtls/*.crt $script_folder/../host_volume/envoy-ingress/ssl/
#cp -f $script_folder/docker-build/mtls/*.key $script_folder/../host_volume/envoy-ingress/ssl/

rm -rf $script_folder/../host_volume/envoy-ingress/conf/*
cp -f $script_folder/docker-build/conf/* $script_folder/../host_volume/envoy-ingress/conf/

cp -f $script_folder/docker-build/envoy-ingress.yaml $script_folder/../host_volume/envoy-ingress/conf/

docker build --no-cache -t serviceproxy_envoy-front:$build_time $script_folder/docker-build/

# tag the image
docker tag serviceproxy_envoy-front:$build_time serviceproxy_envoy-front:latest

unset build_time
unset script_folder
