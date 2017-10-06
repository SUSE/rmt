%define www_base        /srv/www/rmt/

Name:           rmt
Version:        0.0.1
Release:        0
Summary:        Repository Mirroring Tool
License:        GPL-2.0+
Group:          Productivity/Networking/Web/Proxy
Source0:        %{name}-%{version}.tar.bz2
Source1:        rmt-rpmlintrc
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

BuildRequires: ruby2.4 ruby2.4-devel ruby2.4-rubygem-bundler gcc libffi-devel libmysqlclient-devel libxml2-devel libxslt-devel

Requires: ruby2.4 mariadb

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

mkdir %{buildroot}/etc/
mv %{buildroot}%{www_base}/config/rmt.yml %{buildroot}/etc/rmt.conf
rm -rf %{buildroot}%{www_base}/vendor/cache

%files
%defattr(-,root,root)
%{www_base}
/etc/rmt.conf

%post

%changelog
