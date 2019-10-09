#!/bin/bash
script_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $script_folder
cd ../host_volume
host_volume_folder="$(pwd)"
echo "volumes mounted to the docker instance locates at:"
echo $host_volume_folder

exposed_svc_port=8000
exposed_svc_port_ssl=8443
exposed_svc_port_ssl_lua=18443
exposed_svc_port_jwt_payload_test=18000
exposed_svc_port_jwt_test=28000
exposed_adm_port=8001

if [ -z "$1" ]
  then
       run_mode="-it";
  else
    case "$1" in
      "--back-end" )
         run_mode="-d";;
      "--front-end" )
         run_mode="-it";;
      *)
         run_mode="-it";;
    esac
fi

echo "exposed service port for envoy front is $exposed_svc_port"
echo "exposed service port (SSL) for envoy front is $exposed_svc_port_ssl"
echo "exposed service port (SSL) for envoy front as a content router is $exposed_svc_port_ssl_lua"
echo "exposed service port for envoy front for jwt digest testing is $exposed_svc_port_ssl_jwt_test"
echo "exposed service port for envoy front for jwt full payload testing is $exposed_svc_port_ssl_jwt_payload_test"
echo "exposed admin port for envoy front is $exposed_adm_port"

cd $script_folder
docker run --name envoy-ingress --rm $run_mode --network="esg-ingress-bridge" --network-alias envoy-ingress -v $host_volume_folder/envoy-ingress/conf:/home/etransfer/service-proxy/envoy-ingress/conf:Z -v $host_volume_folder/envoy-ingress/ssl:/home/etransfer/service-proxy/envoy-ingress/ssl:Z -v $host_volume_folder/envoy-ingress/logs:/home/etransfer/service-proxy/envoy-ingress/logs:Z -p $exposed_svc_port_ssl:8443 -p $exposed_svc_port_ssl_lua:18443 -p $exposed_svc_port_jwt_payload_test:18000 -p $exposed_svc_port_jwt_test:28000 -p $exposed_svc_port:8000 -p $exposed_adm_port:8001 serviceproxy_envoy-front:latest

unset script_folder
unset exposed_svc_port
unset exposed_svc_port_ssl
unset exposed_svc_port_ssl_lua
unset exposed_adm_port
unset run_mode
