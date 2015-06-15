#!/bin/bash

MASTER=-1
MASTER_IP=
NUM_REGISTERED_WORKERS=0
BASEDIR=$(cd $(dirname $0); pwd)
ELASTICSERVERS="${BASEDIR}/elasticservers"
MASTER_HOSTNAME=elasticsearch-master
WORKER_HOSTNAME=elasticsearch-worker

# starts the elasticsearch master container
function start_master() {
    echo "starting master container"

    # split the volume syntax by :, then use the array to build new volume map
    IFS=' ' read -ra VOLUME_MAP_ARR_PRE <<< "$VOLUME_MAP"
    IFS=':' read -ra VOLUME_MAP_ARR <<< "${VOLUME_MAP_ARR_PRE[1]}"
    MASTER_VOLUME_DIR="${VOLUME_MAP_ARR[0]}"
    echo "Creating directory ${MASTER_VOLUME_DIR}"
    mkdir -p "${MASTER_VOLUME_DIR}"    

    if [ "$DEBUG" -gt 0 ]; then
        echo sudo docker run -d --restart no --dns $NAMESERVER_IP -h ${MASTER_HOSTNAME}${DOMAINNAME} $VOLUME_MAP $1:$2
    fi
    MASTER=$(sudo docker run -d --restart no --dns $NAMESERVER_IP -h ${MASTER_HOSTNAME}${DOMAINNAME} $VOLUME_MAP $1:$2)

    if [ "$MASTER" = "" ]; then
        echo "error: could not start master container from image $1:$2"
        exit 1
    fi

    echo "started master container:      $MASTER"
    sleep 3
    echo "Removing $MASTER_HOSTNAME from $DNSFILE"
    sed -i "/$MASTER_HOSTNAME/d" "$DNSFILE"

    MASTER_IP=$(sudo docker logs $MASTER 2>&1 | egrep '^MASTER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
    echo "MASTER_IP:                     $MASTER_IP"
    echo "address=\"/$MASTER_HOSTNAME/$MASTER_IP\"" >> $DNSFILE
}

# starts a number of elasticsearch workers
function start_workers() {
	
	rm -f $ELASTICSERVERS

    # split the volume syntax by :, then use the array to build new volume map
    IFS=' ' read -ra VOLUME_MAP_ARR_PRE <<< "$VOLUME_MAP"
    IFS=':' read -ra VOLUME_MAP_ARR <<< "${VOLUME_MAP_ARR_PRE[1]}"

    for i in `seq 1 $NUM_WORKERS`; do
        echo "starting worker container"
	hostname="${WORKER_HOSTNAME}${i}${DOMAINNAME}"
        # rename $VOLUME_MAP by adding worker number as suffix if it is not empty
        WORKER_VOLUME_MAP=$VOLUME_MAP
        if [ "$VOLUME_MAP" ]; then
            WORKER_VOLUME_DIR="${VOLUME_MAP_ARR[0]}-${i}"
            echo "Creating directory ${WORKER_VOLUME_DIR}"
            mkdir -p "${WORKER_VOLUME_DIR}"
            # volume will now be like /host/dir/data-1:/data if original volume was /home/dir/data
            WORKER_VOLUME_MAP="-v ${WORKER_VOLUME_DIR}:${VOLUME_MAP_ARR[1]}"            
        fi
        echo "WORKER ${i} VOLUME_MAP => ${WORKER_VOLUME_MAP}"

        if [ "$DEBUG" -gt 0 ]; then
	    echo sudo docker run -d --restart no --dns $NAMESERVER_IP -h $hostname $WORKER_VOLUME_MAP $1:$2
        fi
	WORKER=$(sudo docker run -d --restart no --dns $NAMESERVER_IP -h $hostname $WORKER_VOLUME_MAP $1:$2)

        if [ "$WORKER" = "" ]; then
            echo "error: could not start worker container from image $1:$2"
            exit 1
        fi

	echo "started worker container:  $WORKER"
	sleep 3
	echo "Removing $hostname from $DNSFILE"
    sed -i "/$hostname/d" "$DNSFILE"

    WORKER_IP=$(sudo docker logs $WORKER 2>&1 | egrep '^WORKER_IP=' | awk -F= '{print $2}' | tr -d -c "[:digit:] .")
	echo "address=\"/$hostname/$WORKER_IP\"" >> $DNSFILE
    echo "WORKER #${i} IP: $WORKER_IP" 
    echo $WORKER_IP >> $ELASTICSERVERS
    echo "WORKER #${i} CLUSTER HEALTH: http://${WORKER_IP}:9200/_plugin/head/"
    done
}

# prints out information on the cluster
function print_cluster_info() {
    BASEDIR=$(cd $(dirname $0); pwd)"/.."
    echo ""
    echo "***********************************************************************"
    echo ""
    echo "/data mapped:               $VOLUME_MAP"
    echo ""
    echo "MASTER_IP: ${MASTER_IP}"
    echo ""
    echo "WORKERS:"
    cat -n $ELASTICSERVERS
    echo "***********************************************************************"
    echo ""
    echo "to enable cluster name resolution add the following line to _the top_ of your host's /etc/resolv.conf:"
    echo "nameserver $NAMESERVER_IP"
}

: <<'END'
function get_num_registered_workers() {
    sleep 2
    NUM_REGISTERED_WORKERS=$(($NUM_REGISTERED_WORKERS+1))    
}
END

function wait_for_master {
    echo -n "waiting for master "
    sleep 1
    echo ""
    echo -n "waiting for nameserver to find master "
    check_hostname result "$MASTER_HOSTNAME" "$MASTER_IP"
    until [ "$result" -eq 0 ]; do
        echo -n "."
        sleep 1
        check_hostname result "$MASTER_HOSTNAME" "$MASTER_IP"
    done
    echo ""
    sleep 2
}


