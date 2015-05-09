#!/bin/bash

DEBUG=0
BASEDIR=$(cd $(dirname $0); pwd)

mongodb_images=( "htaox/mongodb-base:3.0.2","htaox/mongodb-worker:3.0.2" )
NAMESERVER_IMAGE="amplab/dnsmasq-precise"

start_shell=0
VOLUME_MAP=""

image_type="?"
image_version="?"
NUM_WORKERS=2
NUM_REPLSETS=2
NUM_QUERY_ROUTERS=1

source $BASEDIR/start_nameserver.sh
source $BASEDIR/start_mongodb_cluster.sh

function check_root() {
    if [[ "$USER" != "root" ]]; then
        echo "please run as: sudo $0"
        exit 1
    fi
}

function print_help() {
    echo "usage: $0 -i <image> [-w <#workers>] [-v <data_directory>] [-c]"
    echo ""
    echo "  image:    mongodb image from:"
    echo -n "               "
    for i in ${mongodb_images[@]}; do
        echo -n "  $i"
    done
    echo ""    
}

function parse_options() {
    while getopts "i:w:cv:h:s:q:" opt; do
        case $opt in
        i)
            echo "$OPTARG" | grep "mongodb:" > /dev/null;
	    if [ "$?" -eq 0 ]; then
                image_type="mongodb"
            fi            
	    image_name=$(echo "$OPTARG" | awk -F ":" '{print $1}')
            image_version=$(echo "$OPTARG" | awk -F ":" '{print $2}') 
          ;;
        w)
            NUM_WORKERS=$OPTARG
          ;;
        h)
            print_help
            exit 0
          ;;
        c)
            start_shell=1
          ;;
        v)
            VOLUME_MAP=$OPTARG
          ;;
        s)
            NUM_REPLSETS=$OPTARG
          ;;
        q)
            NUM_QUERY_ROUTERS=$OPTARG
          ;;
        esac
    done

    if [ "$image_type" == "?" ]; then
        echo "missing or invalid option: -i <image>"
        exit 1
    fi

    if [ ! "$VOLUME_MAP" == "" ]; then
        echo "data volume chosen: $VOLUME_MAP"
        VOLUME_MAP="-v $VOLUME_MAP:/data"
    fi
}

function check_mongodb() {

    containers=($(sudo docker ps | grep mongodb-worker | awk '{print $1}' | tr '\n' ' '))
    NUM_MONGODB_WORKER=$(echo ${#containers[@]})    
    echo "There are $NUM_MONGODB_WORKER mongodb servers running"

}

function remove_stopped_containers() {
    sudo docker ps -a | grep mongodb | awk '{print $1}' | xargs --no-run-if-empty docker rm
}

parse_options $@

if [ "$image_type" == "mongodb" ]; then
    mongodb_VERSION="$image_version"
    echo "*** Starting mongodb $mongodb_VERSION ***"
else
    echo "not starting anything"
    exit 0
fi

check_start_nameserver $NAMESERVER_IMAGE

check_mongodb

if [ $NUM_MONGODB_WORKER -gt 0 ]; then
    exit 0
fi

remove_stopped_containers

start_workers ${image_name}-worker $image_version
sleep 3

echo ""