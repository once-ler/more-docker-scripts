#!/bin/bash

# Docker interface ip
#DOCKERIP="10.1.42.1"

BASEDIR=$(cd $(dirname $0); pwd)
#NUM_REPLSETS

declare -A HOSTMAP

function setupReplicaSets() {

  for i in `seq 1 $NUM_WORKERS`; do

    echo "Initiating Replicat Sets"
    #yes, _srv1 is correct
    docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" ${HOSTMAP["rs${i}_srv1"]}:27017/local /root/jsfiles/initiate.js" htaox/mongodb-worker:3.0.2
    sleep 5

    #form array, start with *_srv2* and up
    for j in `seq 2 $NUM_REPLSETS`; do
      REPLICA_MEMBERS[j]=${HOSTMAP["rs${i}_srv${j}"]}
    done

    echo "Setting Replicat Sets"
    #yes, _srv1 is correct
    docker run --dns $NAMESERVER_IP -P -i -t -e REPLICA_MEMBERS="${REPLICA_MEMBERS[@]}" -e OPTIONS=" ${HOSTMAP["rs${i}_srv1"]}:27017/local /root/jsfiles/setupReplicaSet.js" htaox/mongodb-worker:3.0.2
    sleep 10

  done
}

function createConfigContainers() {
  #should have exactly *3* for production
  for i in `seq 1 3`; do
    CONFIG_VOLUME_DIR="${VOLUME_MAP_ARR[0]}-${i}"
    mkdir -p "${CONFIG_VOLUME_DIR}-cfg"
    
    HOSTNAME=mgs_cfg${i}
    WORKER=$(docker run --dns $NAMESERVER_IP --name $HOSTNAME -P -i -d -v ${CONFIG_VOLUME_DIR}-cfg:/data/db -e OPTIONS="d --configsvr --dbpath /data/db --notablescan --noprealloc --smallfiles --port 27017" htaox/mongodb-worker:3.0.2)
    sleep 3
    #echo "Removing $HOSTNAME from $DNSFILE"
    #sed -i "/$HOSTNAME/d" "$DNSFILE"
    WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
    #echo "address=\"/$HOSTNAME/$WORKER_IP\"" >> $DNSFILE
    echo "$HOSTNAME IP: $WORKER_IP"
    HOSTMAP[$HOSTNAME]=$WORKER_IP
  done
}

function createShardContainers() {

  # split the volume syntax by :, then use the array to build new volume map
  IFS=' ' read -ra VOLUME_MAP_ARR_PRE <<< "$VOLUME_MAP"
  IFS=':' read -ra VOLUME_MAP_ARR <<< "${VOLUME_MAP_ARR_PRE[1]}"

  for i in `seq 1 $NUM_WORKERS`; do

    echo "starting worker container"
    #HOSTNAME="${WORKER_HOSTNAME}${i}${DOMAINNAME}"
    # rename $VOLUME_MAP by adding worker number as suffix if it is not empty
    WORKER_VOLUME_MAP=$VOLUME_MAP
    if [ "$VOLUME_MAP" ]; then
      WORKER_VOLUME_DIR="${VOLUME_MAP_ARR[0]}-${i}"      
      for j in `seq 1 $NUM_REPLSETS`; do
        echo "Creating directory ${WORKER_VOLUME_DIR}-${j}"
        mkdir -p "${WORKER_VOLUME_DIR}-${j}"    
      done      
    fi
    
    # Create mongd servers
    for j in `seq 1 $NUM_REPLSETS`; do
      HOSTNAME=rs${i}_srv${j}
      WORKER=$(docker run --dns $NAMESERVER_IP --name ${HOSTNAME} -P -i -d -v ${WORKER_VOLUME_DIR}-${j}:/data/db -e OPTIONS="d --storageEngine wiredTiger --replSet rs${i} --dbpath /data/db --notablescan --noprealloc --smallfiles" htaox/mongodb-worker:3.0.2)
      sleep 3
      #echo "Removing $HOSTNAME from $DNSFILE"
      #sed -i "/$HOSTNAME/d" "$DNSFILE"
      WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
      #echo "address=\"/$HOSTNAME/$WORKER_IP\"" >> $DNSFILE
      echo "$HOSTNAME IP: $WORKER_IP"
      HOSTMAP[$HOSTNAME]=$WORKER_IP
    done
   
  done
}

