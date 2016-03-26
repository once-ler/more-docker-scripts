#
# ElasticSearch Dockerfile
#
# https://github.com/dockerfile/elasticsearch
#
 
# Pull base image.
#FROM htaox/oracle-java8:latest
FROM java:8u72-jdk

RUN apt-get update
# just run as root
# RUN apt-get install sudo
 
# Install ElasticSearch.
RUN cd /tmp && wget https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.7.5.tar.gz
RUN cd /tmp && tar xvzf elasticsearch-1.7.5.tar.gz && rm -f elasticsearch-1.7.5.tar.gz
RUN mv /tmp/elasticsearch-1.7.5 /elasticsearch
ENV ES_HOME /elasticsearch

# Install elasticsearch-head
RUN /elasticsearch/bin/plugin -install mobz/elasticsearch-head/1.x

# Install elasticsearch-mapper-attachment
RUN /elasticsearch/bin/plugin -install elasticsearch/elasticsearch-mapper-attachments/2.7.1 

# Define mountable directories.
VOLUME ["/data"]

# Define default command.
# ENTRYPOINT ["/elasticsearch/bin/elasticsearch"]

ADD files /root/elasticsearch_files
ADD files/elasticsearch.yml $ES_HOME/config/elasticsearch.yml

# Define working directory.
WORKDIR /data

# Expose ports.
#   - 9200: HTTP
#   - 9300: transport
EXPOSE 9200
EXPOSE 9300

# Add mungehosts (Need to add hostname to 127.0.0.1 in /etc/hosts)
# http://jasani.org/2014/11/19/docker-now-supports-adding-host-mappings/
# https://github.com/hiteshjasani/nim-mungehosts
# ADD https://github.com/hiteshjasani/nim-mungehosts/releases/download/v0.1.1/mungehosts /usr/local/bin/mungehosts
# RUN chmod 755 /usr/local/bin/mungehosts