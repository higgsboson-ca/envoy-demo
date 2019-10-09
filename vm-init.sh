#!/bin/bash
echo "please run this script as root"
echo "user etapp and etgroup will be created"
echo "make sure the docker is fuctioning under root before running this script"
read -p "Press any key to continue. Ctrl+C to stop"

# step-1: add docker group
groupadd docker

# step-2: add etapp group and user with fix id 610
groupadd -g 610 etapp
useradd -u 610 -g 610 etapp

# step-3: add etapp to docker group
usermod -aG docker etapp

read -p "/usr/local/bin need to be added into PATH for etapp .bash_profile manually for docker-compose"

# step-4: change password for etapp
echo "Changing password for etapp"
passwd etapp

# docker network create -d bridge --subnet 192.168.0.0/24 --gateway 192.168.0.1 bnldockernet
docker network create -d bridge envoy-ingress-bridge