function setupShards() {

  for i in `seq 1 $NUM_QUERY_ROUTERS`; do

    # *_srv1* is correct
    for j in `seq 1 $NUM_WORKERS`; do      
      REPLICA_SETS[j]="rs${j}"
      SHARD_MEMBERS[j]=${HOSTMAP["rs${j}_srv1"]}
    done

    QUERY_ROUTER_IP=${HOSTMAP["mongos${i}"]}
    echo "Initiating Shards ${SHARD_MEMBERS[@]} for Router ${QUERY_ROUTER_IP}"
    WORKER=$(docker run --dns $NAMESERVER_IP -P -i -t -e REPLICA_SETS="${REPLICA_SETS[@]}" -e SHARD_MEMBERS="${SHARD_MEMBERS[@]}" -e OPTIONS=" ${QUERY_ROUTER_IP}:27017/local /root/jsfiles/addShard.js" htaox/mongodb-worker:3.0.2)
    sleep 5 # Wait for sharding to be enabled
  
    #echo "Test insert"
    #docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" mongos1:27017 /root/jsfiles/addDBs.js" htaox/mongodb-worker:3.0.2
    #sleep 5 # Wait for db to be created
    
    #echo "Enable shard"
    #docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" mongos1:27017/admin /root/jsfiles/enableSharding.js" htaox/mongodb-worker:3.0.2
    #sleep 5 # Wait sharding to be enabled
    
    #echo "Test indexes"
    #docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" mongos1:27017 /root/jsfiles/addIndexes.js" htaox/mongodb-worker:3.0.2

  done
}

function createQueryRouterContainers() {
  # Setup and configure mongo router
  CONFIG_DBS=""
  for i in `seq 1 3`; do
    #use the IP, not the HOSTNAME
    CONFIG_DBS="${CONFIG_DBS}${HOSTMAP[mgs_cfg${i}]}:27017"
    if [ $i -lt 3 ]; then
      CONFIG_DBS="${CONFIG_DBS},"
    fi
  done

  echo "CONFIG DBS => ${CONFIG_DBS}"

  for j in `seq 1 $NUM_QUERY_ROUTERS`; do
    # Actually running mongos --configdb ...
    HOSTNAME=mongos${j}
    WORKER=$(docker run --dns $NAMESERVER_IP --name ${HOSTNAME} -P -i -d -e OPTIONS="s --configdb ${CONFIG_DBS} --port 27017" htaox/mongodb-worker:3.0.2)
    sleep 5 # Wait for mongo to start
    #echo "Removing $HOSTNAME from $DNSFILE"
    #sed -i "/$HOSTNAME/d" "$DNSFILE"
    WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
    #echo "address=\"/$HOSTNAME/$WORKER_IP\"" >> $DNSFILE
    echo "$HOSTNAME IP: $WORKER_IP"
    HOSTMAP[$HOSTNAME]=$WORKER_IP

  done
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
  echo "Setting Up Replica Sets"
  echo "-------------------------------------"
  setupReplicaSets
  
  echo "-------------------------------------"
  echo "Configuring Query Router Containers"
  echo "-------------------------------------"
  createQueryRouterContainers

  echo "-------------------------------------"
  echo "Setting Up Shards"
  echo "-------------------------------------"
  setupShards

  echo "#####################################"
  echo "MongoDB Cluster is now ready to use"
  echo "Connect to cluster by:"
  #echo "$ mongo --port $(docker port mongos1 27017|cut -d ":" -f2)"
}

