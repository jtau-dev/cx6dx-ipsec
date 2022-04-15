#!/usr/bin/bash
#

function usage() {
    SCRPTNAME=$0
    echo "${SCRPTNAME} -- Launch [n] iperf3 processes as server[s]"
    echo ""
    echo "   : -h, --help This list."
    echo "   : -n [n] Number processes to launch"
    echo "   : -o [o] Core offset"
    echo "   : -s [s] Skip s IPs. "
    echo "   : -l [local|remote|both(default)] "
    echo "   : -v Verbose"
    echo " "
    exit 0
}


source ../config.dat
skip=0
NoT=${VFS}
CO=0

OPTS=`getopt -o n:o:s:vh --long help -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"
while true; do
    case "$1" in
	-n ) NoT=$2; shift;shift ;;
	-o ) CO=$2; shift;shift ;;
	-s ) skip=$2; shift;shift ;;
	-v ) set -x; shift;shift ;;
       	-h ) usage; shift;shift ;;
	* ) break ;;
    esac
done

ifconfig | grep $RHOST > /dev/null
if [[ $? == 1 ]]; then
  iSERVER=$LHOST
  RPCIDEV="0000:$LPCIDEV"
  PCIDEV="0000:$RPCIDEV"
  RPCIDEV="0000:$LPCIDEV"
  LPCIDEV=$PCIDEV
else
  iSERVER=$RHOST
  LPCIDEV="0000:$LPCIDEV"
  RPCIDEV="0000:$RPCIDEV"
fi



# set -x 
NUMA=`cat /sys/bus/pci/devices/${RPCIDEV}/numa_node`
NUMA_CORES=`lscpu | grep "NUMA node$NUMA" | awk '{print $4}'`
NUMA_CORES=${NUMA_CORES//,/ }

NUMA_CORES2=`lscpu | grep -E 'NUMA node[0-1]' | grep -v "NUMA node$NUMA" | awk '{print $4}'`
NUMA_CORES2=${NUMA_CORES2//,/ }

NC=(${NUMA_CORES[@]} ${NUMA_CORES2[@]} ${NUMA_CORES[@]} ${NUMA_CORES2[@]})
#echo "${NC[@]}"

cores=${NC[@]}
for c in ${NC[@]}; do
  if [[ $c =~ [\-] ]]; then
    C=${c/-/ }
    cores=( ${cores[@]} $(seq $C) )
  else
    cores=(${NC[@]})
  fi
done
#echo "${cores[@]}"

RIFN=(`ls /sys/bus/pci/devices/${RPCIDEV}/net`)
RIFN=${RIFN[0]///};
#echo $RIFN
#set -x

if [ -e /sys/bus/pci/devices/${RPCIDEV}/virtfn0 ]; then 
   if [ -e /sys/bus/pci/devices/${RPCIDEV}/net/${RIFN}_0 ]; then
      VFN=(`ls /sys/bus/pci/devices/${RPCIDEV}/virtfn*/net/`);
      if [[ ${#VFN[@]} == 1 ]]; then 
         VFN=( dummy ${VFN[@]} );
      fi
   else 
      VFN=(dummy $RIFN `ls /sys/bus/pci/devices/${RPCIDEV}/virtfn*/net/`);
   fi; 
    for i in $( seq 1 2 ${#VFN[@]} ); do 
      IP=`ip addr show dev ${VFN[$i]} | awk '/inet / {sub(/\/24/,"",$2); print $2}'`
      IP=${IP///24/}
      IPs=(${IPs[@]} $IP)
    done
else
    IPs=(`ip a s dev $RIFN | awk '/inet / {sub(/\/24/,"",$2); print $2}'`)
fi

#echo ${IPs[@]}
#exit

for i in $( seq $skip $(( NoT - 1 + skip)) )
do
  if [ "$i" -lt "${#IPs[@]}" ]; then
    coren=$(( cores[ i + CO - skip ] ))
    cmd="taskset -c $coren iperf3 -s -B ${IPs[$i]}&"
    echo $cmd
    eval $cmd
  fi
 done
wait



