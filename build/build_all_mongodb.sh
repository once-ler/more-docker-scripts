#!/bin/bash

CURDIR=$(pwd)
BASEDIR=$(cd $(dirname $0); pwd)"/.."
dir_list=( "mongodb-cluster" )

export IMAGE_PREFIX="htaox/"

# NOTE: the order matters but this is the right one
for i in ${dir_list[@]}; do
	echo building $i;
	cd ${BASEDIR}/$i
        cat build
        ./build
done
cd $CURDIR
