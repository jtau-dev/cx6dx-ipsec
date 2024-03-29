#!/usr/bin/bash

#Get configuration data
source ../common_config.sh

#set -x #echo on

SETHOST=${1:-both}


if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then
    echo "Configuring local gateway IP ..."
    setgwip $LCPCIDEV $LCTRLR $GW_LIP $GW_RIP $RVFIP0
fi


if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then
    echo "Configuring remote gateway IP ..."
    setgwip $RCPCIDEV $RCTRLR $GW_RIP $GW_LIP $LVFIP0
fi    
