#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# reset the cluster
sudo kubeadm reset

# setup cluster master
JOIN_COMMAND=$(sudo kubeadm init --pod-network-cidr 10.244.0.0/16 --token-ttl 0 | grep " kubeadm join")

# setup kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# add flannel to cluster
curl -sSL https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml | sed "s/amd64/arm64/g" | kubectl create -f -

# get slave local ips
sudo ip -s -s neigh flush all
sudo ping -b 10.0.0.255 -c 5 #replace with own ipaddress .255
PI_IPS=$(arp -e | grep b8:27:eb | awk '{print $1}')

for IP in PI_IPS; do
    ssh pirate@$(IP) sudo $(JOIN_COMMAND)
    ssh pirate@$(IP) sudo reboot
done;

cd ~/arm-kube-yarn; make;
