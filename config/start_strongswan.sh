#!/usr/bin/bash

source ../config.dat

SETHOST=${1:-both}

if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then
  echo "Restarting strongswan on the local host ..."

  ssh -x $LCTRLR /bin/bash <<EOF
    service strongswan restart
EOF
fi

echo

if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then
  echo "Restarting strongswan on the remote host ..."

  ssh -x $RCTRLR /bin/bash <<EOF
    service strongswan restart
EOF
fi
