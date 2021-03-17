#!/usr/bin/bash
source ./config.dat

function setdevlink() {
# setdevlink [mlx_id] [controller IP] [type=full/crypto]
  CMLXID=$1
  CTRLR=$2
  TYPE=$3
  
  ssh -x $CTRLR /bin/bash <<EOF
     set -x #echo on

     ip x s f
     ip x p f
     CIF=\`ls /sys/class/infiniband/$CMLXID/device/net\`
     CIF=\${CIF/\//}
     PCIDEV=\`mst status -v | grep \$CIF | awk '{print \$3}'\`
     PCIDEV="0000:\$PCIDEV"
     echo 0 > /sys/class/infiniband/${CMLXID}/device/mlx5_num_vfs
     devlink dev eswitch set pci/\${PCIDEV} mode legacy
     echo dmfs > /sys/bus/pci/devices/\${PCIDEV}/net/\${CIF}/compat/devlink/steering_mode
     if [[ $TYPE == "full" ]]; then
       echo full > /sys/class/net/\${CIF}/compat/devlink/ipsec_mode
       devlink dev eswitch set pci/\${PCIDEV} mode switchdev
     fi
     service openvswitch stop
EOF
}

function set_host_vfs() {
# setvfs [host IP] [host device mlx id]
    
  HOST=$1
  MLXID=$2
  
  ssh -x $HOST /bin/bash <<EOF
  service NetworkManager stop
  set -x
  echo "$VFS > /sys/class/infiniband/${MLXID}/device/mlx5_num_vfs"
  echo "$VFS" > /sys/class/infiniband/${MLXID}/device/mlx5_num_vfs
  
EOF
}

function set_ovs() {
# set_ovs [controller IP] [controller MLXID] [Offload=on/off]
    
  CTRLRIP=$1
  CMLXID=$2
  OFFLOAD=${3:-"on"}

  if [[ "$OFFLOAD" == "on" ]]; then
      OFL="true"
  else
      OFL="false"
  fi
  
  ssh $CTRLRIP /bin/bash << EOF
    set -x
    service NetworkManager stop
    CIF=\`ls /sys/class/infiniband/$CMLXID/device/net\`
    CIF=\${CIF/\//}
    PF0=\$CIF
    VF0=\`ls /sys/class/infiniband/$CMLXID/device/virtfn0/net/ 2> /dev/null\`
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
    fi
    # adding hw-tc-offload on
    echo update hw-tc-offload to \$PF0 and \$VF0_REP
  
    ethtool -K \$PF0 hw-tc-offload $OFFLOAD
    ifconfig \$PF0 $OUTER_LOCAL_IP up
    service openvswitch start
    ovs-vsctl del-br $OVSBR
    ovs-vsctl add-br $OVSBR
    ovs-vsctl add-port $OVSBR \$VF0_REP
	
   ovs-vsctl set Open_vSwitch . other_config:hw-offload=$OFL
   service openvswitch restart
   ifconfig $OVSBR up
   ovs-vsctl show
EOF
}

function set_vxlan_ovs() {
# set_vxlan_ovs [controller IP] [controller MLXID] [Local GW IP] [Remote GW IP] [VFIP0] [Offload=on/off]
    
  CTRLRIP=$1
  CMLXID=$2
  OUTER_LOCAL_IP=$3
  OUTER_REMOTE_IP=$4
  VF0IP=$5
  OFFLOAD=${6:-"on"}

  if [[ "$OFFLOAD" == "on" ]]; then
      OFL="true"
  else
      OFL="false"
  fi
  
  ssh $CTRLRIP /bin/bash << EOF
    set -x
    service NetworkManager stop
    CIF=\`ls /sys/class/infiniband/$CMLXID/device/net\`
    CIF=\${CIF/\//}
    PF0=\$CIF
    VF0=\`ls /sys/class/infiniband/$CMLXID/device/virtfn0/net/ 2> /dev/null\`
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
  
    ethtool -K \$VF0_REP hw-tc-offload $OFFLOAD
    ethtool -K \$PF0 hw-tc-offload $OFFLOAD
    ifconfig \$PF0 $OUTER_LOCAL_IP up
    service openvswitch start
    ovs-vsctl del-br $OVSBR
    ovs-vsctl add-br $OVSBR
    ovs-vsctl add-port $OVSBR \$VF0_REP
    ovs-vsctl add-port $OVSBR vxlan${VXLAN_ID} -- set interface vxlan${VXLAN_ID} type=vxlan \
    options:local_ip=$OUTER_LOCAL_IP options:remote_ip=$OUTER_REMOTE_IP options:key=$VXLAN_KEY \
    options:dst_port=$VXLAN_PORT
	
   ovs-vsctl set Open_vSwitch . other_config:hw-offload=$OFL
   service openvswitch restart
   ifconfig $OVSBR up
   ovs-vsctl show
EOF
}

function add_ovs_vxlan_ports() {
# add_ovs_vxlan_ports [server IP] [Controller MLX DEVID]
    CTRLRIP=$1
    CMLXID=$2

    ssh $CTRLRIP /bin/bash << EOF
      NOVFS=($(seq 0 $(( $VFS - 1 ))))
      CIF=\`ls /sys/class/infiniband/$CMLXID/device/net\`
      CIF=\${CIF/\//}
      VF0=\`ls /sys/class/infiniband/$CMLXID/device/virtfn0/net/ 2> /dev/null\`
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
# set_host_vf_ips [HOST] [MLXID] [VF0IP] [offload]
    
  HOST=$1
  HMLXID=$2
  VF0IP=$3
  OFL=${4:-"on"}
  ssh -x $HOST /bin/bash <<EOF
    #set -x
    CIF=\`ls /sys/class/infiniband/$HMLXID/device/net\`
    CIF=\${CIF/\//}
    IPB=(`echo $VF0IP | sed "s/\./ /g"`)
    IP3B=\${IPB[2]}
    #set -x
    ifconfig \${CIF}_0 > /dev/null
    if [[ \$? == 1 ]]; then
      netdevs=(dummy \$CIF \`ls /sys/class/infiniband/$HMLXID/device/virtfn*/net/\`)
    else
      netdevs=(\`ls /sys/class/infiniband/$HMLXID/device/virtfn*/net/\`)
    fi
    for i in \$( seq 1 2 \${#netdevs[@]} ); do
      ND=\${netdevs[\$i]}
      cmd="ifconfig \$ND \${IPB[0]}.\${IPB[1]}.\$IP3B.\${IPB[3]}/24 up"
      cmd2="ethtool -K \$ND hw-tc-offload $OFL"
      IP3B=\$(( \$IP3B + 1 ))
      echo \$cmd
      eval "\$cmd"
      echo \$cmd2
      eval "\$cmd2"
    done
EOF
}

function set_host_ips() {
# set_host_ips [HOST] [MLXID] [VF0IP]
    
  HOST=$1
  HMLXID=$2
  VF0IP=$3

  ssh -x $HOST /bin/bash <<EOF
    #set -x
    CIF=\`ls /sys/class/infiniband/$HMLXID/device/net\`
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
# set_vf_mtu [HOST] [MLXID] [mtu]
    
  HOST=$1
  HMLXID=$2
  HMTU=${3:-$MTU}
  ssh -x $HOST /bin/bash <<EOF
    #set -x

    netdevs=(\`ls /sys/class/infiniband/$HMLXID/device/virtfn*/net/\`)
    for i in \$( seq 1 2 \${#netdevs[@]} ); do
      ND=\${netdevs[\$i]}
      cmd="ip link set dev \$ND mtu $HMTU"
      echo \$cmd
      eval "\$cmd"
    done
EOF
}


