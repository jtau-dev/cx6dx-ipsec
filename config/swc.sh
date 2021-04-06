#!/usr/bin/bash
#
# swc.sh - 
#
#  Wrapper script for swanctl execution on the strongswan controller.
#  Location of where to run is set in the <config.dat> file, with
#  the variable LCTRLR, which is the IP of the IPSec controller.
#  This is the BF2 IP (oob_net0 or tmfifo_net0) if transparent IPSec,
#  or the host IP if host-aware IPSec, is desired.
#
#  Run
#
#        swc.sh -i -s 0 -e 0
#
#  on the LHOST to invoke "swanctl -i --child hh0" on the LCTRLR.
#

function usage() {
    SCRPTNAME=$0
    echo "${SCRPTNAME} -- swanctl remote wrapper."
    echo ""
    echo "   : -h, --help This list."
    echo "   : -i swanctl --initiate."
    echo "   : -t swanctl --terminate."
    echo "   : -s child label start index.  Default 0"
    echo "   : -e child label end index.  Default 0"
    echo "   : -n child label. Default label is \"hh\"."
    echo "   : -v Verbose"
    echo " "
    exit 0
}

source ../config.dat
S=0
E=0
CN=hh
CMD="-i"

OPTS=`getopt -o its:e:n:vh --long help -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

while true; do
   case "$1" in
     -i ) CMD="-i"; shift;;
     -s ) S=$2; shift; shift ;;
     -e ) E=$2; shift; shift;;
     -n ) CN=$2; shift; shift;;
     -t ) CMD="-t"; shift;;  
     -v ) set -x; shift;shift ;;
     -h ) usage; shift;shift ;;
      * ) break ;;
   esac
done

shopt -s lastpipe
ssh -x $LCTRLR <<EOF
  for ((i=$S; i<=$E; i++)); do
     cmd="swanctl $CMD --child $CN\$i"
     echo \$cmd
     eval '\$cmd'
   done
EOF
