%define www_base        /srv/www

Name:           potato
Version:        0.0.1
Release:        0
Summary:        Codename Potato
License:        GPL-2.0+
Group:          Productivity/Networking/Web/Proxy
Source0:        %{name}-%{version}.tar.bz2
Source1:        potato-rpmlintrc
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
mkdir -p %{buildroot}%{www_base}/potato/
cp -a * %{buildroot}%{www_base}/potato/

%files
%defattr(-,root,root)
%{www_base}/potato/

%post
cd /srv/www/potato/ && bundle.ruby2.4 --without=test:development

%changelog
