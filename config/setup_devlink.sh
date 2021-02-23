#!/bin/bash
# setup_devlink.sh [remote/local/both] 
# Configures the kernel for IPSec offload
#

# Get configuration data
source ../common_config.sh

#set -x #echo on

SETHOST=${1:-both}


if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then
  echo "Configuring local host ..."
  setdevlink $LCMLXID $LCTRLR
fi


if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then
  echo "Configuring remote host ..."
  setdevlink $RCMLXID $RCTRLR
fi

