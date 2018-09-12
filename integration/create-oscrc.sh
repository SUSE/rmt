#!/bin/sh -xe
printf "[general]\n\
build-root = /oscbuild/%(repo)s-%(arch)s\n\
packagecachedir = /oscbuild/packagecache\n\
[https://api.suse.de]\n\
user=$OBS_USER\n\
pass=$OBS_PASSWORD\n\
sslcertck = 0\n\
trusted_prj=SLE_12 SUSE:SLE-12:GA\n\
[https://api.opensuse.org]\n\
user=$OBS_USER\n\
pass=$OBS_PASSWORD\n\
sslcertck = 0\n\
trusted_prj=SLE_12 SUSE:SLE-12:GA\n\
" >> ~/.oscrc
