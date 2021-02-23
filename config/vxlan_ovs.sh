#!/bin/bash
set -x #echo on
SETHOST=${1:-both}

if [[ "$SETHOST" == "local" || "$SETHOST" == "both" ]]; then


VXLAN_IF_NAME=vxlan_sys_4790
PF0=enp24s0f0
VF0_REP=enp24s0f0_0
VF0=enp24s0f2
OUTER_REMOTE_IP=192.168.1.65
OUTER_LOCAL_IP=192.168.1.62
REMOTE_SERVER="${1:-10.15.4.240}"

#configuring PF and PF representor
ifconfig $PF0 $OUTER_LOCAL_IP/24 up
ifconfig $PF0 up

#ifconfig $VF0 $INNER_LOCAL_IP/24 up
ifconfig $VF0_REP up
ifconfig $VF0 2.2.2.3/24 up
ip link del ${VXLAN_IF_NAME}
#ip link add vxlan_sys_4789 type vxlan id 100 dev ens1f0 dstport 4789

# adding hw-tc-offload on
#echo update hw-tc-offload to $PF0 and $VF0_REP
ethtool -K $VF0_REP hw-tc-offload on
ethtool -K $PF0 hw-tc-offload on
ethtool -K $VF0 hw-tc-offload on

service openvswitch start
ovs-vsctl del-br ovs-br
ovs-vsctl add-br ovs-br
ovs-vsctl add-port ovs-br $VF0_REP
#ovs-vsctl add-port ovs-br $PF0
ovs-vsctl add-port ovs-br vxlan13 -- set interface vxlan13 type=vxlan options:local_ip=$OUTER_LOCAL_IP options:remote_ip=$OUTER_REMOTE_IP options:key=101 options:dst_port=4790

ovs-vsctl set Open_vSwitch . other_config:hw-offload=true
service openvswitch restart
ifconfig ovs-br up
ovs-vsctl show
fi

if [[ "$SETHOST" == "remote" || "$SETHOST" == "both" ]]; then

OUTER_REMOTE_IP=192.168.1.62
OUTER_LOCAL_IP=192.168.1.65
PF0=p0
VF0_REP=pf0hpf

ssh $REMOTE_SERVER /bin/bash << EOF
	#configuring PF and PF representor
	ifconfig $PF0 $OUTER_LOCAL_IP/24 up
	ifconfig $PF0 up
	ifconfig $VF0_REP up

	ip link del ${VXLAN_IF_NAME}

	# adding hw-tc-offload on
	echo update hw-tc-offload to $PF0 and $VF0_REP
	ethtool -K $VF0_REP hw-tc-offload on
	ethtool -K $PF0 hw-tc-offload on
	
	service openvswitch start
	ovs-vsctl del-br ovs-br
	ovs-vsctl add-br ovs-br
	ovs-vsctl add-port ovs-br $VF0_REP
#	ovs-vsctl add-port ovs-br $PF0
	ovs-vsctl add-port ovs-br vxlan13 -- set interface vxlan13 type=vxlan options:local_ip=$OUTER_LOCAL_IP options:remote_ip=$OUTER_REMOTE_IP options:key=101 options:dst_port=4790
	
	ovs-vsctl set Open_vSwitch . other_config:hw-offload=true
	service openvswitch restart
	ifconfig ovs-br up
	ovs-vsctl show
EOF
fi

