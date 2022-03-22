#!/usr/bin/bash
#
#
source ../config.dat

OPTS=`getopt -o d:h --long help -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

while true; do
    case "$1" in
	-d ) DISTRIBUTE="true"; shift;shift ;;
	-v ) VERBOSE=true; shift;shift ;;
	-h ) usage; break;;
	* ) break ;;
    esac
done


LPCIDEV="18:00.0"
PCIDEV="0000:$LPCIDEV"
NUMA=`cat /sys/bus/pci/devices/$PCIDEV/numa_node`
NUMA_CORES=`lscpu | grep "NUMA node$NUMA" | awk '{print $4}'`
NUMA_CORES=${NUMA_CORES//,/ }
NUMA_CORES2=`lscpu | grep "NUMA node" | grep -v "NUMA node$NUMA" | awk '{print $4}'`
NUMA_CORES2=${NUMA_CORES2//,/ }
NC=(${NUMA_CORES[@]} ${NUMA_CORES2[@]} ${NUMA_CORES[@]} ${NUMA_CORES2[@]})

CIF=(`ls /sys/bus/pci/devices/$PCIDEV/net`)
CIF=${CIF[0]/\//}
NETDEVS=(dummy $CIF `ls /sys/bus/pci/devices/$PCIDEV/virtfn*/net`)
echo ${NETDEVS[@]}
exit
IRQ=()
for i in $( seq 1 2 ${#NETDEVS[@]} ); do
    nd=${NETDEVS[$i]}
    cb=`ethtool -l $nd | grep Combined | tail -1 | awk '{print $2}'`
    if [ $cb -ne 1 ]; then
      ethtool -L $nd combined 1
    fi
    eqq=`ethtool -x $nd | grep with | awk '{print $9}'`
    if [ $eqq -ne 1 ]; then
      ethtool -X $nd equal 1
    fi
    irq=`./show_irq_affinity.sh $nd | cut -d" " -f1`
    IRQ=(${IRQ[@]} ${irq/\:/})
    NIRQ=${#IRQ[@]}
done
echo "${IRQ[@]}"

for c in ${NC[@]}; do
    if [[ $c =~ [-] ]]; then
	C=${c/-/ }
	cores=( ${cores[@]} $(seq $C) )
    fi
done
echo "cores = ${cores[@]}"
NCORES=${#cores[@]}
i=0
for irq in ${IRQ[@]}; do
  core=${cores[$i]}
  (( core+=8 ))
  if [ $core -gt 31 ]; then
      (( core-=32 ))
      TA=",00000000"
  fi
  mask=$(( 1 << $core ))        
  T=`printf "%x$TA" ${mask}`
  cmd="echo $T  > /proc/irq/$irq/smp_affinity"
  (( i++ ))
  if [ $i -gt $NCORES ]; then
      i=1
  fi
  echo $cmd
  eval "$cmd"
#  usleep 1000
done    



