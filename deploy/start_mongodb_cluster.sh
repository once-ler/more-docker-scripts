#!/bin/bash

# Docker interface ip
#DOCKERIP="10.1.42.1"

BASEDIR=$(cd $(dirname $0); pwd)

declare -A HOSTMAP

# use 570XX and 580XX for ports
function createShardContainers() {

  # split the volume syntax by :, then use the array to build new volume map
  IFS=' ' read -ra VOLUME_MAP_ARR_PRE <<< "$VOLUME_MAP"
  IFS=':' read -ra VOLUME_MAP_ARR <<< "${VOLUME_MAP_ARR_PRE[1]}"

  for i in `seq 1 $NUM_WORKERS`; do

    echo "starting worker container"
    # rename $VOLUME_MAP by adding worker number as suffix if it is not empty
    WORKER_VOLUME_MAP=$VOLUME_MAP
    if [ "$VOLUME_MAP" ]; then
      WORKER_VOLUME_DIR="${VOLUME_MAP_ARR[0]}-${i}"      
      for j in `seq 1 $NUM_REPLSETS`; do
        echo "Creating directory ${WORKER_VOLUME_DIR}-${j}"
        mkdir -p "${WORKER_VOLUME_DIR}-${j}"
        mkdir -p "${WORKER_VOLUME_DIR}-${j}/log"    
      done      
    fi
    
    # Create mongd servers
    for j in `seq 1 $NUM_REPLSETS`; do
      HOSTNAME=rs${i}_srv${j}
      # use wiredTiger as storageEngine
      WORKER=$(docker run --dns $NAMESERVER_IP --name ${HOSTNAME} -P -i -d -p 570${i}${j}:27017 -p 580${i}${j}:27018 -v ${WORKER_VOLUME_DIR}-${j}:/data/db -v ${WORKER_VOLUME_DIR}-${j}/log:/data/log -e OPTIONS="d --replSet rs${i} --dbpath /data/db --logpath /data/log/mongod.log --logappend --logRotate reopen --storageEngine wiredTiger --wiredTigerCacheSizeGB 2 --wiredTigerDirectoryForIndexes --noIndexBuildRetry --notablescan --setParameter diagnosticDataCollectionEnabled=false --port 27017" htaox/mongodb-worker:latest)
      sleep 3
      WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
      echo "$HOSTNAME IP: $WORKER_IP"
      HOSTMAP[$HOSTNAME]=$WORKER_IP
    done
   
  done
}

# 3 mirrored config server has been deprecated starting with version 3.2
: '
function createConfigContainersDeprecated() {
  #should have exactly *3* for production
  for i in `seq 1 3`; do
    CONFIG_VOLUME_DIR="${VOLUME_MAP_ARR[0]}-${i}"
    mkdir -p "${CONFIG_VOLUME_DIR}-cfg"
    
    HOSTNAME=mgs_cfg${i}
    WORKER=$(docker run --dns $NAMESERVER_IP --name $HOSTNAME -P -i -d -v ${CONFIG_VOLUME_DIR}-cfg:/data/db -e OPTIONS="d --configsvr --dbpath /data/db --notablescan --noprealloc --smallfiles" htaox/mongodb-worker:latest)
    sleep 3
    WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
    echo "$HOSTNAME IP: $WORKER_IP"
    HOSTMAP[$HOSTNAME]=$WORKER_IP
  done
}
'

