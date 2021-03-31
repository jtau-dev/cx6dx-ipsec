#!/bin/bash
# setup_devlink.sh [remote/local/both] [full/crypto]
# Configures the kernel for IPSec offload
#

# Get configuration data
source ../common_config.sh

#set -x #echo on

SETHOST=${1:-both}

TYPE=${2:-full}

if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then
  echo "Configuring local host ..."
  setdevlink $LCPCIDEV $LCTRLR $TYPE
fi


if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then
  echo "Configuring remote host ..."
  setdevlink $RCPCIDEV $RCTRLR $TYPE
fi

