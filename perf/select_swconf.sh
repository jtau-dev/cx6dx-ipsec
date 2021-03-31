#!/usr/bin/bash
#
# select_swconf.sh -
#
#  Links inactive swanctl connection files in SWC_DIR/tmp/ to
#  SWC_DIR/ thereby make it active.
#
#  Delete other links if the '-d' switch is given.
# 
#

function usage() {
    SCRPTNAME=$0
    echo "${SCRPTNAME} -- Simple select and enable strongSwan configuration"
    echo "   from a list of available configuration files."
    echo ""
    echo "   : -h, --help This list."
    echo "   : -d Delete other configuration links while linking the active"
    echo "        configuration file."
    echo "   : -f <swanctl.conf file> If found will use. Otherwise provide list"
    echo "        of available configuration files."
    echo "   : -l [local|remote|both(default)] "
    echo "   : -v Verbose"
    echo " "
    exit 0
}

source ../config.dat
LOCATION="both"

OPTS=`getopt -o dl:f:vh --long help -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

while true; do
    case "$1" in
	-d ) DELFILES=true; shift;;
	-f ) SWC_CONF=$2; shift; shift;;
	-l ) LOCATION=$2; shift; shift;;
	-v ) set -x; shift ;;
       	-h ) usage; shift;shift ;;
	* ) break ;;
    esac
done

declare -A CTRLRS

if [[ "$LOCATION" == "remote" || "$LOCATION" == "both" ]]; then
    CTRLRS=([remote]="$RCTRLR")
fi

if [[ "$LOCATION" == "local" || "$LOCATION" == "both" ]]; then
    CTRLRS+=([local]="$LCTRLR")
fi



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


SWC_CONF_DIR=${SWC_DIR}/tmp
KEYS=`printf '%s\n' "${!CTRLRS[@]}" | tac | tr '\n' ' '; echo`
for key in ${KEYS[@]} ; do
  echo "Configuring \"$key\" controller: ${CTRLRS[$key]}"
  
  shopt -s lastpipe
  ssh -x ${CTRLRS[$key]} <<EOF | read CONFs
   #   echo "SWC_DIR = $SWC_DIR"
   #   echo "SWC_CONF_DIR=${SWC_CONF_DIR}"
      if [ -e ${SWC_CONF_DIR} ]; then
	  if [  -e ${SWC_CONF_DIR}/$SWC_CONF ] && [[ "$SWC_CONF" != "" ]]; then
	      conf=${SWC_CONF_DIR}/$SWC_CONF
	  else
	      CONFs=(\`ls ${SWC_CONF_DIR}/*.conf\`)
	      echo "\${CONFs[@]}"
	  fi
      fi
EOF
   CONFs=($CONFs)
   CNT=${#CONFs[@]}
   #echo "CONFs=${CONFs[@]} CNT=$CNT"

   if [ $CNT -gt 1 ]; then
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
#   echo "conf=$conf"

   ssh -x ${CTRLRS[$key]} <<EOF
     if [ "$DELFILES" == true ]; then
       find ${SWC_DIR}/ -type l -exec rm -f {} \; -print && echo "Removed extraneous links"
     fi
     echo "Enabled $conf"
     ln -s $conf ${SWC_DIR}/. >& /dev/null
     echo ""
EOF
done

