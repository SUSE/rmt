#
# spec file for package rmt-server
#
# Copyright (c) 2025 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


%define app_dir      %{_datadir}/rmt
%define lib_dir      %{_libdir}/rmt
%define data_dir     %{_localstatedir}/lib/rmt
%define conf_dir     %{_sysconfdir}/rmt
%define script_dir   %{_libexecdir}/rmt
%define rmt_user     _rmt
%define rmt_group    nginx

# Only build for the distribution default Ruby version
%define rb_build_versions     %{rb_default_ruby}
%define rb_build_ruby_abis    %{rb_default_ruby_abi}
%define ruby_version          %{rb_default_ruby_suffix}

# disabling dwz for now, as it is not available in SLE15
# related bugzilla https://bugzilla.suse.com/show_bug.cgi?id=1180984
%undefine _find_debuginfo_dwz_opts

Name:           rmt-server
Version:        2.23
Release:        0
Summary:        Repository mirroring tool and registration proxy for SCC
License:        GPL-2.0-or-later
Group:          Productivity/Networking/Web/Proxy
URL:            https://software.opensuse.org/package/rmt-server
Source0:        %{name}-%{version}.tar.bz2
Source1:        rmt-server-rpmlintrc
Source2:        rmt.conf
Source3:        rmt-cli.8.gz
BuildRequires:  %{ruby_version}
BuildRequires:  %{ruby_version}-devel
BuildRequires:  %{ruby_version}-rubygem-bundler
BuildRequires:  chrpath
BuildRequires:  fdupes
BuildRequires:  gcc
BuildRequires:  libcurl-devel
BuildRequires:  libffi-devel
BuildRequires:  libmysqlclient-devel
BuildRequires:  libxml2-devel
BuildRequires:  libxslt-devel
BuildRequires:  sqlite-devel
BuildRequires:  pkgconfig(systemd)
Requires:       gpg2
Recommends:     mariadb
Recommends:     nginx
# The config is not really required by rmt-server, but by nginx ...
Requires:       rmt-server-configuration
Requires(post): %{ruby_version}
Requires:       %{ruby_version}-rubygem-bundler
Requires(pre):  shadow
Requires(post): timezone
Requires(post): util-linux
Conflicts:      yast2-rmt < 1.0.3
Recommends:     rmt-server-config
Recommends:     yast2-rmt >= 1.3.0
Provides:       user(%{rmt_user})
# Does not build for i586 and s390 and is not supported on those architectures
ExcludeArch:    %{ix86} s390
%{systemd_ordering}

%description
This package provides a mirroring tool for RPM repositories and a registration
proxy for the SUSE Customer Center (SCC).

As registration is required for SUSE products, the registration proxy allows
one to register SUSE products within a private network.

It's possible to mirror SUSE, as well as openSUSE and other RPM repositories.
SCC organization credentials are required to synchronize SUSE products,
subscription information, and to mirror SUSE repositories.

RMT supersedes the main functionality of SMT in SLES 15.

%package config
Summary:        RMT default configuration
Group:          Productivity/Networking/Web/Proxy
Requires:       rmt-server = %version
Provides:       rmt-server-configuration
Conflicts:      rmt-server-configuration

%description config
Default nginx configuration for RMT.

%package pubcloud
Summary:        RMT pubcloud extensions
Group:          Productivity/Networking/Web/Proxy
Requires:       rmt-server = %version
Recommends:     valkey
Provides:       rmt-server-configuration
Conflicts:      rmt-server-configuration

%description pubcloud
This package extends the basic RMT functionality with capabilities
required for public cloud environments.

%prep
cp -p %{SOURCE2} .