# starting with version 3.2, config server should be a replica set
# https://docs.mongodb.org/manual/tutorial/deploy-shard-cluster/#deploy-the-config-server-replica-set
# start all config server as follows: mongod --configsvr --replSet configReplSet --port <port> --dbpath <path>
# initialize as follows
: '
// Connect a mongo shell to one of the config servers and run rs.initiate()
  rs.initiate( {
   _id: "configReplSet",
   configsvr: true,
   members: [
      { _id: 0, host: "<host1>:<port1>" },
      { _id: 1, host: "<host2>:<port2>" },
      { _id: 2, host: "<host3>:<port3>" }
   ]
} )
'
# use 470XX and 480XX for ports
function createConfigContainers() {

  #should have exactly *3* for production
  for i in `seq 1 1`; do
    echo "starting cfg container"

    CONFIG_VOLUME_DIR="${VOLUME_MAP_ARR[0]}-cfg-${i}"    
    
    # Create mongd servers
    for j in `seq 1 3`; do
      echo "Creating directory ${CONFIG_VOLUME_DIR}-${j}"
      mkdir -p "${CONFIG_VOLUME_DIR}-${j}"
      mkdir -p "${CONFIG_VOLUME_DIR}-${j}/log"
      HOSTNAME=cfg${i}_srv${j}
      # use wiredTiger as storageEngine
      WORKER=$(docker run --dns $NAMESERVER_IP --name ${HOSTNAME} -P -i -d -p 470${i}${j}:27017 -p 480${i}${j}:27018 -v ${CONFIG_VOLUME_DIR}-${j}:/data/db -v ${CONFIG_VOLUME_DIR}-${j}/log:/data/log -e OPTIONS="d --port 27017 --configsvr --replSet cfg${i} --dbpath /data/db --logpath /data/log/mongod.log --logappend --logRotate reopen --storageEngine wiredTiger --wiredTigerCacheSizeGB 2 --wiredTigerDirectoryForIndexes --noIndexBuildRetry --notablescan --setParameter diagnosticDataCollectionEnabled=false" htaox/mongodb-worker:latest)
      sleep 3
      WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
      echo "$HOSTNAME IP: $WORKER_IP"
      HOSTMAP[$HOSTNAME]=$WORKER_IP
    done

    #HOSTNAME=mgs_cfg${i}
    #WORKER=$(docker run --dns $NAMESERVER_IP --name $HOSTNAME -P -i -d -v ${CONFIG_VOLUME_DIR}-cfg:/data/db -e OPTIONS="d --configsvr --dbpath /data/db --storageEngine wiredTiger --wiredTigerCacheSizeGB 2 --wiredTigerDirectoryForIndexes --noIndexBuildRetry --notablescan --setParameter diagnosticDataCollectionEnabled=false" htaox/mongodb-worker:latest)
    #sleep 3
    #WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
    #echo "$HOSTNAME IP: $WORKER_IP"
    #HOSTMAP[$HOSTNAME]=$WORKER_IP
  done
}

function setupReplicaSets() {
  #unset REPLICA_MEMBERS
  # for ((i=0; i<3; i++)); do REPLICA_MEMBERS=(${REPLICA_MEMBERS[@]:0:$i} ${REPLICA_MEMBERS[@]:$(($i + 1))}); done
  # explicitly unset 3rd member if found
  # pos=2
  # REPLICA_MEMBERS=(${REPLICA_MEMBERS[@]:0:$pos} ${REPLICA_MEMBERS[@]:$(($pos + 1))})

  # used passed in arg or global var
  WORK=$NUM_WORKERS
  [[ ! -z "${1// }" ]] && WORK=$1
  REPL=$NUM_REPLSETS
  [[ ! -z "${2// }" ]] && REPL=$2
  PRX=rs
  [[ ! -z "${3// }" ]] && PRX=$3

  for i in `seq 1 $WORK`; do
    echo "Initiating Replicat Sets ${HOSTMAP["${PRX}${i}_srv1"]}"
    #yes, _srv1 is correct
    docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" ${HOSTMAP["${PRX}${i}_srv1"]}:27017/local /root/jsfiles/initiate.js" htaox/mongodb-worker:latest
    sleep 20
  done

  for i in `seq 1 $WORK`; do
    #form array, start with *_srv2* and up
    for j in `seq 2 $REPL`; do
      REPLICA_MEMBERS[j]=${HOSTMAP["${PRX}${i}_srv${j}"]}
    done

    REPLICAS_MEMBERS_STRING="${REPLICA_MEMBERS[@]}"
    
    echo "Setting Replicat Sets (setupReplicaSet.js)"
    #yes, _srv1 is correct
    docker run --dns $NAMESERVER_IP -P -i -t -e REPLICAS="${REPLICAS_MEMBERS_STRING}" -e OPTIONS=" ${HOSTMAP["${PRX}${i}_srv1"]}:27017/local /root/jsfiles/setupReplicaSet.js" htaox/mongodb-worker:latest
    sleep 15
  done

  for i in `seq 1 $WORK`; do
    echo "Setting Replicat Sets (reconfigure.js)"
    #yes, _srv1 is correct
    docker run --dns $NAMESERVER_IP -P -i -t -e PRIMARY_SERVER=${HOSTMAP["${PRX}${i}_srv1"]} -e OPTIONS=" ${HOSTMAP["${PRX}${i}_srv1"]}:27017/local /root/jsfiles/reconfigure.js" htaox/mongodb-worker:latest
    sleep 5
  done
}

