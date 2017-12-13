#!/bin/bash
sudo ip -s -s neigh flush all
PI_IPS=()
declare -A IP_SET
IP_RANGE="$(ip addr | grep "inet.*eth0" | awk '{print $2}' | awk -F. '{print $1"."$2"."$3}').255"

while [[ ! "${#PI_IPS[@]}" =~ "6" ]]; do
    sudo ping -b $IP_RANGE -c 2
    IPS=$(arp -e | grep eth0 | awk '{print $1}')


    for IP in $IPS; do
        status=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 $IP echo ok 2>&1 || true)
        if [[ $status == ok && ! ${IP_SET["$IP"]+abc} ]] ; then
            IP_SET+=(["$IP"]=true)
            PI_IPS+=("$IP")
            ssh $IP sudo shutdown now || true
        fi
    done;
done;

sudo shutdown now
