#!/usr/bin/bash
#
source ../config.dat

#
NoT=${1:-1}
DIR=${2}

NUMA=`cat /sys/class/infiniband/$LMLXID/device/numa_node`
NUMA_CORES=`lscpu | grep "NUMA node$NUMA" | awk '{print $4}'`
NUMA_CORES=${NUMA_CORES//,/ }


for c in ${NUMA_CORES[@]}; do
    if [[ $c =~ [-] ]]; then
	C=${c/-/ }
	cores=( ${cores[@]} $(seq $C) )
    fi
done
#echo "${cores[@]}"

T="
  RIFN=\`ls /sys/class/infiniband/$RMLXID/device/net/\`; \
  RIFN=\${RIFN/\/}; \
  VFN=(dummy \$RIFN \`ls /sys/class/infiniband/$RMLXID/device/virtfn*/net/\`);\
  for i in \$( seq 1 2 \${#VFN[@]} ); do \
    IP=\`ip addr show \${VFN[\$i]} | grep -E 'inet.*global' | awk '{print \$2}'\`;\
    IP=\${IP//\/24/};\
    echo \$IP; \
  done\
"
#echo $T
IPs=(`ssh -x $RHOST "$T"`)
#echo ${IPs[@]}


for i in $(seq 0 $(( NoT - 1 )) )
do
    corei=$(( i + NoT ))
    cmd="taskset -c ${cores[$corei]} iperf3 -c ${IPs[$i]} -M 1350 -P1 --logfile ${FIFO_DIR}fifo${i}  -t $RUNTIME $DIR &"
    echo $cmd
    eval "$cmd"

done    
wait 
