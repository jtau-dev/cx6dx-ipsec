#!/usr/bin/bash

N=${1:-1}
BR='ovs-br'
REMOTE_SERVER="10.7.159.36 -p 2222"
S=($(seq 0 $(( N - 1 ))))

echo "Bridging local SNIC VF repreentors ..."
for i in ${S[@]} 
do
  cmd="ovs-vsctl add-port $BR pf0vf${i}"
  echo $cmd
  eval $cmd
  ifconfig pf0vf${i} up
done

echo "Bridging remote SNIC VF representors ..."
ssh -x $REMOTE_SERVER /bin/bash << EOF
#!/usr/bash

for i in ${S[@]}
do
  cmd="ovs-vsctl add-port $BR pf0vf\${i}"
  echo \$cmd 
  eval \$cmd
  ifconfig pf0vf\${i} up
done

EOF