%setup -q
sed -i '1 s|/usr/bin/env\ ruby|/usr/bin/ruby.%{ruby_version}|' bin/*
# Set the version of bundler available within the build environment instead
# of expect a hardcoded version. This ensures we bundle with the available version of bundler no matter which version available
# NOTE: This relies on the fact that the lock file format does not change between bundler versions (which is not yet the case)
sed -i "s/2\.2\.34/$(bundle.%{ruby_version} --version | grep -oE '([0-9]+\.?){3}')/g" Gemfile.lock

%build
bundle.%{ruby_version} config build.nio4r --with-cflags='%{optflags} -Wno-return-type'
bundle.%{ruby_version} config set deployment 'true'
bundle.%{ruby_version} config set without 'test development'
bundle.%{ruby_version} install %{?jobs:--jobs %{jobs}}

%install
mkdir -p %{buildroot}%{data_dir}
mkdir -p %{buildroot}%{lib_dir}
mkdir -p %{buildroot}%{app_dir}
mkdir -p %{buildroot}%{conf_dir}/ssl
mkdir -p %{buildroot}%{data_dir}/regsharing

mv tmp %{buildroot}%{data_dir}
mkdir %{buildroot}%{data_dir}/public
mv public/repo %{buildroot}%{data_dir}/public/
mv public/suma %{buildroot}%{data_dir}/public/
mv vendor %{buildroot}%{lib_dir}

cp -ar . %{buildroot}%{app_dir}
ln -s %{data_dir}/tmp %{buildroot}%{app_dir}/tmp
mkdir -p %{buildroot}%{_bindir}
ln -s %{app_dir}/bin/rmt-cli %{buildroot}%{_bindir}
ln -s %{app_dir}/bin/rmt-data-import %{buildroot}%{_bindir}/rmt-data-import
ln -s %{app_dir}/bin/rmt-test-regsharing %{buildroot}%{_bindir}
ln -s %{app_dir}/bin/rmt-manual-instance-verify %{buildroot}%{_bindir}
install -D -m 644 %{_sourcedir}/rmt-cli.8.gz %{buildroot}%{_mandir}/man8/rmt-cli.8.gz

# systemd
mkdir -p %{buildroot}%{_unitdir}

install -m 444 package/files/systemd/rmt-server-mirror.timer %{buildroot}%{_unitdir}
install -m 444 package/files/systemd/rmt-server-sync.timer %{buildroot}%{_unitdir}
install -m 444 package/files/systemd/rmt-server-systems-scc-sync.timer %{buildroot}%{_unitdir}
install -m 444 package/files/systemd/rmt-uptime-cleanup.timer %{buildroot}%{_unitdir}

install -m 444 package/files/systemd/rmt-server-mirror.service %{buildroot}%{_unitdir}
install -m 444 package/files/systemd/rmt-server-sync.service %{buildroot}%{_unitdir}
install -m 444 package/files/systemd/rmt-server-systems-scc-sync.service %{buildroot}%{_unitdir}
install -m 444 package/files/systemd/rmt-server.service %{buildroot}%{_unitdir}
install -m 444 package/files/systemd/rmt-server.target %{buildroot}%{_unitdir}
install -m 444 package/files/systemd/rmt-server-migration.service %{buildroot}%{_unitdir}
install -m 444 package/files/systemd/rmt-uptime-cleanup.service %{buildroot}%{_unitdir}

install -m 444 engines/registration_sharing/package/rmt-server-regsharing.service %{buildroot}%{_unitdir}
install -m 444 engines/registration_sharing/package/rmt-server-regsharing.timer %{buildroot}%{_unitdir}
install -m 444 engines/registration_sharing/package/rmt-server-trim-cache.service %{buildroot}%{_unitdir}
install -m 444 engines/registration_sharing/package/rmt-server-trim-cache.timer %{buildroot}%{_unitdir}

mkdir -p %{buildroot}%{_sbindir}
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-migration
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-mirror
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-sync
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-systems-scc-sync
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-uptime-cleanup

ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-regsharing
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-trim-cache

ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-regsharing
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-server-trim-cache

mkdir -p %{buildroot}%{_sysconfdir}
mv %{_builddir}/rmt.conf %{buildroot}%{_sysconfdir}/rmt.conf

# nginx
install -D -m 644 package/files/nginx/nginx-http.conf %{buildroot}%{_sysconfdir}/nginx/vhosts.d/rmt-server-http.conf
install -D -m 644 package/files/nginx/nginx-https.conf %{buildroot}%{_sysconfdir}/nginx/vhosts.d/rmt-server-https.conf

install -D -m 644 package/files/nginx-pubcloud/nginx-http.conf %{buildroot}%{_sysconfdir}/nginx/vhosts.d/rmt-server-pubcloud-http.conf
install -D -m 644 package/files/nginx-pubcloud/nginx-https.conf %{buildroot}%{_sysconfdir}/nginx/vhosts.d/rmt-server-pubcloud-https.conf
install -D -m 644 package/files/nginx-pubcloud/auth-handler.conf %{buildroot}%{_sysconfdir}/nginx/rmt-auth.d/auth-handler.conf
install -D -m 644 package/files/nginx-pubcloud/auth-location.conf %{buildroot}%{_sysconfdir}/nginx/rmt-auth.d/auth-location.conf

sed -i -e '/BUNDLE_PATH: .*/cBUNDLE_PATH: "\/usr\/lib64\/rmt\/vendor\/bundle\/"' \
    -e 's/^BUNDLE_JOBS: .*/BUNDLE_JOBS: "1"/' \
    %{buildroot}%{app_dir}/.bundle/config

# supportconfig plugin
mkdir -p %{buildroot}%{_libexecdir}/supportconfig/plugins
install -D -m 544 support/rmt %{buildroot}%{_libexecdir}/supportconfig/plugins/rmt

