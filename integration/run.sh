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
cd ~/obs/systemsmanagement:SCC:RMT/rmt-server && osc addremove && osc build SLE_15 x86_64 --no-verify --trust-all-projects --clean && cd .. &&
find /oscbuild/SLE_15-x86_64/home/abuild/rpmbuild/RPMS/x86_64/ -name '*.rpm' -not -name '*pubcloud*' -exec zypper --non-interactive --no-gpg-checks in --no-recommends {} \+
cd /usr/share/rmt
RAILS_ENV=production DISABLE_DATABASE_ENVIRONMENT_CHECK=1 /usr/share/rmt/bin/rails db:drop db:create db:migrate
/usr/bin/rmt-cli sync
cd /tmp/rmt-server/
NO_COVERAGE=true rspec features/
