#!/bin/sh -xe
make dist
mkdir ~/obs
cd ~/obs
osc co systemsmanagement:SCC:RMT rmt-server
cd /tmp/rmt-server/package
cp obs/* ~/obs/systemsmanagement:SCC:RMT/rmt-server
cd ~/obs/systemsmanagement:SCC:RMT/rmt-server && osc build SLE_15 x86_64 --no-verify --trust-all-projects && cd .. &&
zypper --non-interactive --no-gpg-checks in --no-recommends /oscbuild/SLE_15-x86_64/home/abuild/rpmbuild/RPMS/x86_64/*
cd /usr/share/rmt
RAILS_ENV=production /usr/share/rmt/bin/rails db:create db:migrate
/usr/bin/rmt-cli sync
cd /tmp/rmt-server/
NO_COVERAGE=true rspec features/
