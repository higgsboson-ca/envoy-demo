#!/bin/bash

echo "... try to stop envoy-ingress ..."
docker stop envoy-ingress

# clean old images
docker images --no-trunc | grep envoy-ingress | awk '{ print $3 }' | xargs -r docker rmi -f

docker_build_folder="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
build_time=`date +%Y%m%d-%H%M%S-%Z`

docker build --no-cache -t envoy-ingress:$build_time $docker_build_folder/docker-build/

# tag the image
docker tag envoy-ingress:$build_time envoy-ingress:latest

unset build_time
unset docker_build_folder
