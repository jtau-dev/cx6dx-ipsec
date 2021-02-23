#!/usr/bin/bash
LIF=enp175s0f0
LPPFX=enp

NoT=${1:-1}
IPs=($LIF `ibdev2netdev -v | sort -t : -k3,3 | awk '{print $12}' | grep $LPPFX`)
# BF2 NUMA cores.  Change the following to the BF2's NUMA cores.
res=($(seq 12 23) $(seq 36 47) $(seq 0 11) $(seq 24 35))

for i in $( seq 0 $(( NoT - 1)) )
do
    IPADDR=`ip addr show ${IPs[$i]} | grep global | awk '{print $2}'`
    IPADDR=${IPADDR//\/24/}
    coren=${res[$i]}
    cmd="taskset -c $coren iperf3 -s -B $IPADDR&"
    echo $cmd
    eval $cmd
    
done
wait
