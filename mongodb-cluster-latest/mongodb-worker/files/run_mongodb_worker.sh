#!/bin/bash
: "${OPTIONS:=}" # Mongo options

IP=$(ip -o -4 addr list eth0 | perl -n -e 'if (m{inet\s([\d\.]+)\/\d+\s}xms) { print $1 }')
echo "WORKER_IP=$IP"

echo "OPTIONS=${OPTIONS}"

if [[ ${OPTIONS} == *"addShard"* ]]; then
  echo "SHARDS => $SHARDS"
  #echo "REPLICA_SETS => $REPLICA_SETS"
  echo "" >> /root/jsfiles/addShard.js
  SHARDS=($SHARDS)
  for i in "${SHARDS[@]}"; do
    echo "sh.addShard(\"${i}:27017\");" >> /root/jsfiles/addShard.js
  done
  echo "Executing $(cat /root/jsfiles/addShard.js)"
fi

if [[ ${OPTIONS} == *"setupReplicaSet"* ]]; then
  
  echo "REPLICA SET MEMBERS => $REPLICA_MEMBERS"
  echo "" >> /root/jsfiles/setupReplicaSet.js
  #split up MEMBERS
  REPLICAS=($REPLICAS)
  for i in "${REPLICAS[@]}"; do
    echo "rs.add(\"${i}:27017\");" >> /root/jsfiles/setupReplicaSet.js
  done
  echo "Executing $(cat /root/jsfiles/setupReplicaSet.js)"
fi

if [[ ${OPTIONS} == *"reconfigure"* ]]; then

  echo "" >> /root/jsfiles/reconfigure.js
  echo "cfg = rs.conf();" >> /root/jsfiles/reconfigure.js
  echo "cfg.members[0].host = \"${PRIMARY_SERVER}:27017\";" >> /root/jsfiles/reconfigure.js
  echo "rs.reconfig(cfg);" >> /root/jsfiles/reconfigure.js

fi

# Start mongo and log
/usr/bin/mongo$OPTIONS