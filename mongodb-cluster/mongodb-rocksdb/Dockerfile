# Pull base image.
FROM ubuntu:trusty
MAINTAINER  Henry Tao "htaox@hotmail.com"

# Install build tool
RUN apt-get install scons

# Install compression libs
RUN apt-get install libbz2-dev libsnappy-dev zlib1g-dev libzlcore-dev

# Install rocksdb
RUN \
  git clone https://github.com/facebook/rocksdb.git && \
  cd rocksdb && \
  git checkout mongorocks && \
  make static_lib && \
  make install

RUN cd ~

# Install mongodb from the v3.0-mongorocks branch
RUN \
  git clone https://github.com/mongodb-partners/mongo.git && \
  cd mongo && \
  git checkout v3.0-mongorocks && \
  scons mongod mongo mongos --rocksdb=1

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


