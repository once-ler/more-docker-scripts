#!/bin/bash
: "${OPTIONS:=}" # Mongo options

IP=$(ip -o -4 addr list eth0 | perl -n -e 'if (m{inet\s([\d\.]+)\/\d+\s}xms) { print $1 }')
echo "WORKER_IP=$IP"

if [[ ${OPTIONS} == *"setupReplicaSet"* ]]
then
  
  echo "rs.initiate()" >> /root/jsfiles/setupReplicaSet.js

  echo "MEMEBERS => $MEMBERS"

  #split up MEMBERS
  MEMBERS=($MEMBERS)
  for i in "${MEMBERS[@]}"; do
    echo "rs.add(\"${i}:27017\")" >> /root/jsfiles/setupReplicaSet.js
  done

  echo "cfg = rs.conf()" >> /root/jsfiles/setupReplicaSet.js
  echo "cfg.members[0].host = \"${IP}:27017\"" >> /root/jsfiles/setupReplicaSet.js
  echo "rs.reconfig(cfg)" >> /root/jsfiles/setupReplicaSet.js  
  
fi

# Start mongo and log
/usr/bin/mongo$OPTIONS