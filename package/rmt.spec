%define www_base    /srv/www/rmt/
%define systemd_dir /usr/lib/systemd/system/
%define rmt_user    rmt
%define rmt_group   nginx

Name:           rmt
Version:        0.0.1
Release:        0
Summary:        Repository Mirroring Tool
License:        GPL-2.0+
Group:          Productivity/Networking/Web/Proxy
Source0:        %{name}-%{version}.tar.bz2
Source1:        rmt-rpmlintrc
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

Requires: ruby2.4 ruby2.4-rubygem-bundler mariadb
Requires(pre): ruby2.4-rubygem-bundler

BuildRequires: gcc ruby2.4-devel libffi-devel libmysqlclient-devel libxml2-devel libxslt-devel

%description
This tool allows you to mirror RPM repositories in your own private network.

%prep
%setup

%build
bundle.ruby2.4 install --local --without test development

%install
mkdir -p %{buildroot}%{www_base}
cp -ar . %{buildroot}%{www_base}
find %{buildroot}%{www_base} -name '*.c' -exec rm {} \;
find %{buildroot}%{www_base} -name '*.h' -exec rm {} \;
mkdir -p %{buildroot}%{systemd_dir}
install -m 444 service/rmt.target %{buildroot}%{systemd_dir}
install -m 444 service/rmt.service %{buildroot}%{systemd_dir}
install -m 444 service/rmt-migration.service %{buildroot}%{systemd_dir}

mkdir %{buildroot}/etc/
mv %{buildroot}%{www_base}/config/rmt.yml %{buildroot}/etc/rmt.conf
rm -rf %{buildroot}%{www_base}/vendor/cache

%files
%defattr(-,root,root)
%attr(750,%{rmt_user},%{rmt_group}) %{www_base}
%config(noreplace) /etc/rmt.conf
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

%preun
%service_del_preun rmt-migration.service

# no postun service handling for target or schema-upgrade, we don't want them to be restarted on upgrade
%postun
%service_del_postun rmt.service

%changelog
