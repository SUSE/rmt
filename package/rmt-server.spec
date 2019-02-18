#
# spec file for package rmt-server
#
# Copyright (c) 2019 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


%define app_dir %{_datadir}/rmt
%define lib_dir %{_libdir}/rmt
%define data_dir %{_localstatedir}/lib/rmt
%define conf_dir %{_sysconfdir}/rmt
%define rmt_user    _rmt
%define rmt_group   nginx
%if 0%{?suse_version} == 1315
%define is_sle_12_family 1
%endif
Name:           rmt-server
Version:        1.2.1
Release:        0
Summary:        Repository mirroring tool and registration proxy for SCC
License:        GPL-2.0-or-later
Group:          Productivity/Networking/Web/Proxy
URL:            https://software.opensuse.org/package/rmt-server
Source0:        %{name}-%{version}.tar.bz2
Source1:        rmt-server-rpmlintrc
Source2:        rmt.conf
Source3:        rmt-cli.8.gz
Source4:        nginx-http.conf
Source5:        rmt-server-mirror.service
Source6:        rmt-server-mirror.timer
Source7:        rmt-server-sync.service
Source8:        rmt-server-sync.timer
Source9:        rmt-server.service
Source10:       rmt-server.target
Source11:       rmt-server-migration.service
Source12:       rmt-server-sync-sles12.timer
Source13:       rmt-server-mirror-sles12.timer
Source14:       nginx-https.conf
Source15:       auth-handler.conf
Source16:       auth-location.conf
Source17:       rmt-cli_bash-completion.sh
Source18:       rmt-server.reg
Patch0:         use-ruby-2.5-in-rmt-cli.patch
Patch1:         use-ruby-2.5-in-rails.patch
Patch2:         use-ruby-2.5-in-rmt-data-import.patch
BuildRequires:  fdupes
BuildRequires:  gcc
BuildRequires:  libcurl-devel
BuildRequires:  libffi-devel
BuildRequires:  libmysqlclient-devel
BuildRequires:  libxml2-devel
BuildRequires:  libxslt-devel
BuildRequires:  ruby2.5
BuildRequires:  ruby2.5-devel
BuildRequires:  ruby2.5-rubygem-bundler
BuildRequires:  systemd
Requires:       mariadb
Requires:       nginx
Requires(post): ruby2.5
Requires(post): ruby2.5-rubygem-bundler
Requires(post): shadow
Requires(post): timezone
Requires(post): util-linux
Conflicts:      yast2-rmt < 1.0.3
Recommends:     yast2-rmt >= 1.0.3
# Does not build for i586 and s390 and is not supported on those architectures
ExcludeArch:    %{ix86} s390

%description
This package provides a mirroring tool for RPM repositories and a registration
proxy for the SUSE Customer Center (SCC).

As registration is required for SUSE products, the registration proxy allows
one to register SUSE products within a private network.

It's possible to mirror SUSE, as well as openSUSE and other RPM repositories.
SCC organization credentials are required to synchronize SUSE products,
subscription information, and to mirror SUSE repositories.

RMT supersedes the main functionality of SMT in SLES 15.

%package pubcloud
Summary:        RMT pubcloud extensions
Group:          Productivity/Networking/Web/Proxy
Requires:       rmt-server = %version

%description pubcloud
This package extends the basic RMT functionality with capabilities
required for public cloud environments.

%prep
cp -p %{SOURCE2} .

%setup -q

%patch0 -p1
%patch1 -p1
%patch2 -p1

%build
bundle.ruby2.5 install %{?jobs:--jobs %{jobs}} --without test development --deployment --standalone

%install
mkdir -p %{buildroot}%{data_dir}
mkdir -p %{buildroot}%{lib_dir}
mkdir -p %{buildroot}%{app_dir}
mkdir -p %{buildroot}%{conf_dir}/ssl
mkdir -p %{buildroot}%{data_dir}/regsharing

mv tmp %{buildroot}%{data_dir}
mkdir %{buildroot}%{data_dir}/public
mv public/repo %{buildroot}%{data_dir}/public/
mv vendor %{buildroot}%{lib_dir}

cp -ar . %{buildroot}%{app_dir}
ln -s %{data_dir}/tmp %{buildroot}%{app_dir}/tmp
ln -s %{data_dir}/public/repo %{buildroot}%{app_dir}/public/repo
mkdir -p %{buildroot}%{_bindir}
ln -s %{app_dir}/bin/rmt-cli %{buildroot}%{_bindir}
ln -s %{app_dir}/bin/rmt-data-import %{buildroot}%{_bindir}/rmt-data-import
install -D -m 644 %{_sourcedir}/rmt-cli.8.gz %{buildroot}%{_mandir}/man8/rmt-cli.8.gz

# systemd
mkdir -p %{buildroot}%{_unitdir}

