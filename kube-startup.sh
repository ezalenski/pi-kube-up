#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set +e

# get and reset cluster
rm -f ~/.ssh/known_hosts
PI_IPS=()
declare -A IP_SET
IP_RANGE="$(ip addr | grep "inet.*eth0" | awk '{print $2}' | awk -F. '{print $1"."$2"."$3}').0"

while [[ ! "${#PI_IPS[@]}" =~ "6" ]]; do
    IPS=$(nmap -p 22 --open 10.0.0.0/24 | grep 'scan report' | awk '{print $5}')

    for IP in $IPS; do
        status=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 $IP echo ok 2>&1 || true)
        if [[ $status == ok && ! ${IP_SET["$IP"]+abc} ]] ; then
            IP_SET+=(["$IP"]=true)
            PI_IPS+=("$IP")
            ssh $IP sudo kubeadm reset
            ssh $IP sudo reboot || true
        fi
    done;
    echo "Found ${#PI_IPS[@]} nodes..."
done;
set -e

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

sleep 30

# get slave local ips
echo "Kubernetes join command: $JOIN_COMMAND"
for IP in "${PI_IPS[@]}"; do
    ssh -f pirate@$IP sudo $JOIN_COMMAND || true
done;

cd ~/arm-kube-yarn; make;
