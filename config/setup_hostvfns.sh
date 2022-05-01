#!/bin/bash
# setup_hostvfips.sh [offload on/off] [local/remote/both]
#set -x #echo on
source ../common_config.sh


SETHOST=${1:-both}
OFFLOAD=${2:-"on"}

if [[ "$OFFLOAD" == "local" || "$OFFLOAD" == "remote" || \
        "$OFFLOAD" == "both" ]]; then
    T=$SETHOST
    SETHOST=$OFFLOAD
    OFFLOAD=$T
fi

case "$SETHOST" in
    "local"|"remote"|"both")
	;;
    *)
	SETHOST="both"
	;;
esac     


if [[ "$SETHOST" == "both" || "$SETHOST" == "local" ]]; then
  echo "Setting local host VF namespaces ..."
  set_host_vf_ns $LHOST $LPCIDEV $LVFIP0 $OFFLOAD
fi

if [[ "$SETHOST" == "both" || "$SETHOST" == "remote" ]]; then
  echo "Setting remote host VF namespaces ..."
  set_host_vf_ns $RHOST $RPCIDEV $RVFIP0  $OFFLOAD
fi

