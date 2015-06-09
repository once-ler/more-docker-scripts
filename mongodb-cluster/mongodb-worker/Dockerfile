# Pull base image.
FROM htaox/mongodb-base:latest
MAINTAINER Henry Tao htaox@hotmail.com

ADD files /root/mongodb_worker_files
RUN chmod 700 /root/mongodb_worker_files/run_mongodb_worker.sh
CMD ["/root/mongodb_worker_files/run_mongodb_worker.sh"]
