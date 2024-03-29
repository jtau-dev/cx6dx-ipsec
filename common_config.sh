#!/usr/bin/bash
source ./config.dat

function setdevlink() {
# setdevlink [PCIDEV] [controller IP] [type=full/crypto]
  set -x
  PCIDEV="0000:$1"
  CTRLR=$2
  TYPE=$3

  if [[ "$CTRLR" == "$LCTRLR" ]]; then
      HOST=$LHOST
      HPCIDEV="0000:$LPCIDEV"
  else
      HOST=$RHOST
      HPCIDEV="0000:$RPCIDEV"
  fi
  ssh -x $HOST <<EOF
  set -x
  if [ -e /sys/bus/pci/devices/${HPCIDEV}/sriov_numvfs ]; then
      N=\`cat /sys/bus/pci/devices/${HPCIDEV}/sriov_numvfs\`
     if [[ \$N -ne 0 ]]; then
       echo 0 > /sys/bus/pci/devices/${HPCIDEV}/sriov_numvfs
     fi
  fi
EOF
  echo "CTRLR=$CTRLR"
  ssh -x $CTRLR /usr/bin/bash <<EOF
     set -x #echo on

     ip x s f
     ip x p f
     mdevs=(\`devlink dev show | grep auxiliary\`)
#    mdevs=(\`devlink dev show | awk '/mdev/ {print substr(\$0,6,length(\$0))}'\`)
     if [ \${#mdevs[@]} -ne 0 ]; then
        mdevs=(\`mlnx-sf -a show | awk '/SF Index/ {print \$3}'\`)
         for mdev in \${mdevs[@]}; do
          echo "mlnx-sf -a delete -i \$mdev > /dev/null"
           mlnx-sf -a delete -i \$mdev > /dev/null
#            mlnx-sf -a remove --uuid \$mdev > /dev/null
         done
#        mlnx-sf -a remove --uuid \${mdevs[0]} > /dev/null
#        mlnx-sf -a remove --uuid \${mdevs[1]} > /dev/null
     fi
     CIFs=(\`ls /sys/bus/pci/devices/${PCIDEV}/net\`)
     CIF=\${CIFs[0]}
     CIF=\${CIF/\//}
     if [ -e /sys/bus/pci/devices/${PCIDEV}/net/\${CIF}/compat/devlink/steering_mode ]; then
       if [[ "\${CIF}" == "p0" || "\${CIF}" == "p1" ]]; then
          devlink dev eswitch set pci/0000:03:00.0 mode legacy
          devlink dev eswitch set pci/0000:03:00.1 mode legacy
          sleep 1
          echo dmfs > /sys/bus/pci/devices/0000:03:00.0/net/p0/compat/devlink/steering_mode
          echo dmfs > /sys/bus/pci/devices/0000:03:00.1/net/p1/compat/devlink/steering_mode
       else
         devlink dev eswitch set pci/${PCIDEV} mode legacy
         echo dmfs > /sys/bus/pci/devices/${PCIDEV}/net/\${CIF}/compat/devlink/steering_mode
       fi
       if [[ $TYPE == "full" ]]; then
         if [[ "\${CIF}" == "p0" || "\${CIF}" == "p1" ]]; then
           echo full > /sys/class/net/p0/compat/devlink/ipsec_mode
           echo full > /sys/class/net/p1/compat/devlink/ipsec_mode
         else
           echo full > /sys/class/net/\${CIF}/compat/devlink/ipsec_mode
         fi
       else
         if [[ "\${CIF}" == "p0" || "\${CIF}" == "p1" ]]; then
           echo "none" > /sys/class/net/p0/compat/devlink/ipsec_mode
           echo "none" > /sys/class/net/p1/compat/devlink/ipsec_mode
         else
           echo "none" > /sys/class/net/\${CIF}/compat/devlink/ipsec_mode
         fi
       fi
       if [[ "\${CIF}" == "p0" || "\${CIF}" == "p1" ]]; then
         devlink dev eswitch set pci/0000:03:00.0 mode switchdev
         devlink dev eswitch set pci/0000:03:00.1 mode switchdev
       else
         devlink dev eswitch set pci/${PCIDEV} mode switchdev
       fi
     fi
     grep Ubuntu /etc/os-release >& /dev/null
     if [[ \$? == 1 ]]; then
       service openvswitch stop
     else
       service openvswitch-switch stop
     fi
EOF
}

function set_host_vfs() {
# setvfs [host IP] [host PCI device]
    
  HOST=$1
#  MLXID=$2
  PCIDEV="0000:$2"
  
  ssh -x $HOST /bin/bash <<EOF
  service NetworkManager stop
  set -x
  echo "$VFS > /sys/bus/pci/devices/${PCIDEV}/sriov_numvfs"
  echo "$VFS" > /sys/bus/pci/devices/${PCIDEV}/sriov_numvfs
EOF
}


function set_vxlan_ovs() {
# set_vxlan_ovs [controller IP] [controller PCIDEV] [Local GW IP] [Remote GW IP] [VFIP0] [Offload=on/off]
    
  CTRLRIP=$1
#  CMLXID=$2
  PCIDEV="0000:$2"
  OUTER_LOCAL_IP=$3
  OUTER_REMOTE_IP=$4
  VF0IP=$5
  OFFLOAD=${6:-"$OF_MODE"}

  if [[ "$OFFLOAD" == "yes" || "$OFFLOAD" == "full" ]]; then
      OFL="true"
      ETHOFL=on
  else
      OFL="false"
      ETHOFL=off      
  fi
  
  ssh $CTRLRIP /bin/bash << EOF
    set -x
    service NetworkManager stop
#    CIF=\`ls /sys/bus/pci/devices/${PCIDEV}/net\`
#    CIF=\${CIF/\//}
    CIFs=(\`ls /sys/bus/pci/devices/${PCIDEV}/net\`)
    CIF=\${CIFs[0]}
    CIF=\${CIF/\//}
    PF0=\$CIF
    VF0=\`ls /sys/bus/pci/devices/${PCIDEV}/virtfn0/net/ 2> /dev/null\`
    if [[ "\$VF0" == "" ]]; then
      # Controller is BF
       case "\$PF0" in
         p0) 
           VF0_REP="pf0hpf"
         ;;
         p1)
           VF0_REP="pf1hpf"
         ;;
      esac
    else
       VF0_REP=\${PF0}_0
    fi
    # adding hw-tc-offload on
    echo update hw-tc-offload to \$PF0 and \$VF0_REP
  
    ethtool -K \$VF0_REP hw-tc-offload $ETHOFL
    ethtool -K \$PF0 hw-tc-offload $ETHOFL
    ifconfig \$PF0 $OUTER_LOCAL_IP up

    grep Ubuntu /etc/os-release > /dev/null
    if [[ \$? == 1 ]]; then
       OVS="openvswitch"
    else
       OVS="openvswitch-switch"
    fi
    service \$OVS start
    sleep 2
    BRS=(\`ovs-vsctl list-br\`)
    if [ \${#BRS[@]} -gt 0 ]; then
       for br in \${BRS[@]}; do
          ovs-vsctl list-ports \$br | grep -E "\$PF0||\$VF0_REP"
          if [[ \$? == 0 ]]; then
            ovs-vsctl del-br \$br
          fi
       done
    fi
    ovs-vsctl add-br $OVSBR
    ovs-vsctl add-port $OVSBR \$VF0_REP
    ovs-vsctl add-port $OVSBR vxlan${VXLAN_ID} -- set interface vxlan${VXLAN_ID} type=vxlan \
    options:local_ip=$OUTER_LOCAL_IP options:remote_ip=$OUTER_REMOTE_IP options:key=$VXLAN_KEY \
    options:dst_port=$VXLAN_PORT
	
   ovs-vsctl set Open_vSwitch . other_config:hw-offload=$OFL
   service \$OVS restart

   ifconfig \$VF0_REP up
   ifconfig $OVSBR up
   ovs-vsctl show
EOF
}

function add_vxlan_ovs() {
# set_vxlan_ovs [controller IP] [controller PCIDEV] [Local GW IP] [Remote GW IP] [VFIP0] [Offload=on/off]
    
  CTRLRIP=$1
  OUTER_LOCAL_IP=$2
  OUTER_REMOTE_IP=$3

  ssh $CTRLRIP /bin/bash << EOF
    set -x
    BRS=(\`ovs-vsctl list-br\`)
    if [ \${#BRS[@]} -gt 0 ]; then
       for br in \${BRS[@]}; do
         echo $br
       done
    fi
    ovs-vsctl add-port \$br vxlan${VXLAN_ID} -- set interface vxlan${VXLAN_ID} type=vxlan \
    options:local_ip=$OUTER_LOCAL_IP options:remote_ip=$OUTER_REMOTE_IP options:key=$VXLAN_KEY \
    options:dst_port=$VXLAN_PORT
    ovs-vsctl show
EOF
}


function add_ovs_vxlan_ports() {
# add_ovs_vxlan_ports [server IP] [Controller PCIDEV]
    CTRLRIP=$1
    PCIDEV="0000:$2"

    ssh $CTRLRIP /bin/bash << EOF
      NOVFS=($(seq 0 $(( $VFS - 1 ))))
      CIFs=(\`ls /sys/bus/pci/devices/${PCIDEV}/net\`)
      CIF=\${CIFs[0]}
      CIF=\${CIF/\//}

      VF0=\`ls /sys/bus/pci/devices/${PCIDEV}/virtfn0/net/ 2> /dev/null\`
      if [[ "\$VF0" == "" ]]; then
        case "\$CIF" in
          p0)
          VFX_REP=pf0vf
          ;;
          p1)
          VFX_REP=pf1vf
          ;;
        esac
      else
        VFX_REP=\${CIF}_
      fi
      
      for i in \${NOVFS[@]}
        do
          cmd="ovs-vsctl add-port $OVSBR \${VFX_REP}\${i}"
          echo \$cmd 
          eval \$cmd
          ifconfig \${VFX_REP}\${i} up
        done
EOF
}

function set_host_vf_ips() {
# set_host_vf_ips [HOST] [PCIDEV] [VF0IP] [offload]
    
  HOST=$1
  PCIDEV="0000:$2"
  VF0IP=$3
  ETHOFL=${4:-"on"}

  
  ssh -x $HOST /bin/bash <<EOF
    set -x
    CIF=(\`ls /sys/bus/pci/devices/${PCIDEV}/net\`)
    CIF=\${CIF[0]/\//}
    IPB=(\`echo $VF0IP | sed "s/\./ /g"\`)
    IP3B=\${IPB[2]}
    ip l show dev \${CIF}_0 >& /dev/null

    if [[ \$? != 0 ]]; then
# With crypto-offload IPSec, both PF and representor would show.
      netdevs=(dummy \$CIF \`ls /sys/bus/pci/devices/${PCIDEV}/virtfn*/net/\`)
    else
# Full offload IPSec
      netdevs=(\`ls /sys/bus/pci/devices/${PCIDEV}/virtfn*/net/\`)
      if [[ \${#netdevs[@]} == 1 ]]; then
        netdevs=(dummy \${netdevs[@]})
      fi
    fi
    for i in \$( seq 1 2 \${#netdevs[@]} ); do
      ND=\${netdevs[\$i]}
      cmd="ifconfig \$ND \${IPB[0]}.\${IPB[1]}.\$IP3B.\${IPB[3]}/24 up"
      cmd2="ethtool -K \$ND hw-tc-offload $ETHOFL"
      IP3B=\$(( \$IP3B + 1 ))
      echo \$cmd
      eval "\$cmd"
      echo \$cmd2
      eval "\$cmd2"
    done
EOF
}

function set_host_ips() {
# set_host_ips [HOST] [PCIDEV] [VF0IP]
    
  HOST=$1
  PCIDEV="0000:$2"
  VF0IP=$3

  ssh -x $HOST /bin/bash <<EOF
    set -x
    CIF=(\`ls /sys/bus/pci/devices/${PCIDEV}/net\`)
    if [[ \${#CIF[@]} == 1 ]]; then
      CIF=\${CIF[0]/\//}
      NIPs=$VFS
    elif [[ $VFS == 1 ]]; then
      CIF=\`ls /sys/bus/pci/devices/${PCIDEV}/virtfn0/net\`
      NIPs=${NIP:-1}
      echo "NIPs=\$NIPs $NIP"
    else
      echo "Illegal configuration ..."
      exit
    fi
    IPB=(\`echo $VF0IP | sed "s/\./ /g"\`)
    IP2B=\${IPB[2]}
    IP1B=\${IPB[1]}
    #set -x
    for i in \$( seq 0 \$NIPs ); do
      cmd="ip a a \${IPB[0]}.\$IP1B.\$IP2B.\${IPB[3]}/24 dev \$CIF"
      IP2B=\$(( \$IP2B + 1 ))
      if [[ \$IP2B == 255 ]]; then
        IP2B=0
        IP1B=\$(( \$IP1B + 1 ))
      fi
      echo \$cmd
      eval "\$cmd"
    done
    ip link set dev \$CIF up
EOF
}


function set_host_vf_mtu() {
# set_vf_mtu [HOST] [PCIDEV] [mtu]
    
  HOST=$1
  PCIDEV="0000:$2"
  HMTU=${3:-$MTU}
  ssh -x $HOST /bin/bash <<EOF
    #set -x

    netdevs=(\`ls /sys/bus/pci/devices/${PCIDEV}/virtfn*/net/\`)
    for i in \$( seq 1 2 \${#netdevs[@]} ); do
      ND=\${netdevs[\$i]}
      cmd="ip link set dev \$ND mtu $HMTU"
      echo \$cmd
      eval "\$cmd"
    done
EOF
}

function set_host_vf_ns() {
# set_host_vf_ips [HOST] [PCIDEV] [VF0IP] [offload]
    
  HOST=$1
  PCIDEV="0000:$2"
  VF0IP=$3
  ETHOFL=${4:-"on"}

  ssh -x $HOST /bin/bash <<EOF
#    set -x
    devlink dev eswitch show pci/${PCIDEV} | grep switchdev > /dev/null
    if [[ \$? == 1 ]]; then
      echo "Configure ${PCIDEV} to switchdev mode first."
      echo "For example, run setup_devlink.sh"
      exit
    fi
    if [[ ! -e /sys/bus/pci/devices/${PCIDEV}/virtfn0 ]]; then
       echo "No VFs yet.  Run setup_hostvfs.sh first."
       exit
    fi
      netdevs=(\`ls /sys/bus/pci/devices/${PCIDEV}/virtfn*/net\`) 
#      echo "\${netdevs[@]}"

# Add netns
    for i in \$( seq 0 $(( VFS - 1)) ); do
      ip netns | grep netns\$i >& /dev/null
      if [[ \$? == 1 ]]; then
        cmd="ip netns add netns\$i"
        echo \$cmd
        eval "\$cmd"
      else
        echo "nets\$i exists."
      fi
    done

    for (( i=0 ; \$i<\${#netdevs[@]} ; i++ )); do
      ce=\${netdevs[\$i]};
#      echo "ce \$ce"
      ne=\${netdevs[\$(( i + 1 ))]};
#      echo "ne \$ne"

      echo \$ne | grep virtfn > /dev/null
      if [[ \$? == 0 || x"\$ne" == "x" ]]; then
         continue
      fi
      ns=\${ce:40:-5}
      ip l | grep \$ne >& /dev/null
      cmd="ip l s \$ne netns netns\$ns"
      echo "\$cmd"
      eval "\$cmd"
      i=\$(( i + 1 ))
    done
EOF
}

function set_host_vf_ns_ips() {
# set_host_vf_ips [HOST] [PCIDEV] [VF0IP] [offload]
    
  HOST=$1
  PCIDEV="0000:$2"
  VF0IP=$3
  ETHOFL=${4:-"on"}

  if [[ "$VF0IP" == "$LVFIP0" ]]; then
      RIP=$RVFIP0
  else
      RIP=$LVFIP0
  fi
  IPB=(${VF0IP//\./\ })

  RIPA=(${RIP//\./\ })
  IPR="${RIPA[0]}.${RIPA[1]}.0.0/16"
  ssh -x $HOST /bin/bash <<EOF
#    set -x
    NS=(\`/usr/sbin/ip netns | cut -d" " -f1 | sort\`)
#    echo \${NS[@]}
#    IPB=(\`echo $VF0IP | sed "s/\./ /g"\`)

    IP2B=${IPB[2]}
    for ns in \${NS[@]}; do
      LIP="${IPB[0]}.${IPB[1]}.\$IP2B.$REPNODE"
 #     echo "ns \$ns"
      dev=\`ip netns exec \$ns ip a | grep -E '^[0-9]+:' | grep -v 'lo:' | cut -d' ' -f2\`
      dev=\${dev:0:-1}
#      echo "IP2B=\$IP2B"
      cmd="ip netns exec \$ns ip a a ${IPB[0]}.${IPB[1]}.\$IP2B.${IPB[3]}/24 dev \$dev"
      cmd2="ip netns exec \$ns ethtool -K \$dev hw-tc-offload $ETHOFL"
      cmd3="ip netns exec \$ns ip l s dev \$dev up"
      cmd4="ip netns exec \$ns ip r a $IPR via \$LIP dev \$dev"
      ((IP2B++))
      echo \$cmd
      eval "\$cmd"
      echo \$cmd2
      eval "\$cmd2"
      echo "\$cmd3"
      eval "\$cmd3"
      echo "\$cmd4"
      eval "\$cmd4"
      echo ""
    done
EOF
}


function setgwip() {
  PCIDEV="0000:$1"
  HOST=$2
  LGWIP=$3
  RGWIP=$4
  VF0IP=$5

  if [[ "$LGWIP" == "$GW_LIP" ]]; then
    RIP=$LVFIP0
  else
    RIP=$RVFIP0
  fi
	 
#  IPB=(`echo $VF0IP | sed "s/\./ /g"`)  
  IPB=(${VF0IP//\./\ })
  IPR="${IPB[0]}.${IPB[1]}.0.0/16"
  RIPA=(${RIP//\./\ })
  LIP="${RIPA[0]}.${RIPA[1]}.${RIPA[2]}.$REPNODE/24"

  ssh -x $HOST /bin/bash <<EOF
#    set -x
    devlink dev eswitch show pci/${PCIDEV} | grep switchdev > /dev/null
    if [[ \$? == 1 ]]; then
      echo "Run setup_devlink.sh first."
      exit
    fi
    netdevs=(\`ls /sys/bus/pci/devices/${PCIDEV}/net/\`)
    netdev=\${netdevs[0]}
    cmd="ip addr flush dev \$netdev"
    echo "\$cmd"
    eval "\$cmd"
    cmd="ip addr add ${LGWIP}/24 dev \$netdev"
    echo "\$cmd"
    eval "\$cmd"
    # Add host route
    cmd="ip r a $IPR via ${RGWIP}"
    echo "\$cmd"
    eval "\$cmd"
    # Add representor routes
   LIP=$LIP
   B2=${RIPA[2]}
   for (( i = 1; \$i < \${#netdevs[@]};i++ )); do
     netdev=\${netdevs[\$i]}
     cmd="ip a a \$LIP dev \$netdev"
     cmd2="ip l s dev \$netdev up"
     echo "\$cmd"
     eval "\$cmd"
     echo "\$cmd2"
     eval "\$cmd2"
      ((B2++))
     LIP="${RIPA[0]}.${RIPA[1]}.\$B2.$REPNODE/24"
   done
EOF
}
