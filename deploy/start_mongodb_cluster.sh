#!/bin/bash

# Docker interface ip
#DOCKERIP="10.1.42.1"

#LOCALPATH="/home/vagrant/docker"

BASEDIR=$(cd $(dirname $0); pwd)
WORKER_HOSTNAME=mongodb-node

# Clean up
#containers=( skydns skydock mongos1r1 mongos1r2 mongos2r1 mongos2r2 mongos3r1 mongos3r2 configservers1 configservers2 configservers3 mongos1 )
#for c in ${containers[@]}; do
#  docker kill ${c}  > /dev/null 2>&1
#  docker rm ${c}    > /dev/null 2>&1
#done

# Uncomment to build mongo image yourself otherwise it will download from docker index.
#docker build -t htaox/mongodb-worker:3.0.2 ${LOCALPATH}/mongo > /dev/null 2>&1

# Setup skydns/skydock
# docker run -d -p $NAMESERVER_IP:53:53/udp --name skydns crosbymichael/skydns -nameserver 8.8.8.8:53 -domain docker
# docker run -d -v /var/run/docker.sock:/docker.sock --name skydock crosbymichael/skydock -ttl 30 -environment dev -s /docker.sock -domain docker -name skydns

function start_workers() {
  
  # split the volume syntax by :, then use the array to build new volume map
  IFS=' ' read -ra VOLUME_MAP_ARR_PRE <<< "$VOLUME_MAP"
  IFS=':' read -ra VOLUME_MAP_ARR <<< "${VOLUME_MAP_ARR_PRE[1]}"

  for i in `seq 1 $NUM_WORKERS`; do

    echo "starting worker container"
    #hostname="${WORKER_HOSTNAME}${i}${DOMAINNAME}"
    # rename $VOLUME_MAP by adding worker number as suffix if it is not empty
    WORKER_VOLUME_MAP=$VOLUME_MAP
    if [ "$VOLUME_MAP" ]; then
      WORKER_VOLUME_DIR="${VOLUME_MAP_ARR[0]}-${i}"
      echo "Creating directory ${WORKER_VOLUME_DIR}"
      #mkdir -p "${WORKER_VOLUME_DIR}"
      mkdir -p "${WORKER_VOLUME_DIR}-1"
      mkdir -p "${WORKER_VOLUME_DIR}-2"
      mkdir -p "${WORKER_VOLUME_DIR}-cfg"
      
      # volume will now be like /host/dir/data-1:/data if original volume was /home/dir/data
      # WORKER_VOLUME_MAP="-v ${WORKER_VOLUME_DIR}:${VOLUME_MAP_ARR[1]}"            
    fi
    #echo "WORKER ${i} VOLUME_MAP => ${WORKER_VOLUME_MAP}"

    # Create mongd servers
    WORKER=$(docker run --dns $NAMESERVER_IP --name mongos${i}r1 -P -i -d -v ${WORKER_VOLUME_DIR}-1:/data/db -e OPTIONS="d --replSet set${i} --dbpath /data/db --notablescan --noprealloc --smallfiles" htaox/mongodb-worker:3.0.2)
    sleep 3
    hostname=mongos${i}r1
    echo "Removing $hostname from $DNSFILE"
    sed -i "/$hostname/d" "$DNSFILE"
    WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
    echo "address=\"/$hostname/$WORKER_IP\"" >> $DNSFILE
    echo "$hostname IP: $WORKER_IP"

    WORKER=$(docker run --dns $NAMESERVER_IP --name mongos${i}r2 -P -i -d -v ${WORKER_VOLUME_DIR}-2:/data/db -e OPTIONS="d --replSet set${i} --dbpath /data/db --notablescan --noprealloc --smallfiles" htaox/mongodb-worker:3.0.2)
    sleep 3
    hostname=mongos${i}r2
    echo "Removing $hostname from $DNSFILE"
    sed -i "/$hostname/d" "$DNSFILE"
    WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
    echo "address=\"/$hostname/$WORKER_IP\"" >> $DNSFILE
    echo "$hostname IP: $WORKER_IP"

    # sleep 10 # Wait for mongo to start
    # Setup replica set
    #docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" $NAMESERVER_IP:$(docker port mongos${i}r1 27017|cut -d ":" -f2) /root/jsfiles/initiate.js" htaox/mongodb-worker:3.0.2
    docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" mongos${i}r1:27017 /root/jsfiles/initiate.js" htaox/mongodb-worker:3.0.2
    sleep 5 # Waiting for set to be initiated

    #update setupReplicaSet.js
    #docker run --dns $NAMESERVER_IP -P -i -t -e WORKERNUM=${i} -e OPTIONS=" $NAMESERVER_IP:$(docker port mongos${i}r1 27017|cut -d ":" -f2) /root/jsfiles/setupReplicaSet.js" htaox/mongodb-worker:3.0.2
    docker run --dns $NAMESERVER_IP -P -i -t -e WORKERNUM=${i} -e OPTIONS=" mongos${i}r1:27017 /root/jsfiles/setupReplicaSet.js" htaox/mongodb-worker:3.0.2

    # Create configserver
    WORKER=$(docker run --dns $NAMESERVER_IP --name mongos-configservers${i} -P -i -d -v ${WORKER_VOLUME_DIR}-cfg:/data/db -e OPTIONS="d --configsvr --dbpath /data/db --notablescan --noprealloc --smallfiles --port 27017" htaox/mongodb-worker:3.0.2)
    sleep 3
    hostname=mongos-configservers${i}
    echo "Removing $hostname from $DNSFILE"
    sed -i "/$hostname/d" "$DNSFILE"
    WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
    echo "address=\"/$hostname/$WORKER_IP\"" >> $DNSFILE
    echo "$hostname IP: $WORKER_IP"
   
  done

  # Setup and configure mongo router
  CONFIG_DBS=""
  for i in `seq 1 $NUM_WORKERS`; do
    CONFIG_DBS="${CONFIG_DBS}mongos-configservers${i}.mongo.dev.docker:27017"
    if [ $i -lt $(($NUM_WORKERS-1)) ]; then
      CONFIG_DBS="${CONFIG_DBS},"
    fi
  done

  echo "Config dbs --> ${CONFIG_DBS}"

  WORKER=$(docker run --dns $NAMESERVER_IP --name mongos1 -P -i -d -e OPTIONS="s --configdb ${CONFIG_DBS} --port 27017" htaox/mongodb-worker:3.0.2)
  sleep 5 # Wait for mongo to start
  hostname=mongos1
  echo "Removing $hostname from $DNSFILE"
  sed -i "/$hostname/d" "$DNSFILE"
  WORKER_IP=$(docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
  echo "address=\"/$hostname/$WORKER_IP\"" >> $DNSFILE
  echo "$hostname IP: $WORKER_IP"

  #docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" $NAMESERVER_IP:$(docker port mongos1 27017|cut -d ":" -f2) /root/jsfiles/addShard.js" htaox/mongodb-worker:3.0.2
  docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" mongos1:27017 /root/jsfiles/addShard.js" htaox/mongodb-worker:3.0.2
  sleep 5 # Wait for sharding to be enabled
  #docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" $NAMESERVER_IP:$(docker port mongos1 27017|cut -d ":" -f2) /root/jsfiles/addDBs.js" htaox/mongodb-worker:3.0.2
  docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" mongos1:27017 /root/jsfiles/addDBs.js" htaox/mongodb-worker:3.0.2
  sleep 5 # Wait for db to be created
  #docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" $NAMESERVER_IP:$(docker port mongos1 27017|cut -d ":" -f2)/admin /root/jsfiles/enabelSharding.js" htaox/mongodb-worker:3.0.2
  docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" mongos1:27017/admin /root/jsfiles/enabelSharding.js" htaox/mongodb-worker:3.0.2
  sleep 5 # Wait sharding to be enabled
  #docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" $NAMESERVER_IP:$(docker port mongos1 27017|cut -d ":" -f2) /root/jsfiles/addIndexes.js" htaox/mongodb-worker:3.0.2
  docker run --dns $NAMESERVER_IP -P -i -t -e OPTIONS=" mongos1:27017 /root/jsfiles/addIndexes.js" htaox/mongodb-worker:3.0.2

  echo "#####################################"
  echo "MongoDB Cluster is now ready to use"
  echo "Connect to cluster by:"
  echo "$ mongo --port $(docker port mongos1 27017|cut -d ":" -f2)"
}

