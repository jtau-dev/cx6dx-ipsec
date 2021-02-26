#!/usr/bin/bash
#
source ../config.dat

#
NoT=${1:-1}
DIR=${2}
CO=${3:-0} # core offset

if [[ $2 =~ [\^0-9$] ]]; then
    CO=$2
    DIR=""
fi

if [[ "$3" == "-R" ]]; then
    DIR=$3
fi

ifconfig | grep $LHOST > /dev/null
if [[ $? == 1 ]]; then
  iSERVER=$LHOST
  MLXID=$LMLXID
else
  iSERVER=$RHOST
  MLXID=$RMLXID
fi

NUMA=`cat /sys/class/infiniband/$MLXID/device/numa_node`
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
  RIFN=\`ls /sys/class/infiniband/$MLXID/device/net/\`; \
  RIFN=\${RIFN/\/}; \
  ifconfig \${RIFN}_0 2> /dev/null
  if [[ \$? == 1 ]]; then
    VFN=(dummy \$RIFN \`ls /sys/class/infiniband/$MLXID/device/virtfn*/net/\`);\
  else
    VFN=(\`ls /sys/class/infiniband/$MLXID/device/virtfn*/net/\`);\
  fi
  for i in \$( seq 1 2 \${#VFN[@]} ); do \
    IP=\`ip addr show \${VFN[\$i]} | grep -E 'inet.*global' | awk '{print \$2}'\`;\
    IP=\${IP//\/24/};\
    echo \$IP; \
  done\
"
IPs=(`ssh -x $iSERVER "$T"`)

for i in $(seq 0 $(( NoT - 1 )) )
do
    corei=$(( i + NoT + CO ))
    cmd="taskset -c ${cores[$corei]} iperf3 -c ${IPs[$i]} -M 1350 -P1 --logfile ${FIFO_DIR}fifo${i}  -t $RUNTIME $DIR &"
    echo $cmd
    eval "$cmd"

done    
wait 
