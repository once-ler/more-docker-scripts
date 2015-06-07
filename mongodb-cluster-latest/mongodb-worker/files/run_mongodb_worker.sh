#!/bin/bash
: "${OPTIONS:=}" # Mongo options

IP=$(ip -o -4 addr list eth0 | perl -n -e 'if (m{inet\s([\d\.]+)\/\d+\s}xms) { print $1 }')
echo "WORKER_IP=$IP"

echo "OPTIONS=${OPTIONS}"

if [[ ${OPTIONS} == *"addShard"* ]]; then
  echo "SHARDS => $SHARD_MEMBERS"
  #echo "REPLICA_SETS => $REPLICA_SETS"
  echo "" >> /root/jsfiles/addShard.js
  SHARD_MEMBERS=($SHARD_MEMBERS)
  #REPLICA_SETS=($REPLICA_SETS)
  #SHARD_COUNT=${#SHARD_MEMBERS[@]}
  for i in "${SHARD_MEMBERS[@]}"; do
  #for i in `seq 1 $SHARD_COUNT`; do
    #SHARD=${SHARD_MEMBERS[i-1]}
    #REPLICA_SET=${REPLICA_SETS[i-1]}
    #echo "sh.addShard(\"${REPLICA_SET}/${SHARD}:27017\");" >> /root/jsfiles/addShard.js

    echo "sh.addShard(\"${i}:27017\");" >> /root/jsfiles/addShard.js
  done
  #replace @IP@ with "/"
  sed -i "s|@IP@|/|g" /root/jsfiles/addShard.js
  echo "Executing $(cat /root/jsfiles/addShard.js)"
fi

if [[ ${OPTIONS} == *"setupReplicaSet"* ]]; then
  
  #echo "rs.initiate()" >> /root/jsfiles/setupReplicaSet.js

  echo "REPLICA SET MEMBERS => $REPLICA_MEMBERS"
  echo "" >> /root/jsfiles/setupReplicaSet.js
  #split up MEMBERS
  REPLICA_MEMBERS=($REPLICA_MEMBERS)
  for i in "${REPLICA_MEMBERS[@]}"; do
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