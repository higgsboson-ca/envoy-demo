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

if [ ! -d $host_volume_folder/tls ]; then
    mkdir $host_volume_folder/tls
fi

cp -f $docker_run_folder/docker-build/conf/envoy-ingress.yaml $host_volume_folder/conf/envoy-ingress.yaml
cp -f $docker_run_folder/docker-build/conf/pre-processor.lua $host_volume_folder/conf/pre-processor.lua
cp -f $docker_run_folder/docker-build/conf/post-processor.lua $host_volume_folder/conf/post-processor.lua
cp -f $docker_run_folder/docker-build/server-certs/bnlorg999.tls.devqa.crt $host_volume_folder/tls/bnlorg999.tls.devqa.crt
cp -f $docker_run_folder/docker-build/server-certs/bnlorg999.tls.devqa.key $host_volume_folder/tls/bnlorg999.tls.devqa.key

echo "... generate SPKI hash - server cert #bnlorg999 ..."
echo
openssl x509 -in $docker_run_folder/docker-build/server-certs/bnlorg999.tls.devqa.crt -noout -pubkey \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
# will generate hash: 9zetMl0cmtqNwF8xZUOJ4wHwrtbE44ChJef8B5l3kZo=  
echo
read -p "please copy the above hash to the verify_certificate_spki section in the envoy config yaml file: $host_volume_folder/conf/envoy-ingress.yaml... enter to continuew... ctrl+c to stop ..."

echo "... generate SPKI hash - server cert #bnlorg001 ..."
echo
openssl x509 -in $docker_run_folder/docker-build/client-certs/bnlorg001.tls.devqa.crt -noout -pubkey \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
# will generate hash: 4TIS8pmf1f0iYoZqDHRY28UbXC1FlPyM6qb/1h1gdCw=  
echo
read -p "please copy the above hash to the verify_certificate_spki section in the envoy config yaml file: $host_volume_folder/conf/envoy-ingress.yaml... enter to continuew... ctrl+c to stop ..."


exposed_svc_port=8000
exposed_https_port=8443
exposed_adm_port=8001

echo "exposed service port for envoy front is $exposed_svc_port"
echo "exposed admin port for envoy front is $exposed_adm_port"

echo starting envoy with command ---- docker run --rm -d --network="envoy-ingress-bridge" --network-alias envoy-ingress \
  -v $host_volume_folder/conf:/home/bnlapp/envoy-ingress/conf:Z \
  -v $host_volume_folder/tls:/home/bnlapp/envoy-ingress/tls:Z \
  -v $host_volume_folder/logs:/home/bnlapp/envoy-ingress/logs:Z \
  -p $exposed_svc_port:8000 -p $exposed_https_port:8443 -p $exposed_adm_port:8001 \
  --name envoy-ingress  envoy-ingress:latest

docker run --rm -d --network="envoy-ingress-bridge" --network-alias envoy-ingress \
	-v $host_volume_folder/conf:/home/bnlapp/envoy-ingress/conf:Z \
	-v $host_volume_folder/tls:/home/bnlapp/envoy-ingress/tls:Z \
	-v $host_volume_folder/logs:/home/bnlapp/envoy-ingress/logs:Z \
	-p $exposed_svc_port:8000 -p $exposed_https_port:8443 -p $exposed_adm_port:8001 \
	--name envoy-ingress  envoy-ingress:latest

unset docker_run_folder
unset exposed_svc_port
unset exposed_adm_port
unset host_volume_folder

sleep 2
dkid=$(docker ps | grep envoy-ingress | awk '{ print $1 }')
docker logs -f $dkid &
unset dkid
