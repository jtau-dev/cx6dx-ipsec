#!/usr/bin/bash
#
source ../config.dat

NoT=$VFS
DIR=""
CO=0 # core offset
skip=0

OPTS=`getopt -o n:o:Rs:vh --long help -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"
while true; do
    case "$1" in
	-n ) NoT=$2; shift;shift ;;
	-o ) CO=$2;  shift;shift ;;
	-R ) DIR="-R"; shift;shift ;;
	-s ) skip=$2; shift;shift ;;
	-v ) set -x; shift;shift ;;
       	-h ) usage; shift;shift ;;
	* ) break ;;
    esac
done


ifconfig | grep $LHOST > /dev/null
if [[ $? == 1 ]]; then
  iSERVER=$LHOST
  PCIDEV="0000:$RPCIDEV"
  RPCIDEV="0000:$LPCIDEV"
  LPCIDEV=$PCIDEV
else
  iSERVER=$RHOST
  RPCIDEV="0000:$RPCIDEV"
  LPCIDEV="0000:$LPCIDEV"
fi

NUMA=`cat /sys/bus/pci/devices/${LPCIDEV}/numa_node`
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
  RIFN=\`ls /sys/bus/pci/devices/${RPCIDEV}/net/\`; \
  RIFN=\${RIFN/\/};\
  if [ -e /sys/bus/pci/devices/${RPCIDEV}/virtfn0 ]; then \
    ifconfig \${RIFN}_0 2> /dev/null;\
    if [[ \$? == 0 ]]; then\
      VFN=(\`ls /sys/bus/pci/devices/${RPCIDEV}/virtfn*/net/\`);\
    else \
      VFN=(dummy \$RIFN \`ls /sys/bus/pci/devices/${RPCIDEV}/virtfn*/net/\`);\
    fi; \
    for i in \$( seq 1 2 \${#VFN[@]} ); do \
      IP=\`ip addr show \${VFN[\$i]} | grep -E 'inet.*global' | awk '{print \$2}'\`;\
      IP=\${IP//\/24/};\
      echo \$IP;\
    done;\
  else\
    IPs=(\`ip a s dev \$RIFN | awk '/inet / {sub(/\/24/,\"\",\$2); print \$2}'\`);\
    echo \${IPs[@]};\
  fi
"

#    IPs=\(`ip a s dev \$RIFN | awk '/inet / {print \$2}'`\);\
#  fi\
#"

RIPs=(`ssh -x $iSERVER "$T"`)
#echo "${RIPs[@]}"

LIFN=`ls /sys/bus/pci/devices/${LPCIDEV}/net/`
LIFN=${LIFN/\/};

if [ -e /sys/bus/pci/devices/$LPCIDEV/virtfn0 ]; then
    ifconfig ${LIFN}_0 >& /dev/null
    if [[ $? == 0 ]]; then
      VFN=(`ls /sys/bus/pci/devices/${LPCIDEV}/virtfn*/net/`);
    else
      VFN=(dummy $LIFN `ls /sys/bus/pci/devices/${LPCIDEV}/virtfn*/net/`);
    fi
  for i in $( seq 1 2 ${#VFN[@]} ); do
    IP=`ip addr show ${VFN[$i]} | grep -E 'inet.*global' | awk '{print $2}'`
    IP=${IP///24/}
    BIP=(${BIP[@]} "-B $IP")
  done
else
    BIP=(`ip a s dev $LIFN | awk '/inet / {sub(/\/24/,"",$2); print "-B " $2}'`)
fi

#echo "${BIP[@]}"
#[[ $NoT -gt 16 ]] && NoTO=16 || NoTO=$NoT
[[ "$OF_MODE" == "full" ]] && MSZ="-M 1350"

for i in $(seq $skip $(( NoT - 1 + skip )) )
do
    j=$(( i - skip ))
    corei=$(( i + CO - skip ))
    cmd="taskset -c ${cores[$corei]} iperf3 $MSZ -c ${RIPs[$i]} -P1 --logfile ${FIFO_DIR}fifo${j} ${BIP[@]:$((2*i)):2} -t $RUNTIME $DIR &"
    echo $cmd
    eval "$cmd"
done    
wait 
