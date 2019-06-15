#!/bin/bash
sudo apt update 
#&& sudo apt upgrade -y

sudo apt install -y  build-essential python3 python3-pip python3-dev libffi-dev git
sudo pip3 install --upgrade pip

git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray

sudo pip3 install --upgrade cryptography
sudo pip3 install -r requirements.txt
cp -rfp inventory/sample inventory/mycluster

declare -a IPS=$HOSTS

echo $IPS
CONFIG_FILE=inventory/mycluster/hosts.yml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
