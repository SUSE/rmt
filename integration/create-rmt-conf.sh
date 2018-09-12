#!/bin/sh -xe
mkdir /etc/rmt
printf "database:\n\
  host: $MYSQL_HOST\n\
  username: $MYSQL_USER\n\
  password: $MYSQL_PASSWORD\n\
  database: $MYSQL_DATABASE\n\
scc:\n\
  username: $SCC_USERNAME\n\
  password: $SCC_PASSWORD\n\
" >> /etc/rmt.conf
