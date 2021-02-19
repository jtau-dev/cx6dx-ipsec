#!/bin/bash
#set -x #echo on
LHOST=host
RHOST=host2
LIF=enp24s0f0
RIF=enp59s0f0
LPPFX=enp
RPPFX=enp
SETHOST=${1:-both}


get_netdevs (){
PPFX=$1
ibdev2netdev -v | sort -t : -k3,3 | awk '{if (\$10 == "DOWN") print \$13 else print \$12}' | grep \$PPFX
}

if [[ "$SETHOST" == "both" || "$SETHOST" == "local" ]]; then
echo "Setting local host VF IPs ..."
ssh -t $LHOST << EOF
#!/usr/bin/bash
#set -x

netdevs=($LIF \`ibdev2netdev -v | sort -t : -k3,3 | awk '{if (\$10 == "(DOWN") print \$13; else print \$12}' | grep $LPPFX\`)
i=0
for ND in \${netdevs[@]}; do
    cmd="ifconfig \$ND 2.2.\$i.1/24 up"
    echo \$cmd
    eval "\$cmd"
    i=\$((i+1))
done
EOF
fi


if [[ "$SETHOST" == "both" || "$SETHOST" == "remote" ]]; then
echo "Setting remote host VF IPs ..."
ssh -t $RHOST << EOF
#!/usr/bin/bash
#set -x

netdevs=($RIF \`ibdev2netdev -v | sort -t : -k3,3 | awk '{if (\$10 == "(DOWN") print \$13; else print \$12}' | grep $RPPFX\`)
i=0
for ND in \${netdevs[@]}; do
    cmd="ifconfig \$ND 2.2.\$i.2/24 up"
    echo \$cmd
    eval "\$cmd"
    i=\$((i+1))
done
EOF
fi

