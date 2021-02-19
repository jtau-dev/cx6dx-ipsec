#!/usr/bin/bash
set -x

VFS=${1:-2}
SETHOST=${2:-both}

LHOST=host
RHOST=10.7.159.36
LIF=enp175s0f0
RIF=enp175s0f0

if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then
ssh $LHOST << EOF
#!/usr/bin/bash
echo 0 > /sys/class/net/$LIF/device/sriov_numvfs
echo $VFS > /sys/class/net/$LIF/device/sriov_numvfs
EOF
fi

if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then

ssh $RHOST << EOF
#!/usr/bin/bash

echo 0 > /sys/class/net/$RIF/device/sriov_numvfs
echo $VFS > /sys/class/net/$RIF/device/sriov_numvfs
EOF
fi