# use 3701X and 3801X for ports
# should be lightweight, no need for replsets
# mongos --configdb cfg1/172.17.1.95:27017,172.17.1.96:27017,172.17.1.97:27017 --port 27017
function createQueryRouterContainers() {
  # Setup and configure mongo router
  # mongos --configdb configReplSet/<cfgsvr1:port1>,<cfgsvr2:port2>,<cfgsvr3:port3>
  # we're only using 1 config replica set, so hardcode cfg1
  CONFIG_DBS="cfg1/"
  for i in `seq 1 3`; do
    #use the IP, not the HOSTNAME
    CONFIG_DBS="${CONFIG_DBS}${HOSTMAP[cfg1_srv${i}]}:27017"
    if [ $i -lt 3 ]; then
      CONFIG_DBS="${CONFIG_DBS},"
    fi
  done

  echo "CONFIG DBS => ${CONFIG_DBS}"

  ROUTER_VOLUME_DIR="${VOLUME_MAP_ARR[0]}-mongos"
  for j in `seq 1 $NUM_QUERY_ROUTERS`; do
    # Actually running mongos --configdb ...
    HOSTNAME=mongos${j}
    WORKER=$(docker run --dns $NAMESERVER_IP --name ${HOSTNAME} -P -i -d -p 3701${j}:27017 -p 3801${j}:27018 -e OPTIONS="s --configdb ${CONFIG_DBS} --port 27017" htaox/mongodb-worker:latest)
    sleep 5 # Wait for mongo to start
    WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
    echo "$HOSTNAME IP: $WORKER_IP"
    HOSTMAP[$HOSTNAME]=$WORKER_IP
    ROUTERS[j]=$WORKER_IP
  done
}

function setupShards() {
  #for i in `seq 1 $NUM_QUERY_ROUTERS`; do

  # *_srv1* is correct
  for j in `seq 1 $NUM_WORKERS`; do      
    SHARD_MEMBERS[j]="rs${j}/${HOSTMAP["rs${j}_srv1"]}"
  done

  #Convert array to string; replace space with "@"
  SHARD_MEMBERS="${SHARD_MEMBERS[@]}"
  #SHARD_MEMBERS=${SHARD_MEMBERS//@/ }

  #Only need to log into one query router
  QUERY_ROUTER_IP=${HOSTMAP["mongos1"]}
  echo "Initiating Shards ${SHARD_MEMBERS[@]} for Router ${QUERY_ROUTER_IP}"
  docker run --dns $NAMESERVER_IP -P -i -t -e SHARDS="${SHARD_MEMBERS}" -e OPTIONS=" ${QUERY_ROUTER_IP}:27017 /root/jsfiles/addShard.js" htaox/mongodb-worker:latest
  sleep 15 # Wait for sharding to be enabled

  #done
}

