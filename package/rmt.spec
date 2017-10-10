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


%define www_base    /srv/www/rmt/
%define systemd_dir %{_prefix}/lib/systemd/system/
%define rmt_user    rmt
%define rmt_group   nginx
Name:           rmt
Version:        0.0.1
Release:        0
Summary:        Repository Mirroring Tool
License:        GPL-2.0+
Group:          Productivity/Networking/Web/Proxy
URL:            https://software.opensuse.org/package/rmt
Source0:        %{name}-%{version}.tar.bz2
Source1:        rmt-rpmlintrc
Source2:        rmt.conf
Patch0:         use-ruby-2.4-in-rmt-cli.patch
Patch1:         use-ruby-2.4-in-rails.patch
BuildRequires:  gcc
BuildRequires:  libcurl-devel
BuildRequires:  libffi-devel
BuildRequires:  libmysqlclient-devel
BuildRequires:  libxml2-devel
BuildRequires:  libxslt-devel
BuildRequires:  ruby2.4
BuildRequires:  ruby2.4-devel
BuildRequires:  ruby2.4-rubygem-bundler
Requires:       mariadb
Requires:       ruby2.4
Requires:       ruby2.4-rubygem-bundler
Requires(post): timezone

%description
This tool allows you to mirror RPM repositories in your own private network.

%prep
cp -p %SOURCE2 .

%setup -q
%patch0 -p1
%patch1 -p1

%build
bundle.ruby2.4 install %{?jobs:--jobs %jobs} --local --without test development

%install
mkdir -p %{buildroot}%{www_base}
cp -ar . %{buildroot}%{www_base}
mkdir -p %{buildroot}%{_bindir}
ln -s %{www_base}/bin/rmt-cli %{buildroot}%{_bindir}

# cleanup unneeded files
rm -r %{buildroot}%{www_base}/vendor/bundle/ruby/2.4.0/cache
find %{buildroot}%{www_base} -name '*.c' -exec rm {} \;
find %{buildroot}%{www_base} -name '*.h' -exec rm {} \;

mkdir -p %{buildroot}%{systemd_dir}
install -m 444 service/rmt.target %{buildroot}%{systemd_dir}
install -m 444 service/rmt.service %{buildroot}%{systemd_dir}
install -m 444 service/rmt-migration.service %{buildroot}%{systemd_dir}

mkdir -p %{buildroot}%{_sysconfdir}
mv %{_builddir}/rmt.conf %{buildroot}%{_sysconfdir}/rmt.conf
rm -rf %{buildroot}%{www_base}/vendor/cache

%files
%defattr(-,root,root)
%attr(755,%{rmt_user},%{rmt_group}) %{www_base}
%config(noreplace) %{_sysconfdir}/rmt.conf
%{_bindir}/rmt-cli
%{_libexecdir}/systemd/system/rmt.target
%{_libexecdir}/systemd/system/rmt.service
%{_libexecdir}/systemd/system/rmt-migration.service

%pre
%{_sbindir}/groupadd -r %{rmt_group} &>/dev/null ||:
%{_sbindir}/useradd -g %{rmt_group} -s /bin/false -r -c "user for RMT" -d %{www_base} %{rmt_user} &>/dev/null ||:
%service_add_pre rmt.target
%service_add_pre rmt.service
%service_add_pre rmt-migration.service

%post
%service_add_post rmt.target
%service_add_post rmt.service
%service_add_post rmt-migration.service
cd /srv/www/rmt && bin/rails secrets:setup >/dev/null
cd /srv/www/rmt && bin/rails runner -e production "Rails::Secrets.write({'production' => {'secret_key_base' => SecureRandom.hex(64)}}.to_yaml)"

%preun
%service_del_preun rmt-migration.service

# no postun service handling for target or schema-upgrade, we don't want them to be restarted on upgrade
%postun
%service_del_postun rmt.service

%changelog
