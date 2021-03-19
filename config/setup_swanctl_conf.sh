#!/usr/bin/bash
#
# setup_swanctl_conf.sh -
#  
#  Create left/right swanctl configuration files.
#
#
#

function usage() {
    SCRPTNAME=$0
    echo "${SCRPTNAME} -- Simple script to set up strongSwan configuration files."
    echo "   : Setup IPSec transport layer.  Left/right hosts."
    echo "   : -h, --help This list."
    echo "   : -c Connection label."
    echo "   : -f Left/right configuration file name suffix."
    echo "   : -m Operation [transport/tunnel] mode."
    echo "   : -n Number of SAs."
    echo "   : -o Offload [yes/no/full]."
    echo "   : -s SA label for child(ren) SAs."
    echo "   : -v Verbose"
    echo
    echo " "
    exit 0
}


source ../config.dat

NoSA=$VFS
CXN="Connection-1"
SAN="hh"
GW_FILE=gw.conf
LH=host1
RH=host2

OPTS=`getopt -o c:f:m:n:o:s:vh --long help -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

while true; do
    case "$1" in
	-c ) CXN="$2"; shift;shift ;;
	-f ) FSX="_$2"; shift;shift ;;
	-m ) OP_MODE="$2"; shift;shift ;;
	-n ) NoSA="$2"; shift;shift ;;
	-o ) OF_MODE="$2"; shift;shift ;;
	-s ) SAN="$2"; shift;shift ;;
	-v ) VERBOSE=true; shift;shift ;;
	-h ) usage; break;;
	* ) break ;;
    esac
done


LEFT="left${FSX}.conf"
RIGHT="right${FSX}.conf"
[ "$VERBOSE" == "true" ] && set -x

# section 1
sed_script="s/cxn%/$CXN/g;s/localaddr%/$GW_LIP/g;s/remoteaddr%/$GW_RIP/g;s/lhost%/$LH/g;s/rhost%/$RH/g"
sed_script2="s/cxn%/$CXN/g;s/localaddr%/$GW_RIP/g;s/remoteaddr%/$GW_LIP/g;s/lhost%/$RH/g;s/rhost%/$LH/g"
sed "$sed_script" ../strongswan/${GW_FILE%.*}_1.${GW_FILE##*.} > /tmp/.${LEFT}
sed "$sed_script2" ../strongswan/${GW_FILE%.*}_1.${GW_FILE##*.} > /tmp/.${RIGHT}

# section 2
LTIP=(`echo $LVFIP0 | sed "s/\./ /g"`)
RTIP=(`echo $RVFIP0 | sed "s/\./ /g"`)
if [[ "$OP_MODE" == "transport" ]]; then
    OPM="mode = transport"
fi
    LB2=${LTIP[2]}
    RB2=${RTIP[2]}
    
for ((i=0;i<$NoSA;i++)) {
    ltip=`echo ${LTIP[@]} | tr ' ' '.'`
    rtip=`echo ${RTIP[@]} | tr ' ' '.'`
    sed_script="s/hh%/${SAN}$i/g;s/ltaddr%/$ltip/g;s/rtaddr%/$rtip/g;s/op_mode%/$OPM/g;s/ol%/$OF_MODE/"
    sed_script2="s/hh%/${SAN}$i/g;s/ltaddr%/$rtip/g;s/rtaddr%/$ltip/g;s/op_mode%/$OPM/g;s/ol%/$OF_MODE/"    
    sed "$sed_script" ../strongswan/${GW_FILE%.*}_2.${GW_FILE##*.} >> /tmp/.${LEFT}
    sed "$sed_script2" ../strongswan/${GW_FILE%.*}_2.${GW_FILE##*.} >> /tmp/.${RIGHT}
    (( LTIP[2]++ ))
    (( RTIP[2]++ ))

}
# Section 3

sed_script="s/lhost%/$LH/g;s/rhost%/$RH/g"
sed_script2="s/lhost%/$RH/g;s/rhost%/$LH/g"
sed "$sed_script" ../strongswan/${GW_FILE%.*}_3.${GW_FILE##*.} >> /tmp/.${LEFT}
sed "$sed_script2" ../strongswan/${GW_FILE%.*}_3.${GW_FILE##*.} >> /tmp/.${RIGHT}

ssh -x $LCTRLR '[ ! -d ${SWC_DIR}/tmp/i ] && mkdir ${SWC_DIR}/tmp'
#ssh -x $RCTRLR '[ ! -d ${SWC_DIR}/tmp/i ] && mkdir ${SWC_DIR}/tmp'
scp /tmp/.${LEFT} ${LCTRLR}:${SWC_DIR}/tmp/$LEFT
#scp /tmp/.${RIGHT} ${RCTRLR}:${SWC_DIR}/tmp/$RIGHT

