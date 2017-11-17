#
# spec file for package rmt
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
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


%if (0%{?suse_version} > 0 && 0%{?suse_version} <= 1320) || (0%{?sle_version} > 0 && 0%{?sle_version} <= 120300)
%define use_ruby_2_4 1
%endif

%define app_dir /usr/share/rmt/
%define lib_dir %{_libdir}/rmt/
%define data_dir /var/lib/rmt/
%define rmt_user    _rmt
%define rmt_group   nginx
Name:           rmt
Version:        0.0.1
Release:        0
Summary:        Repository mirroring tool and registration proxy for SCC
License:        GPL-2.0+
Group:          Productivity/Networking/Web/Proxy
Url:            https://software.opensuse.org/package/rmt
Source0:        %{name}-%{version}.tar.bz2
Source1:        rmt-rpmlintrc
Source2:        rmt.conf
Source3:        rmt.8.gz
Patch0:         use-ruby-2.4-in-rmt-cli.patch
Patch1:         use-ruby-2.4-in-rails.patch
Patch2:         use-ruby-2.5-in-rmt-cli.patch
Patch3:         use-ruby-2.5-in-rails.patch
BuildRequires:  gcc
BuildRequires:  libcurl-devel
BuildRequires:  libffi-devel
BuildRequires:  libmysqlclient-devel
BuildRequires:  libxml2-devel
BuildRequires:  libxslt-devel
%if 0%{?use_ruby_2_4}
BuildRequires:  ruby2.4
BuildRequires:  ruby2.4-devel
BuildRequires:  ruby2.4-rubygem-bundler
%else
BuildRequires:  ruby2.5
BuildRequires:  ruby2.5-devel
BuildRequires:  ruby2.5-stdlib
%endif
BuildRequires:  fdupes
Requires:       mariadb

%if 0%{?use_ruby_2_4}
Requires(post): ruby2.4
Requires(post): ruby2.4-rubygem-puma
Requires(post): ruby2.4-rubygem-nokogiri
Requires(post): ruby2.4-rubygem-fast_gettext
Requires(post): ruby2.4-rubygem-gettext_i18n_rails
Requires(post): ruby2.4-rubygem-thor
%else
Requires(post): ruby2.5
Requires(post): ruby2.5-rubygem-puma = 3.10.0
Requires(post): ruby2.5-rubygem-nokogiri = 1.8.1
Requires(post): ruby2.5-rubygem-fast_gettext = 1.5.1
Requires(post): ruby2.5-rubygem-gettext_i18n_rails = 1.8.0
Requires(post): ruby2.5-rubygem-thor = 0.20.0
%endif

Requires(post): timezone
Requires(post): util-linux
Requires(post): shadow

%description
This package provides a mirroring tool for RPM repositories and a registration
proxy for the SUSE Customer Center (SCC).

As registration is required for SUSE products, the registration proxy allows
one to register SUSE products within a private network.

It's possible to mirror SUSE, as well as openSUSE and other RPM repositories.
SCC organization credentials are required to synchronize SUSE products,
subscription information, and to mirror SUSE repositories.

RMT supersedes the main functionality of SMT in SLES 15.

%prep
cp -p %SOURCE2 .

%setup -q

%if 0%{?use_ruby_2_4}
%patch0 -p1
%patch1 -p1
%else
%patch2 -p1
%patch3 -p1
%endif

%build
%if 0%{?use_ruby_2_4}
bundle.ruby2.4 install %{?jobs:--jobs %jobs} --without test development system_gems --deployment --standalone
%else
bundle.ruby.ruby2.5 install %{?jobs:--jobs %jobs} --without test development system_gems --deployment --standalone
%endif

%install
mkdir -p %{buildroot}%{data_dir}
mkdir -p %{buildroot}%{lib_dir}
mkdir -p %{buildroot}%{app_dir}

mv log %{buildroot}%{data_dir}
mv tmp %{buildroot}%{data_dir}
mv public %{buildroot}%{data_dir}
mv vendor %{buildroot}%{lib_dir}

cp -ar . %{buildroot}%{app_dir}
ln -s %{data_dir}/log %{buildroot}%{app_dir}/log
ln -s %{data_dir}/tmp %{buildroot}%{app_dir}/tmp
ln -s %{data_dir}/public %{buildroot}%{app_dir}/public
mkdir -p %{buildroot}%{_bindir}
ln -s %{app_dir}/bin/rmt-cli %{buildroot}%{_bindir}
install -D -m 644 %_sourcedir/rmt.8.gz %{buildroot}%_mandir/man8/rmt.8.gz

# systemd
mkdir -p %{buildroot}%{_unitdir}
install -m 444 service/rmt.target %{buildroot}%{_unitdir}
install -m 444 service/rmt.service %{buildroot}%{_unitdir}
install -m 444 service/rmt-migration.service %{buildroot}%{_unitdir}
mkdir -p %{buildroot}%{_sbindir}
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-migration

mkdir -p %{buildroot}%{_sysconfdir}
mv %{_builddir}/rmt.conf %{buildroot}%{_sysconfdir}/rmt.conf

sed -i '/BUNDLE_PATH: .*/cBUNDLE_PATH: "\/usr\/lib64\/rmt\/vendor\/bundle\/"' %{buildroot}%{app_dir}/.bundle/config
sed -i 's/BUNDLE_DISABLE_SHARED_GEMS.*/BUNDLE_DISABLE_SHARED_GEMS: "false"/' %{buildroot}%{app_dir}/.bundle/config
sed -i 's/group :system_gems .*//' %{buildroot}%{app_dir}/Gemfile
sed -i 's/.*# system_gems//' %{buildroot}%{app_dir}/Gemfile

# cleanup unneeded files
rm -r %{buildroot}%{app_dir}/service
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
rm -rf %{buildroot}%{lib_dir}/vendor/bundle/ruby/*/gems/*/.gitignore

%fdupes %{buildroot}/%{lib_dir}

%files
%defattr(-,root,root)
%attr(-,%{rmt_user},%{rmt_group}) %{app_dir}
%attr(-,%{rmt_user},%{rmt_group}) %{data_dir}
%config(noreplace) %{_sysconfdir}/rmt.conf
%doc %{_mandir}/man8/rmt.8.gz
%{_bindir}/rmt-cli
%{_sbindir}/rcrmt
%{_sbindir}/rcrmt-migration
%{_unitdir}/rmt.target
%{_unitdir}/rmt.service
%{_unitdir}/rmt-migration.service
%{_libdir}/rmt

%pre
getent group %{rmt_group} >/dev/null || %{_sbindir}/groupadd -r %{rmt_group}
getent passwd %{rmt_user} >/dev/null || \
	%{_sbindir}/useradd -g %{rmt_group} -s /bin/false -r \
	-c "user for RMT" -d %{app_dir} %{rmt_user}
%service_add_pre rmt.target rmt.service rmt-migration.service

%post
%service_add_post rmt.target rmt.service rmt-migration.service
cd /usr/share/rmt && runuser -u %{rmt_user} -g %{rmt_group} -- bin/rails secrets:setup >/dev/null
cd /usr/share/rmt && runuser -u %{rmt_user} -g %{rmt_group} -- bin/rails runner -e production "Rails::Secrets.write({'production' => {'secret_key_base' => SecureRandom.hex(64)}}.to_yaml)"

%preun
%service_del_preun rmt.target rmt.service rmt-migration.service

%postun
%service_del_postun rmt.target rmt.service rmt-migration.service

%changelog
