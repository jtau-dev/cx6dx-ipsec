#!/bin/bash
# add_vxlan_ovs.sh [local/remote/both] [offload full/yes/no] 
#
# add a new vxlan using the current config.dat file

source ../common_config.sh

set -x #echo on
SETHOST=${1:-both}
OFFLOAD=${2:-"$OF_MODE"}

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
  add_vxlan_ovs $LCTRLR $GW_LIP $GW_RIP
fi

if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then
  add_vxlan_ovs $RCTRLR $GW_RIP $GW_LIP 
fi
