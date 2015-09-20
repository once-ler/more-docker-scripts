#
# ElasticSearch Dockerfile
#
# https://github.com/dockerfile/elasticsearch
#
 
# Pull base image.
#FROM htaox/oracle-java8:latest
FROM java:8u45-jdk

RUN apt-get update
# just run as root
# RUN apt-get install sudo
 
# Install ElasticSearch.
RUN cd /tmp && wget https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.7.2.tar.gz
RUN cd /tmp && tar xvzf elasticsearch-1.5.2.tar.gz && rm -f elasticsearch-1.7.2.tar.gz
RUN mv /tmp/elasticsearch-1.7.2 /elasticsearch
ENV ES_HOME /elasticsearch

# Install elasticsearch-head
RUN /elasticsearch/bin/plugin -install mobz/elasticsearch-head

# Install elasticsearch-mapper-attachment
RUN /elasticsearch/bin/plugin -install elasticsearch/elasticsearch-mapper-attachments/2.7.0 

# Create elasticsearch user
# ENV ES_USER elasticsearch
# ENV ES_GROUP elasticsearch

# RUN addgroup elasticsearch
# RUN useradd elasticsearch -g elasticsearch
## RUN adduser --ingroup elasticsearch elasticsearch

# Define mountable directories.
VOLUME ["/data"]

# Define working directory.
WORKDIR /data

# Define default command.
# ENTRYPOINT ["/elasticsearch/bin/elasticsearch"]

# Expose ports.
#   - 9200: HTTP
#   - 9300: transport
EXPOSE 9200
EXPOSE 9300

ADD files /root/elasticsearch_files
ADD files/elasticsearch.yml $ES_HOME/config/elasticsearch.yml

RUN chown -R elasticsearch.elasticsearch $ES_HOME

# Add mungehosts (Need to add hostname to 127.0.0.1 in /etc/hosts)
# http://jasani.org/2014/11/19/docker-now-supports-adding-host-mappings/
# https://github.com/hiteshjasani/nim-mungehosts
# ADD https://github.com/hiteshjasani/nim-mungehosts/releases/download/v0.1.1/mungehosts /usr/local/bin/mungehosts
# RUN chmod 755 /usr/local/bin/mungehosts