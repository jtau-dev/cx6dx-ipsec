#!/usr/bin/bash
set -x

echo 0 > /sys/class/infiniband/mlx5_0/device/mlx5_num_vfs

/opt/mellanox/iproute2/sbin/devlink dev eswitch set pci/0000:18:00.0 mode legacy                                             
echo dmfs > /sys/bus/pci/devices/0000\:18\:00.0/net/enp24s0f0/compat/devlink/steering_mode
echo none > /sys/class/net/enp24s0f0/compat/devlink/ipsec_mode
#echo 0000:18:00.2 >  /sys/bus/pci/drivers/mlx5_core/unbind
echo full > /sys/class/net/enp24s0f0/compat/devlink/ipsec_mode                                                              
/opt/mellanox/iproute2/sbin/devlink dev eswitch set pci/0000:18:00.0 mode switchdev   
#echo 0000:18:00.2 >  /sys/bus/pci/drivers/mlx5_core/bind

