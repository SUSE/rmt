#!/bin/sh -xe

# update project
rm -r /tmp/rmt-server/*
cp -r /tmp/workdir/* /tmp/rmt-server
chown -R scc /tmp/rmt-server

make dist
mkdir ~/obs
cd ~/obs
osc co systemsmanagement:SCC:RMT rmt-server
cd /tmp/rmt-server/package
cp obs/* ~/obs/systemsmanagement:SCC:RMT/rmt-server
cd ~/obs/systemsmanagement:SCC:RMT/rmt-server && osc addremove && osc build SLE_15 x86_64 --no-verify --trust-all-projects --clean
MESSAGE=$(awk '{}' rmt-server.changes) # TODO: parse changelog with awk to extract changes to insert into message
osc ci -m $MESSAGE
