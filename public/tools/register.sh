#! /bin/sh

export RMT_SERVER=deliverance.suse.cz

wget --no-check-certificate https://download.opensuse.org/repositories/home:/lpato:/sll7/CentOS_7/x86_64/zypper-1.13.55-2.1.x86_64.rpm
wget --no-check-certificate https://download.opensuse.org/repositories/home:/lpato:/sll7/CentOS_7/x86_64/libzypp-16.20.5-8.1.x86_64.rpm
wget --no-check-certificate https://download.opensuse.org/repositories/home:/lpato:/sll7/CentOS_7/x86_64/librepo-1.8.1-9.1.x86_64.rpm
wget --no-check-certificate https://download.opensuse.org/repositories/home:/lpato:/sll7/CentOS_7/x86_64/suseconnect-ng-1.6.0~git0.31371c8-2.1.x86_64.rpm
wget --no-check-certificate http://zenon.suse.de/RH_review/updates/ESEA-2024:0009/7.0-x86_64/sles_es-release-server-7.9-7.el7.x86_64.rpm

yum install librepo-1.8.1-9.1.x86_64.rpm libzypp-16.20.5-8.1.x86_64.rpm suseconnect-ng-1.6.0~git0.31371c8-2.1.x86_64.rpm zypper-1.13.55-2.1.x86_64.rpm
rpm -e --nodeps centos-release
sudo yum install sles_es-release-server-7.9-7.el7.x86_64.rpm 

wget --no-check-certificate https://raw.githubusercontent.com/plorinc/rmt/master/public/tools/rmt-client-setup-res7
sh -x rmt-client-setup-res7 https://$RMT_SERVER
