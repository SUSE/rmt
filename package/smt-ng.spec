%define www_base        /srv/www

Name:           smt-ng
Version:        0.0.1
Release:        0
Summary:        SMT NG
License:        GPL-2.0+
Group:          Productivity/Networking/Web/Proxy
Source0:        %{name}-%{version}.tar.bz2
Source1:        smt-ng-rpmlintrc
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

Requires:       ruby2.4
Requires:       ruby2.4-rubygem-bundler
Requires:       ruby2.4-rubygem-nio4r
Requires:       ruby2.4-rubygem-nokogiri
Requires:       ruby2.4-rubygem-puma
Requires:       ruby2.4-rubygem-sqlite3
Requires:       ruby2.4-rubygem-websocket-driver

%description
Subscription management tool NG

%prep
%setup

%build

%install
make DESTDIR=%{buildroot} install

%files
%defattr(-,root,root)
%{www_base}/smt-ng/

%post
cd /srv/www/smt-ng/ && bundle.ruby2.4 --without=test:development

%changelog
