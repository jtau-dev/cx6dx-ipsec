# cx6dx-ipsec

Supporting Assets Directory

Contains various scripts to facilitate the configuration and
performance testing of ConnectX-6DX/BlueField-2 IPSec offload.

These are the quick-and-dirty scripts.

1. common_config.sh
2. config.dat
3. config/
   a. setup_devlink.sh
   b. setup_vxlan_ovs.sh
   c. setup_hostvfs.sh
   d. setup_hostvfips.sh
   e. ovs_add_ports.sh
   f. setup_hostips.sh
   g. setup_vf_mtu.sh
   h. setup_swanctl_conf.sh
   i. select_swconf.sh
   j. start_swanctl.sh
   k. swc.sh
4. kernel/
   a. offload_patches.tar.bz2
   b. defconfig
5. strongswan/
   a. gw_[123].conf
6. perf/
   a. mkfifos.sh
   b. iperf3_server.sh
   c. iperf3_clients.sh
   d. perfsum2.pl
               