%if 0%{?is_sle_12_family}
install -m 444 %{SOURCE12} %{buildroot}%{_unitdir}/rmt-server-sync.timer
install -m 444 %{SOURCE13} %{buildroot}%{_unitdir}/rmt-server-mirror.timer
%else
install -m 444 %{SOURCE6} %{buildroot}%{_unitdir}
install -m 444 %{SOURCE8} %{buildroot}%{_unitdir}
%endif

install -m 444 %{SOURCE5} %{buildroot}%{_unitdir}
install -m 444 %{SOURCE7} %{buildroot}%{_unitdir}
install -m 444 %{SOURCE9} %{buildroot}%{_unitdir}
install -m 444 %{SOURCE10} %{buildroot}%{_unitdir}
install -m 444 %{SOURCE11} %{buildroot}%{_unitdir}
install -m 444 engines/registration_sharing/package/rmt-server-regsharing.service %{buildroot}%{_unitdir}
install -m 444 engines/registration_sharing/package/rmt-server-regsharing.timer %{buildroot}%{_unitdir}

mkdir -p %{buildroot}%{_sbindir}
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-migration
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-mirror
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-sync
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-regsharing

mkdir -p %{buildroot}%{_sysconfdir}
mv %{_builddir}/rmt.conf %{buildroot}%{_sysconfdir}/rmt.conf

# nginx
install -D -m 644 %{SOURCE4} %{buildroot}%{_sysconfdir}/nginx/vhosts.d/rmt-server-http.conf
install -D -m 644 %{SOURCE14} %{buildroot}%{_sysconfdir}/nginx/vhosts.d/rmt-server-https.conf
install -D -m 644 %{SOURCE15} %{buildroot}%{_sysconfdir}/nginx/rmt-auth.d/auth-handler.conf
install -D -m 644 %{SOURCE16} %{buildroot}%{_sysconfdir}/nginx/rmt-auth.d/auth-location.conf
install -D -m 644 package/http-certs.conf %{buildroot}%{_sysconfdir}/nginx/rmt-pubcloud.d/http-certs.conf

sed -i -e '/BUNDLE_PATH: .*/cBUNDLE_PATH: "\/usr\/lib64\/rmt\/vendor\/bundle\/"' \
    -e 's/^BUNDLE_JOBS: .*/BUNDLE_JOBS: "1"/' \
    %{buildroot}%{app_dir}/.bundle/config

# supportconfig plugin
mkdir -p %{buildroot}%{_libexecdir}/supportconfig/plugins
install -D -m 544 support/rmt %{buildroot}%{_libexecdir}/supportconfig/plugins/rmt

# bash completion
install -D -m 644 %{SOURCE17} %{buildroot}%{_datadir}/bash-completion/completions/rmt-cli

install -D -m 644 %{SOURCE18} %{buildroot}%{_sysconfdir}/slp.reg.d/rmt-server.reg

# cleanup of /usr/bin/env commands
grep -rl '\/usr\/bin\/env ruby' %{buildroot}%{lib_dir}/vendor/bundle/ruby | xargs \
    sed -i -e 's@\/usr\/bin\/env ruby.ruby2\.5@\/usr\/bin\/ruby\.ruby2\.5@g' \
    -e 's@\/usr\/bin\/env ruby@\/usr\/bin\/ruby\.ruby2\.5@g'
grep -rl '\/usr\/bin\/env bash' %{buildroot}%{lib_dir}/vendor/bundle/ruby | xargs \
    sed -i -e 's@\/usr\/bin\/env bash@\/bin\/bash@g' \

# cleanup unneeded files
find %{buildroot}%{lib_dir} "(" -name "*.c" -o -name "*.h" -o -name .keep ")" -delete
find %{buildroot}%{app_dir} -name .keep -delete
find %{buildroot}%{data_dir} -name .keep -delete
rm -r  %{buildroot}%{lib_dir}/vendor/bundle/ruby/2.*.0/cache
rm -rf %{buildroot}%{lib_dir}/vendor/cache
rm -rf %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/*/doc
rm -rf %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/*/examples
rm -rf %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/*/samples
rm -rf %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/*/test
rm -rf %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/*/ports
rm -rf %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/*/ext
rm -rf %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/*/bin
rm -rf %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/*/spec
rm -f %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/*/.gitignore
rm -f %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/extensions/*/*/*/gem_make.out
rm -f %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/extensions/*/*/*/mkmf.log
find %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/yard*/ -type f -exec chmod 644 -- {} +

%fdupes %{buildroot}/%{lib_dir}

