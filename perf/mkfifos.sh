#!/usr/bin/bash

source ../common_config.sh


NoF=${1:-$VFS}

if [ ! -d $FIFO_DIR ]; then
    mkdir -p $FIFO_DIR
fi

for i in $( seq 0 $(( NoF - 1 )) ); do
 if [ ! -p "${FIFO_DIR}fifo${i}" ]; then
    cmd="mknod ${FIFO_DIR}fifo${i} p"
    echo $cmd
    $cmd
 fi
done

