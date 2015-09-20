#!/bin/bash

env

echo 'Starting Elasticsearch Worker'

IP=$(ip -o -4 addr list eth0 | perl -n -e 'if (m{inet\s([\d\.]+)\/\d+\s}xms) { print $1 }')
echo "WORKER_IP=$IP"

sed -i "s/@IP@/$IP/g" $ES_HOME/config/elasticsearch.yml
#sed -i "s|^network.host:.*|network.host: $IP|" $ES_HOME/config/elasticsearch.yml

sed -i "s/@MASTER@/false/g" $ES_HOME/config/elasticsearch.yml
sed -i "s/@DATA@/true/g" $ES_HOME/config/elasticsearch.yml

#elasticsearch requires hostname loopback
#sudo mungehosts -l $HOSTNAME
#cat /etc/hosts

ES_HEAP_SIZE=2g

#run as root
$ES_HOME/bin/elasticsearch -f -Des.config=$ES_HOME/config/elasticsearch.yml -Xms$ES_HEAP_SIZE -Xmx$ES_HEAP_SIZE