%files
%attr(-,%{rmt_user},%{rmt_group}) %{app_dir}
%exclude %{app_dir}/engines/
%attr(-,%{rmt_user},%{rmt_group}) %{data_dir}
%attr(-,%{rmt_user},%{rmt_group}) %{conf_dir}
%attr(-,%{rmt_user},%{rmt_group}) /var/lib/rmt
%dir %{_libexecdir}/supportconfig
%dir %{_libexecdir}/supportconfig/plugins
%dir %{_sysconfdir}/nginx
%dir %{_sysconfdir}/nginx/vhosts.d
%dir /var/lib/rmt
%dir %{_sysconfdir}/slp.reg.d
%config(noreplace) %attr(0640, %{rmt_user},root) %{_sysconfdir}/rmt.conf
%config(noreplace) %{_sysconfdir}/nginx/vhosts.d/rmt-server-http.conf
%config(noreplace) %{_sysconfdir}/nginx/vhosts.d/rmt-server-https.conf
%config(noreplace) %{_sysconfdir}/slp.reg.d/rmt-server.reg
%{_mandir}/man8/rmt-cli.8%{?ext_man}
%{_bindir}/rmt-cli
%{_bindir}/rmt-data-import
%{_sbindir}/rcrmt-server
%{_sbindir}/rcrmt-server-migration
%{_sbindir}/rcrmt-server-sync
%{_sbindir}/rcrmt-server-mirror
%{_unitdir}/rmt-server.target
%{_unitdir}/rmt-server.service
%{_unitdir}/rmt-server-migration.service
%{_unitdir}/rmt-server-mirror.service
%{_unitdir}/rmt-server-mirror.timer
%{_unitdir}/rmt-server-sync.service
%{_unitdir}/rmt-server-sync.timer
%dir %{_datadir}/bash-completion/
%dir %{_datadir}/bash-completion/completions/
%{_datadir}/bash-completion/completions/rmt-cli

%{_libdir}/rmt
%{_libexecdir}/supportconfig/plugins/rmt

%files pubcloud
%attr(-,%{rmt_user},%{rmt_group}) %{app_dir}/engines/
%dir %{_sysconfdir}/nginx/rmt-auth.d/
%dir %{_sysconfdir}/nginx/rmt-pubcloud.d/
%dir %attr(-,%{rmt_user},%{rmt_group}) %{data_dir}/regsharing
%exclude %{app_dir}/engines/registration_sharing/package/
%config(noreplace) %{_sysconfdir}/nginx/rmt-auth.d/auth-handler.conf
%config(noreplace) %{_sysconfdir}/nginx/rmt-auth.d/auth-location.conf
%config(noreplace) %{_sysconfdir}/nginx/rmt-pubcloud.d/http-certs.conf

%{_sbindir}/rcrmt-server-regsharing
%{_unitdir}/rmt-server-regsharing.service
%{_unitdir}/rmt-server-regsharing.timer

%pre
getent group %{rmt_group} >/dev/null || %{_sbindir}/groupadd -r %{rmt_group}
getent passwd %{rmt_user} >/dev/null || \
	%{_sbindir}/useradd -g %{rmt_group} -s /bin/false -r \
	-c "user for RMT" -d %{app_dir} %{rmt_user}
%service_add_pre rmt-server.target rmt-server.service rmt-server-migration.service rmt-server-mirror.service rmt-server-sync.service

%post
%service_add_post rmt-server.target rmt-server.service rmt-server-migration.service rmt-server-mirror.service rmt-server-sync.service
cd %{_datadir}/rmt && runuser -u %{rmt_user} -g %{rmt_group} -- bin/rails secrets:setup >/dev/null
cd %{_datadir}/rmt && runuser -u %{rmt_user} -g %{rmt_group} -- bin/rails runner -e production "Rails::Secrets.write({'production' => {'secret_key_base' => SecureRandom.hex(64)}}.to_yaml)" >/dev/null

# Run only on install
if [ $1 -eq 1 ]; then
  echo "Please run the YaST RMT module (or 'yast2 rmt' from the command line) to complete the configuration of your RMT" >> /dev/stdout
fi

# Run only on upgrade
if [ $1 -eq 2 ]; then
  if [ -f %{app_dir}/ssl/rmt-ca.crt ]; then
    mv %{app_dir}/ssl/* %{conf_dir}/ssl
    echo "RMT SSL configuration has been moved to a new location: %{conf_dir}/ssl"
  fi
  if [ -f %{app_dir}/config/system_uuid ]; then
    mv %{app_dir}/config/system_uuid /var/lib/rmt/system_uuid
  fi
fi

%preun
%service_del_preun rmt-server.target rmt-server.service rmt-server-migration.service rmt-server-mirror.service rmt-server-sync.service

%postun
%service_del_postun rmt-server.target rmt-server.service rmt-server-migration.service rmt-server-mirror.service rmt-server-sync.service

%pre pubcloud
%service_add_pre rmt-server-regsharing.service

%post pubcloud
%service_add_post rmt-server-regsharing.service

%preun pubcloud
%service_del_preun rmt-server-regsharing.service

%postun pubcloud
%service_del_postun rmt-server-regsharing.service

%posttrans pubcloud
/usr/bin/systemctl try-restart rmt-server.service

%changelog
