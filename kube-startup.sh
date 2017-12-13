#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# wait for nodes to come up
sleep 30

# get cluster
sudo ip -s -s neigh flush all
sudo ping -b 10.0.0.255 -c 5 #replace with own ipaddress .255
IPS=$(arp -e | grep eth0 | awk '{print $1}')
PI_IPS=()
declare -A IP_SET


for IP in $IPS; do
    status=$(ssh -o BatchMode=yes -o ConnectTimeout=5 $IP echo ok 2>&1)
    if [[ $status == ok && ! ${IP_SET["$IP"]+abc} ]] ; then
        HOSTNAME=$(ssh $IP hostname)
        IP_SET+=(["$IP"]=true)
        PI_IPS+=("$IP")
    fi
done;

for IP in $PI_IPS; do
    echo $IP
done;

exit 0
# reset the cluster
rm -rf $HOME/.kube
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
for IP in $PI_IPS; do
    status=$(ssh -o BatchMode=yes -o ConnectTimeout=5 $IP echo ok 2>&1)
    if [[ $status == ok ]] ; then
        ssh pirate@$IP sudo $JOIN_COMMAND
    fi
done;

cd ~/arm-kube-yarn; make;
