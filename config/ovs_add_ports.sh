#!/usr/bin/bash

source ../common_config.sh

MYVFS=${1:-${VFS}}
SETHOST=${2:-both}

if [[ $MYVFS =~ [\^0-9+$] && ! $MYVFS =~ [A-Za-z] ]]; then
    VFS=$MYVFS
elif [[ "$MYVFS" == "local" || "$MYVFS" == "remote" || \
        "$MYVFS" == "both" ]]; then
    SETHOST=$MYVFS
fi

case "$SETHOST" in
    "local"|"remote"|"both")
	;;
    *)
	SETHOST="both"
	;;
esac     

if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then
  echo "Bridging local SNIC VF repreentors ..."
  add_ovs_vxlan_ports $LHOST $LMLXID
fi

if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then
  echo "Bridging remote SNIC VF representors ..."
  add_ovs_vxlan_ports $RHOST $RMLXID
fi

