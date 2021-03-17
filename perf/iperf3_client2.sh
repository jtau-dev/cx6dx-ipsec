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

NUMA=`cat /sys/class/infiniband/$LMLXID/device/numa_node`
NUMA_CORES=`lscpu | grep "NUMA node$NUMA" | awk '{print $4}'`
NUMA_CORES=${NUMA_CORES//,/ }
NUMA_CORES2=`lscpu | grep "NUMA node" | grep -v "NUMA node$NUMA" | awk '{print $4}'`
NUMA_CORES2=${NUMA_CORES2//,/ }
NC=(${NUMA_CORES[@]} ${NUMA_CORES2[@]} ${NUMA_CORES[@]} ${NUMA_CORES2[@]})

for c in ${NC[@]}; do
    if [[ $c =~ [-] ]]; then
	C=${c/-/ }
	cores=( ${cores[@]} $(seq $C) )
    fi
done
#echo "${cores[@]}"

T="
  RIFN=\`ls /sys/class/infiniband/$MLXID/device/net/\`; \
  RIFN=\${RIFN/\/};\
  if [ -e /sys/class/infiniband/$MLXID/device/virtfn0 ]; then \
    echo 'No'
    ifconfig \${RIFN}_0 2> /dev/null;\
    if [[ \$? == 1 ]]; then\
      VFN=(dummy \$RIFN \`ls /sys/class/infiniband/$MLXID/device/virtfn*/net/\`);\
    else \
      VFN=(\`ls /sys/class/infiniband/$MLXID/device/virtfn*/net/\`);\
      for i in \$( seq 1 2 \${#VFN[@]} ); do \
	IP=\`ip addr show \${VFN[\$i]} | grep -E 'inet.*global' | awk '{print \$2}'\`;\
	IP=\${IP//\/24/};\
	echo \$IP;\
      done;\
    fi\
  else
    IPs=(\`ip a s dev \$RIFN | awk '/inet / {sub(/\/24/,\"\",\$2); print \$2}'\`);
    for ip in \${IPs[@]}; do\
      echo \$ip;\
    done;\
  fi
"


#    IPs=\(`ip a s dev \$RIFN | awk '/inet / {print \$2}'`\);\
#  fi\
#"

RIPs=(`ssh -x $iSERVER "$T"`)
#echo "${IPs[@]}"

if [ ! -e /sys/class/infiniband/$LMLXID/device/virtfn0 ]; then
    LIFN=`ls /sys/class/infiniband/$LMLXID/device/net/`
    LIFN=${LIFN//}
    BIP=(`ip a s dev $LIFN | awk '/inet / {sub(/\/24/,"",$2); print "-B " $2}'`)
fi

#echo "YES: ${BIP[@]}"

[[ $NoT -gt 16 ]] && NoTO=16 || NoTO=$NoT

for i in $(seq 0 $(( NoT - 1 )) )
do
    corei=$(( i + CO ))
    cmd="taskset -c ${cores[$corei]} iperf3 -c ${RIPs[$i]} -P1 --logfile ${FIFO_DIR}fifo${i} ${BIP[@]:$((2*i)):2} -t $RUNTIME $DIR &"
    echo $cmd
    eval "$cmd"

done    
wait 
