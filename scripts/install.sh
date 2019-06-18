#!/bin/bash
sudo apt update 
#&& sudo apt upgrade -y

sudo apt install -y  build-essential python3 python3-pip python3-dev libffi-dev git 

sudo ln -s /usr/bin/python3 /usr/bin/python

sudo pip3 install ansible

ansible-galaxy install indigo-dc.kubernetes

echo "[kube-node]" > hosts.ini

echo -e $HOSTS >> hosts.ini

