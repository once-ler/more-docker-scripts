#!/bin/bash
: "${OPTIONS:=}" # Mongo options

IP=$(ip -o -4 addr list eth0 | perl -n -e 'if (m{inet\s([\d\.]+)\/\d+\s}xms) { print $1 }')
echo "WORKER_IP=$IP"

if [[ ${OPTIONS} == *"setupReplicaSet"* ]]
then
  : "${WORKERNUM:=}" # worker number
  echo "Updating setupReplicaSet.js for ${WORKERNUM}" 
  # update setupReplicaSet.js
  sed -i "s/@WORKERNUM@/$WORKERNUM/g" /root/jsfiles/setupReplicaSet.js
fi

# Start mongo and log
/usr/bin/mongo$OPTIONS