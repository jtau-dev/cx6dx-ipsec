#!/usr/bin/bash

source ../config.dat

NUMA=`cat /sys/class/infiniband/$LMLXID/device/numa_node`
NUMA_CORES=`lscpu | grep "NUMA node$NUMA" | awk '{print $4}'`
NUMA_CORES=${NUMA_CORES//,/ }
NUMA_CORES2=`lscpu | grep "NUMA node" | grep -v "NUMA node$NUMA" | awk '{print $4}'`
NUMA_CORES2=${NUMA_CORES2//,/ }
NC=(${NUMA_CORES[@]} ${NUMA_CORES2[@]} ${NUMA_CORES[@]} ${NUMA_CORES2[@]})

CIF=`ls /sys/class/infiniband/$LCMLXID/device/net`
CIF=${CIF/\//}
IRQ=(`show_irq_affinity.sh $CIF | cut -d" " -f1`)
NIRQ=${#IRQ[@]}

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

  irq=${irq/:/}
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



