#!/usr/bin/bash
# setup_vf_mtu.sh [MTU] [local/remost/both]
# Sets N VFs on one, two, or both serves.

source ../common_config.sh
set -x

MYMTU=${1:-${MTU}}
MYSETHOST=${2:-both}

if [[ $MYMTU =~ [\^0-9+$] && ! $MYMTU =~ [A-Za-z] ]]; then
    MTU=$MYMTU
elif [[ "$MYMTU" == "local" || "$MYMTU" == "remote" || \
        "$MYMTU" == "both" ]]; then
    SETHOST=$MYMTU
fi

case "$SETHOST" in
    "local"|"remote"|"both")
	;;
    *)
	SETHOST="both"
	;;
esac     

#echo $VFS
#echo $SETHOST

if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then
    set_host_vf_mtu $LHOST $LPCIDEV
fi

if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then
    set_host_vf_mtu $RHOST $RPCIDEV
fi


