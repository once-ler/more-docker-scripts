#FROM mongo:3.0.2

# Pull base image.
FROM ubuntu:trusty
MAINTAINER  Henry Tao "htaox@hotmail.com"

# Install MongoDB.
RUN \
  sed -i "/^# deb.*multiverse/ s/^# //" /etc/apt/sources.list && apt-get update && \
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
  echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.0.list && \
  apt-get update && \
  apt-get install -y mongodb-org && \
  rm -rf /var/lib/apt/lists/*

# Define mountable directories.
VOLUME ["/data/db"]

# Define working directory.
WORKDIR /data

# Expose ports.
#   - 27017: process
#   - 28017: http
EXPOSE 27017
EXPOSE 28017

ADD files /root/jsfiles

# Define default command.
CMD ["/bin/bash"]

