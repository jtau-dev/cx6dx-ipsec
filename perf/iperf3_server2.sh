#!/usr/bin/bash
source ../config.dat

NoT=${1:-$VFS}
CO=${2:-0} # core offset

# set -x 
NUMA=`cat /sys/class/infiniband/$RMLXID/device/numa_node`
NUMA_CORES=`lscpu | grep "NUMA node$NUMA" | awk '{print $4}'`
NUMA_CORES=${NUMA_CORES//,/ }

for c in ${NUMA_CORES[@]}; do
  if [[ $c =~ [-] ]]; then
    C=${c/-/ }
    cores=( ${cores[@]} $(seq $C) )
  fi
done
#echo "${cores[@]}"

RIFN=`ls /sys/class/infiniband/$RMLXID/device/net/`;
RIFN=${RIFN//};

VFN=(dummy $RIFN `ls /sys/class/infiniband/$RMLXID/device/virtfn*/net/`);
echo "VFN=${VFN[@]}"
for i in $( seq 1 2 ${#VFN[@]} ); do 
  IP=`ip addr show ${VFN[$i]} | grep -E 'inet.*global' | awk '{print $2}'`
  IP=${IP///24/}
  IPs=(${IPs[@]} $IP)
done

echo ${IPs[@]}
for i in $( seq 0 $(( NoT - 1)) )
do
  coren=$(( cores[$i] + NoT + $CO ))
  cmd="taskset -c $coren iperf3 -s -B ${IPs[$i]}&"
  echo $cmd
  eval $cmd
 done
wait



