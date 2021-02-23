#!/usr/bin/bash

source ../common_config


NoF=${1:-1}

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

