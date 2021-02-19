#!/bin/bash
set -x #echo on

VXLAN_IF_NAME=vxlan_sys_4789
PF0=p0
VF0_REP=pf0hpf
OUTER_REMOTE_IP=192.168.1.65
OUTER_LOCAL_IP=192.168.1.64
REMOTE_SERVER=${1:-10.7.158.168}

#configuring PF and PF representor
ifconfig $PF0 $OUTER_LOCAL_IP/24 up
ifconfig $PF0 up
#ifconfig $VF0 $INNER_LOCAL_IP/24 up
ifconfig $VF0_REP up
ip link del vxlan_sys_4789
#ip link add vxlan_sys_4789 type vxlan id 100 dev ens1f0 dstport 4789

# adding hw-tc-offload on
#echo update hw-tc-offload to $PF0 and $VF0_REP
ethtool -K $VF0_REP hw-tc-offload off
ethtool -K $PF0 hw-tc-offload off

service openvswitch start
ovs-vsctl del-br ovs-br
ovs-vsctl add-br ovs-br
ovs-vsctl add-port ovs-br $VF0_REP
#ovs-vsctl add-port ovs-br $PF0
ovs-vsctl add-port ovs-br vxlan11 -- set interface vxlan11 type=vxlan options:local_ip=$OUTER_LOCAL_IP options:remote_ip=$OUTER_REMOTE_IP options:key=100 options:dst_port=4789

ovs-vsctl set Open_vSwitch . other_config:hw-offload=false
service openvswitch restart
ifconfig ovs-br up
ovs-vsctl show

OUTER_REMOTE_IP=192.168.1.64
OUTER_LOCAL_IP=192.168.1.65
PF0=p0
VF0_REP=pf0hpf
ssh $REMOTE_SERVER /bin/bash << EOF
	#configuring PF and PF representor
	ifconfig $PF0 $OUTER_LOCAL_IP/24 up
	ifconfig $PF0 up
#	ifconfig $VF0 $INNER_LOCAL_IP/24 up
	ifconfig $VF0_REP up
	ip link del vxlan_sys_4789
#	ip link add vxlan_sys_4789 type vxlan id 100 dev ens1f0 dstport 4789

	# adding hw-tc-offload on
	echo update hw-tc-offload to $PF0 and $VF0_REP
	ethtool -K $VF0_REP hw-tc-offload off
	ethtool -K $PF0 hw-tc-offload off
	
	service openvswitch start
	ovs-vsctl del-br ovs-br
	ovs-vsctl add-br ovs-br
	ovs-vsctl add-port ovs-br $VF0_REP
#	ovs-vsctl add-port ovs-br $PF0
	ovs-vsctl add-port ovs-br vxlan11 -- set interface vxlan11 type=vxlan options:local_ip=$OUTER_LOCAL_IP options:remote_ip=$OUTER_REMOTE_IP options:key=100 options:dst_port=4789
	
	ovs-vsctl set Open_vSwitch . other_config:hw-offload=false
	service openvswitch restart
	ifconfig ovs-br up
	ovs-vsctl show
EOF