# Directory permission update script
mkdir -p %{buildroot}%{script_dir}
install -D -m 544 package/files/update_rmt_app_dir_permissions.sh %{buildroot}%{script_dir}/update_rmt_app_dir_permissions.sh

# bash completion
install -D -m 644 package/files/rmt-cli_bash-completion.sh %{buildroot}%{_datadir}/bash-completion/completions/rmt-cli

install -D -m 644 package/files/rmt-server.reg %{buildroot}%{_sysconfdir}/slp.reg.d/rmt-server.reg

# cleanup of /usr/bin/env commands
grep -rl '\/usr\/bin\/env ruby' %{buildroot}%{lib_dir}/vendor/bundle/ruby | xargs \
    sed -i -e 's@\/usr\/bin\/env ruby.%{ruby_version}@\/usr\/bin\/ruby\.%{ruby_version}@g' \
    -e 's@\/usr\/bin\/env ruby@\/usr\/bin\/ruby\.%{ruby_version}@g'
grep -rl '\/usr\/bin\/env bash' %{buildroot}%{lib_dir}/vendor/bundle/ruby | xargs \
    sed -i -e 's@\/usr\/bin\/env bash@\/bin\/bash@g'

# Drop 'BUNDLED WITH' line from Gemfile.lock. It causes trouble when the Gemfile.lock
# was created with a different major version than the distribution's bundler.
sed -i '/BUNDLED WITH/{N;d;}' %{buildroot}%{app_dir}/Gemfile.lock

# Drop warning "Nokogiri was built against libxml version x, but has dynamically y"
# Because we cannot control which libxml version is installed on the system
sed -i 's|warnings << "Nokogiri was built|# warnings << "Nokogiri was built|' %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/nokogiri-*/lib/nokogiri/version/info.rb

# cleanup unneeded files
find %{buildroot}%{lib_dir} "(" -name "*.c" -o -name "*.h" -o -name .keep ")" -delete
find %{buildroot}%{app_dir} -name .keep -delete
find %{buildroot}%{data_dir} -name .keep -delete
rm -r  %{buildroot}%{lib_dir}/vendor/bundle/ruby/[23].*.0/cache
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

# drop custom rpath from native gems
chrpath -d %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/mysql2-*/lib/mysql2/mysql2.so
chrpath -d %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/extensions/*/*/mysql2-*/mysql2/mysql2.so

%files
%attr(0755,root,root) %{app_dir}
%attr(0755,root,root) %{app_dir}/public/tools
%exclude %{app_dir}/engines/
%exclude %{app_dir}/package/
%exclude %{app_dir}/rmt/tmp
%attr(-,%{rmt_user},%{rmt_group}) %{data_dir}
%attr(-,%{rmt_user},%{rmt_group}) %{conf_dir}
%dir %{_libexecdir}/supportconfig
%dir %{_libexecdir}/supportconfig/plugins
%dir %{script_dir}
%dir /var/lib/rmt
%ghost %{_datadir}/rmt/public/repo
%ghost %{_datadir}/rmt/public/suma

# The secrets file is created by running the initial rake tasks in the `post` section
%ghost %attr(0640,root,%{rmt_group}) %{app_dir}/config/secrets.yml.key
%ghost %attr(0640,root,%{rmt_group}) %{app_dir}/config/secrets.yml.enc

%dir %{_sysconfdir}/slp.reg.d
%config(noreplace) %attr(0640, %{rmt_user}, root) %{_sysconfdir}/rmt.conf
%config(noreplace) %{_sysconfdir}/slp.reg.d/rmt-server.reg

%{_mandir}/man8/rmt-cli.8%{?ext_man}
%{_bindir}/rmt-cli
%{_bindir}/rmt-data-import
%{_sbindir}/rcrmt-server
%{_sbindir}/rcrmt-server-migration
%{_sbindir}/rcrmt-server-sync
%{_sbindir}/rcrmt-server-mirror
%{_sbindir}/rcrmt-server-systems-scc-sync
%{_sbindir}/rcrmt-uptime-cleanup
%{_unitdir}/rmt-server.target
%{_unitdir}/rmt-server.service
%{_unitdir}/rmt-server-migration.service
%{_unitdir}/rmt-server-mirror.service
%{_unitdir}/rmt-server-mirror.timer
%{_unitdir}/rmt-server-sync.service
%{_unitdir}/rmt-server-sync.timer
%{_unitdir}/rmt-server-systems-scc-sync.service
%{_unitdir}/rmt-server-systems-scc-sync.timer
%{_unitdir}/rmt-uptime-cleanup.service
%{_unitdir}/rmt-uptime-cleanup.timer
%config(noreplace) %{_unitdir}/rmt-server-mirror.timer
%config(noreplace) %{_unitdir}/rmt-server-sync.timer
%config(noreplace) %{_unitdir}/rmt-server-systems-scc-sync.timer
%config(noreplace) %{_unitdir}/rmt-uptime-cleanup.timer

