#!/usr/bin/bash

source ../config.dat
LEFT="left.conf"
RIGHT="right.conf"

# Maybe the template can be made to simplify the regular expression here.
LSTR="s/\(local_\)\(.*=\).*[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\(.*\)\$/\1\2 $GW_LIP\3/"
RSTR="s/\(remote_\)\(.*=\).*[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\(.*\)\$/\1\2 $GW_RIP\3/"
sed "$LSTR;$RSTR" ../strongswan/$LEFT > /tmp/.${LEFT}

LSTR="s/\(local_\)\(.*=\).*[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\(.*\)\$/\1\2 $GW_RIP\3/"
RSTR="s/\(remote_\)\(.*=\).*[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\(.*\)\$/\1\2 $GW_LIP\3/"
sed "$LSTR;$RSTR" ../strongswan/$RIGHT > /tmp/.$RIGHT

scp /tmp/.${LEFT} ${LCTRLR}:/etc/swanctl/conf.d/$LEFT
scp /tmp/.${RIGHT} ${RCTRLR}:/etc/swanctl/conf.d/$RIGHT

