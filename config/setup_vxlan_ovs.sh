#!/bin/bash


source ../common_config.sh

set -x #echo on
SETHOST=${1:-both}

if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then
  set_vxlan_ovs $LCTRLR $LCMLXID $GW_LIP $GW_RIP $LVFIP0
fi

if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then
  set_vxlan_ovs $RCTRLR $RCMLXID $GW_RIP $GW_LIP $RVFIP0
fi
