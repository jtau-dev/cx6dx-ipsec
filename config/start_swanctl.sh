#!/usr/bin/bash

source ../config.dat

conn=${1:-hh}

ssh -x $RCTRLR /bin/bash <<EOF
  service strongswan-starter restart
  sleep 2
  swanctl --load-all
EOF

ssh -x $LCTRLR /bin/bash <<EOF
  service strongswan-starter restart
  sleep 2
  swanctl --load-all
  swanctl -i --child $conn
EOF
