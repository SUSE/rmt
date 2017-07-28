%define www_base        /srv/www

Name:           rmt
Version:        0.0.1
Release:        0
Summary:        Repository Mirroring Tool
License:        GPL-2.0+
Group:          Productivity/Networking/Web/Proxy
Source0:        %{name}-%{version}.tar.bz2
Source1:        rmt-rpmlintrc
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
mkdir -p %{buildroot}%{www_base}/rmt/
cp -a * %{buildroot}%{www_base}/rmt/

%files
%defattr(-,root,root)
%{www_base}/rmt/

%post
cd /srv/www/rmt/ && bundle.ruby2.4 --without=test:development

%changelog
