#!/bin/sh -xe
SUSEConnect -r $REGCODE
SUSEConnect -p sle-module-desktop-applications/15/x86_64
SUSEConnect -p sle-module-development-tools/15/x86_64 # this and above is needed for 'rpm-build' package
zypper --non-interactive ar http://download.opensuse.org/repositories/openSUSE:/Tools/SLE_15/openSUSE:Tools.repo
zypper --non-interactive --gpg-auto-import-keys ref
zypper --non-interactive up
zypper --non-interactive in -t pattern devel_osc_build
zypper --non-interactive install --no-recommend wget curl timezone \
  gcc-c++ libffi-devel git-core zlib-devel libxml2-devel libxslt-devel libmariadb-devel \
  mariadb-client mariadb ruby2.5-rubygem-bundler make build sudo ruby-devel nginx obs-service-format_spec_file
SUSEConnect -d
