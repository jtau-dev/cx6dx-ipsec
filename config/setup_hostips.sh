#!/bin/bash
# setup_hostips.sh [local/remote/both]
#set -x #echo on
source ../common_config.sh

SETHOST=${1:-both}

case "$SETHOST" in
    "local"|"remote"|"both")
	;;
    *)
	SETHOST="both"
	;;
esac     


if [[ "$SETHOST" == "both" || "$SETHOST" == "local" ]]; then
  echo "Setting local host VF IPs ..."
  set_host_ips $LHOST $LMLXID $LVFIP0
fi

if [[ "$SETHOST" == "both" || "$SETHOST" == "remote" ]]; then
  echo "Setting remote host VF IPs ..."
  set_host_ips $RHOST $RMLXID $RVFIP0
fi

