
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
  if [ -e /sys/bus/pci/devices/${HPCIDEV}/mlx5_num_vfs ]; then
      N=`cat /sys/bus/pci/devices/${HPCIDEV}/mlx5_num_vfs`
     if [ \$N -ne 0 ]; then
       echo 0 > /sys/bus/pci/devices/${HPCIDEV}/mlx5_num_vfs
     fi
  fi
EOF
  
  ssh -x $CTRLR /bin/bash <<EOF
     set -x #echo on

     ip x s f
     ip x p f
     CIF=\`ls /sys/bus/pci/devices/${PCIDEV}/net\`
     CIF=\${CIF/\//}
     if [ -e /sys/bus/pci/devices/${PCIDEV}/net/\${CIF}/compat/devlink/steering_mode ]; then
       devlink dev eswitch set pci/${PCIDEV} mode legacy
       sleep 1
       echo dmfs > /sys/bus/pci/devices/${PCIDEV}/net/\${CIF}/compat/devlink/steering_mode
       if [[ $TYPE == "full" ]]; then
           echo full > /sys/class/net/\${CIF}/compat/devlink/ipsec_mode
       fi
       devlink dev eswitch set pci/${PCIDEV} mode switchdev
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
  echo "$VFS > /sys/bus/pci/devices/${PCIDEV}/mlx5_num_vfs"
  echo "$VFS" > /sys/bus/pci/devices/${PCIDEV}/mlx5_num_vfs
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
    CIF=\`ls /sys/bus/pci/devices/${PCIDEV}/net\`
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

function add_ovs_vxlan_ports() {
# add_ovs_vxlan_ports [server IP] [Controller PCIDEV]
    CTRLRIP=$1
    PCIDEV="0000:$2"

    ssh $CTRLRIP /bin/bash << EOF
      NOVFS=($(seq 0 $(( $VFS - 1 ))))
      CIF=\`ls /sys/bus/pci/devices/${PCIDEV}/net\`
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
    CIF=\`ls /sys/bus/pci/devices/${PCIDEV}/net\`
    CIF=\${CIF/\//}
    IPB=(`echo $VF0IP | sed "s/\./ /g"`)
    IP3B=\${IPB[2]}
    ip l s \${CIF}_0 >& /dev/null
# With host-aware IPSec, both PF and representor would show.
    if [[ \$? == 1 ]]; then
      netdevs=(dummy \$CIF \`ls /sys/bus/pci/devices/${PCIDEV}/virtfn*/net/\`)
    else
# Transparent IPSec
      netdevs=(\`ls /sys/bus/pci/devices/${PCIDEV}/virtfn*/net/\`)
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
    #set -x
#    CIF=\`ls /sys/class/infiniband/$HMLXID/device/net\`
    CIF=\`ls /sys/bus/pci/devices/${PCIDEV}/net\`
    CIF=\${CIF/\//}
    IPB=(`echo $VF0IP | sed "s/\./ /g"`)
    IP3B=\${IPB[2]}
    #set -x
    for i in \$( seq 0 $VFS ); do
      cmd="ip a a \${IPB[0]}.\${IPB[1]}.\$IP3B.\${IPB[3]}/24 dev \$CIF"
      IP3B=\$(( \$IP3B + 1 ))
      echo \$cmd
      eval "\$cmd"
    done
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


