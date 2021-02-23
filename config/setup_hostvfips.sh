#!/bin/bash
#set -x #echo on
source ../common_config.sh

SETHOST=${1:-both}


if [[ "$SETHOST" == "both" || "$SETHOST" == "local" ]]; then
  echo "Setting local host VF IPs ..."
  set_host_vf_ips $LHOST $LMLXID $LVFIP0
fi

if [[ "$SETHOST" == "both" || "$SETHOST" == "remote" ]]; then
  echo "Setting remote host VF IPs ..."
  set_host_vf_ips $RHOST $RMLXID $RVFIP0  
fi

