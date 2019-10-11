#!/bin/bash
docker_run_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
host_volume_folder=$docker_run_folder/host_volume

echo "... try to stop envoy-ingress ..."
docker stop envoy-ingress

echo "volumes mounted to the docker instance locates at:"
echo $host_volume_folder



if [ ! -d $host_volume_folder/conf ]; then
    mkdir $host_volume_folder/conf
fi

if [ ! -d $host_volume_folder/logs ]; then
    mkdir $host_volume_folder/logs
fi

if [ ! -d $host_volume_folder/ssl ]; then
    mkdir $host_volume_folder/ssl
fi

cp $docker_run_folder/docker-build/conf/envoy-ingress.yaml $host_volume_folder/conf/envoy-ingress.yaml
cp $docker_run_folder/docker-build/conf/pre-processor.lua $host_volume_folder/conf/pre-processor.lua
cp $docker_run_folder/docker-build/conf/post-processor.lua $host_volume_folder/conf/post-processor.lua

exposed_svc_port=8000
exposed_adm_port=8001

echo "exposed service port for envoy front is $exposed_svc_port"
echo "exposed admin port for envoy front is $exposed_adm_port"

cd $docker_run_folder
docker run --rm -d --network="envoy-ingress-bridge" --network-alias envoy-ingress \
	-v $host_volume_folder/conf:/home/bnlapp/envoy-ingress/conf:Z \
	-v $host_volume_folder/ssl:/home/bnlapp/envoy-ingress/ssl:Z \
	-v $host_volume_folder/logs:/home/bnlapp/envoy-ingress/logs:Z \
	-p $exposed_svc_port:8000 -p $exposed_adm_port:8001 \
	--name envoy-ingress  envoy-ingress:latest

unset docker_run_folder
unset exposed_svc_port
unset exposed_adm_port

sleep 2
dkid=$(docker ps | grep envoy-ingress | awk '{ print $1 }')
docker logs -f $dkid &
unset dkid
