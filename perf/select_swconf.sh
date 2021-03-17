#!/usr/bin/bash

OPTS=`getopt -o dv --long help -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

while true; do
    case "$1" in
	-d ) DELFILES=true; shift;shift ;;
	-v ) set -x; shift;shift ;;
	* ) break ;;
    esac
done

function isNum() {
 if [[ $1 =~ ^[0-9]+$ ]]; then
   return 1
 else
   return 0
 fi
}

function getEntry() {
#echo "CNT = " $1
while :
do
  echo -n "Which entry? "
  read ENTRY
  if ! isNum $ENTRY && [ $ENTRY -le $1 ]; then 
    return 1
  else
    echo "Invalid entry."
  fi
done
}


SWC_CONF=${1}
SWC_DIR="/usr/local/etc/swanctl"
SWC_CONF_DIR=${SWC_DIR}/conf.d/tmp


if [ -e ${SWC_CONF_DIR} ]; then
    if [  -e ${SWC_CONF_DIR}/$SWC_CONF ] && [[ "$SWC_CONF" != "" ]]; then
	conf=$SWC_CONF
    else	
	i=1
	CONFs=(`ls ${SWC_CONF_DIR}/*.conf`)
	CNT=${#CONFs[@]}
	if [ $CNT > 1 ]; then
	    for (( i=0; i<$CNT; i++ )); do
		conf=${CONFs[$i]}
		echo $((i+1)). `basename $conf`
	    done
	    getEntry $CNT
	    ((ENTRY--))
	else
	    ENTRY=0
	fi
	conf=${CONFs[$ENTRY]}
    fi
    
    if [ "$DELFILES" == true ]; then
	find ${SWC_DIR}/conf.d -type l -exec rm -f {} \; -print && echo "Removed extraneous links"
    fi
    echo "Enabled $conf"
    ln -s $conf ${SWC_DIR}/conf.d/. >& /dev/null	
fi
