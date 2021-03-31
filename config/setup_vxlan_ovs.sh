#!/bin/bash
# setup_vxlan_ovs.sh [local/remote/both] [offload on/off] 
#

source ../common_config.sh

set -x #echo on
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


if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then
  set_vxlan_ovs $LCTRLR $LCPCIDEV $GW_LIP $GW_RIP $LVFIP0 $OFFLOAD
fi

if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then
  set_vxlan_ovs $RCTRLR $RCPCIDEV $GW_RIP $GW_LIP $RVFIP0 $OFFLOAD
fi