function updateDNSFile() {
  
  #Shard containers
  if [ $1 == "shard" ] ; then 
    for i in `seq 1 $NUM_WORKERS`; do
      for j in `seq 1 $NUM_REPLSETS`; do
        HOSTNAME=rs${i}_srv${j}
        echo "Removing $HOSTNAME from $DNSFILE"
        sed -i "/$HOSTNAME/d" "$DNSFILE"

        WORKER_IP=${HOSTMAP["rs${i}_srv${j}"]}
        echo "Updating $HOSTNAME in $DNSFILE to $WORKER_IP"
        echo "address=\"/$HOSTNAME/$WORKER_IP\"" >> $DNSFILE
      done
    done
  fi

  #Config containers
  if [ $1 == "config" ] ; then
    for i in `seq 1 1`; do
      for j in `seq 1 3`; do
        HOSTNAME=cfg${i}_srv${j}
        echo "Removing $HOSTNAME from $DNSFILE"
        sed -i "/$HOSTNAME/d" "$DNSFILE"

        WORKER_IP=${HOSTMAP["cfg${i}_srv${j}"]}
        echo "Updating $HOSTNAME in $DNSFILE to $WORKER_IP"
        echo "address=\"/$HOSTNAME/$WORKER_IP\"" >> $DNSFILE
      done
    done
  fi

  #Query containers
  if [ $1 == "query" ] ; then
    for j in `seq 1 $NUM_QUERY_ROUTERS`; do
      HOSTNAME=mongos${j}
      echo "Removing $HOSTNAME from $DNSFILE"
      sed -i "/$HOSTNAME/d" "$DNSFILE"

      WORKER_IP=${HOSTMAP["mongos${i}"]}
      echo "Updating $HOSTNAME in $DNSFILE to $WORKER_IP"
      echo "address=\"/$HOSTNAME/$WORKER_IP\"" >> $DNSFILE
    done
  fi
}

function enableShardTest() {

    #Just pick the first router
    #Note: used seq 1, so mongos1
    QUERY_ROUTER_IP=${HOSTMAP["mongos1"]}

    echo "Test insert"
    docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" ${QUERY_ROUTER_IP}:27017/test_db /root/jsfiles/addDBs.js" htaox/mongodb-worker:latest
    sleep 5 # Wait for db to be created
    
    echo "Enable shard"
    docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" ${QUERY_ROUTER_IP}:27017/admin /root/jsfiles/enableSharding.js" htaox/mongodb-worker:latest
    sleep 5 # Wait sharding to be enabled
    
    echo "Test indexes"
    docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" ${QUERY_ROUTER_IP}:27017/test_db /root/jsfiles/addIndexes.js" htaox/mongodb-worker:latest

}

function start_workers() {
  
  echo "-------------------------------------"
  echo "Settings"
  echo "-------------------------------------"
  echo "NUM_WORKERS: ${NUM_WORKERS}"
  echo "NUM_REPLSETS: ${NUM_REPLSETS}"
  echo "NUM_QUERY_ROUTERS: ${NUM_QUERY_ROUTERS}"

  echo "-------------------------------------"
  echo "Creating Shard Containers"
  echo "-------------------------------------"
  createShardContainers  
  
  echo "-------------------------------------"
  echo "Creating Config Containers"
  echo "-------------------------------------"
  createConfigContainers

  echo "-------------------------------------"
  echo "Updating DNS file (shards and config)"
  echo "-------------------------------------"
  updateDNSFile shard
  updateDNSFile config

  echo "-------------------------------------"
  echo "Setting Up Replica Sets for Shards"
  echo "-------------------------------------"
  setupReplicaSets
  
  echo "-------------------------------------"
  echo "Setting Up Replica Sets for Config"
  echo "-------------------------------------"
  setupReplicaSets 1 3 cfg
  
  echo "-------------------------------------"
  echo "Configuring Query Router Containers"
  echo "-------------------------------------"
  createQueryRouterContainers

  echo "-------------------------------------"
  echo "Updating DNS file (query)"
  echo "-------------------------------------"
  updateDNSFile query

  echo "-------------------------------------"
  echo "Setting Up Shards"
  echo "-------------------------------------"
  setupShards

  echo "-------------------------------------"
  echo "Enable Shard Test"
  echo "-------------------------------------"
  enableShardTest
  
  echo "#####################################"
  echo "MongoDB Cluster is now ready to use"
  echo "Connect to cluster by: ${ROUTERS[@]}"
}