%dir %{_datadir}/bash-completion/
%dir %{_datadir}/bash-completion/completions/
%{_datadir}/bash-completion/completions/rmt-cli

%{_libdir}/rmt
%{_libexecdir}/supportconfig/plugins/rmt
%{script_dir}/update_rmt_app_dir_permissions.sh

%files config
%dir %{_sysconfdir}/nginx
%dir %{_sysconfdir}/nginx/vhosts.d
%config(noreplace) %{_sysconfdir}/nginx/vhosts.d/rmt-server-http.conf
%config(noreplace) %{_sysconfdir}/nginx/vhosts.d/rmt-server-https.conf

%files pubcloud
%{_bindir}/rmt-test-regsharing
%{_bindir}/rmt-manual-instance-verify
%attr(-,root,root) %{app_dir}/engines/
%dir %{_sysconfdir}/nginx/rmt-auth.d/
%dir %attr(-,%{rmt_user},%{rmt_group}) %{data_dir}/regsharing
%exclude %{app_dir}/engines/registration_sharing/package/
%dir %{_sysconfdir}/nginx
%dir %{_sysconfdir}/nginx/vhosts.d
%config(noreplace) %{_sysconfdir}/nginx/vhosts.d/rmt-server-pubcloud-http.conf
%config(noreplace) %{_sysconfdir}/nginx/vhosts.d/rmt-server-pubcloud-https.conf
%config(noreplace) %{_sysconfdir}/nginx/rmt-auth.d/auth-handler.conf
%config(noreplace) %{_sysconfdir}/nginx/rmt-auth.d/auth-location.conf

%{_sbindir}/rcrmt-server-regsharing
%{_sbindir}/rcrmt-server-trim-cache
%{_unitdir}/rmt-server-regsharing.service
%{_unitdir}/rmt-server-regsharing.timer
%{_unitdir}/rmt-server-trim-cache.service
%{_unitdir}/rmt-server-trim-cache.timer
%config(noreplace) %{_unitdir}/rmt-server-regsharing.timer
%config(noreplace) %{_unitdir}/rmt-server-trim-cache.timer

%pre
getent group %{rmt_group} >/dev/null || %{_sbindir}/groupadd -r %{rmt_group}
getent passwd %{rmt_user} >/dev/null || \
	%{_sbindir}/useradd -g %{rmt_group} -s /bin/false -r \
	-c "user for RMT" %{rmt_user}
%service_add_pre rmt-server.target rmt-server.service rmt-server-migration.service rmt-server-mirror.service rmt-server-sync.service rmt-server-systems-scc-sync.service rmt-uptime-cleanup.service

%post
%service_add_post rmt-server.target rmt-server.service rmt-server-migration.service rmt-server-mirror.service rmt-server-sync.service rmt-server-systems-scc-sync.service rmt-uptime-cleanup.service

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
  bash %{script_dir}/update_rmt_app_dir_permissions.sh %{app_dir}

  echo "RMT database migration in progress. This could take some time."
  echo ""
  echo "To check current migration status:"
  echo "  systemctl status rmt-server-migration.service"
fi

if [ ! -e %{_datadir}/rmt/public/repo ]; then
 ln -ns %{_sharedstatedir}/rmt/public/repo %{_datadir}/rmt/public/repo
fi

if [ ! -e %{_datadir}/rmt/public/suma ]; then
 ln -ns %{_sharedstatedir}/rmt/public/suma %{_datadir}/rmt/public/suma
fi

%preun
%service_del_preun rmt-server.target rmt-server.service rmt-server-migration.service rmt-server-mirror.service rmt-server-sync.service rmt-server-systems-scc-sync.service rmt-uptime-cleanup.service

%postun
%service_del_postun rmt-server.target rmt-server.service rmt-server-migration.service rmt-server-mirror.service rmt-server-sync.service rmt-server-systems-scc-sync.service rmt-uptime-cleanup.service

%posttrans config
# Don't fail if either systemd or nginx are not running
/usr/bin/systemctl try-reload-or-restart nginx.service || true

%pre pubcloud
%service_add_pre rmt-server-regsharing.service rmt-server-trim-cache.service

%post pubcloud
%service_add_post rmt-server-regsharing.service rmt-server-trim-cache.service

%preun pubcloud
%service_del_preun rmt-server-regsharing.service rmt-server-trim-cache.service

%postun pubcloud
%service_del_postun rmt-server-regsharing.service rmt-server-trim-cache.service

%posttrans pubcloud
/usr/bin/systemctl try-restart rmt-server.service
# Don't fail if either systemd or nginx are not running
/usr/bin/systemctl try-reload-or-restart nginx.service || true

%changelog
