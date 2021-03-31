#!/usr/bin/bash
# setup_hostvfs.sh [#N of VFs to use] [local/remost/both]
# Sets N VFs on one, two, or both serves.

source ../common_config.sh
set -x

MYVFS=${1:-${VFS}}
MYSETHOST=${2:-both}

if [[ $MYVFS =~ [\^0-9+$] && ! $MYVFS =~ [A-Za-z] ]]; then
    VFS=$MYVFS
    SETHOST=$MYSETHOST
else 
    SETHOST=$MYVFS
fi

case "$SETHOST" in
    "local"|"remote"|"both")
	;;
    *)
	SETHOST="both"
	;;
esac     
echo $VFS
echo $SETHOST

if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then
    set_host_vfs $LHOST $LPCIDEV
fi

if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then
    set_host_vfs $RHOST $RPCIDEV
fi


