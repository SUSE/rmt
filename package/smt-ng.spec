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

Requires(post): ruby2.4
Requires(post): ruby2.4-rubygem-bundler
Requires(post): ruby2.4-rubygem-nio4r
Requires(post): ruby2.4-rubygem-nokogiri
Requires(post): ruby2.4-rubygem-puma
Requires(post): ruby2.4-rubygem-sqlite3
Requires(post): ruby2.4-rubygem-websocket-driver

%description
Subscription management tool NG

%prep
%setup

%build

%install
mkdir -p %{buildroot}%{www_base}/smt-ng/
cp -a * %{buildroot}%{www_base}/smt-ng/

%files
%defattr(-,root,root)
%{www_base}/smt-ng/

%post
cd /srv/www/smt-ng/ && bundle.ruby2.4 --without=test:development

%changelog
