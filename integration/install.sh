#!/bin/sh -xe
SUSEConnect -r $REGCODE
zypper --non-interactive ar http://download.opensuse.org/repositories/openSUSE:/Tools/SLE_15/openSUSE:Tools.repo
zypper --non-interactive --gpg-auto-import-keys ref
zypper --non-interactive up
zypper --non-interactive in -t pattern devel_osc_build
zypper --non-interactive install --no-recommend wget curl timezone \
  gcc-c++ libffi-devel git-core zlib-devel libxml2-devel libxslt-devel libmariadb-devel \
  mariadb-client mariadb ruby2.5-rubygem-bundler make build sudo ruby-devel nginx
SUSEConnect -d
