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

%define www_base    /srv/www/rmt/
%define systemd_dir %{_prefix}/lib/systemd/system/
%define rmt_user    _rmt
%define rmt_group   nginx
Name:           rmt
Version:        0.0.1
Release:        0
Summary:        Repository mirroring tool and registration proxy for SCC
License:        GPL-2.0+
Group:          Productivity/Networking/Web/Proxy
URL:            https://software.opensuse.org/package/rmt
Source0:        %{name}-%{version}.tar.bz2
Source1:        rmt-rpmlintrc
Source2:        rmt.conf
Source3:        rmt.8.gz
%if 0%{?use_ruby_2_4}
Patch0:         use-ruby-2.4-in-rmt-cli.patch
Patch1:         use-ruby-2.4-in-rails.patch
%else
Patch0:         use-ruby-2.5-in-rmt-cli.patch
Patch1:         use-ruby-2.5-in-rails.patch
%endif
%if 0%{?use_ruby_2_4}
Requires(post): ruby2.4
Requires(post): ruby2.4-rubygem-puma
Requires(post): ruby2.4-rubygem-mysql2
Requires(post): ruby2.4-rubygem-nokogiri
Requires(post): ruby2.4-rubygem-thor
Requires(post): ruby2.4-rubygem-versionist
Requires(post): ruby2.4-rubygem-responders
Requires(post): ruby2.4-rubygem-typhoeus
Requires(post): ruby2.4-rubygem-active_model_serializers
Requires(post): ruby2.4-rubygem-fast_gettext
Requires(post): ruby2.4-rubygem-gettext_i18n_rails
Requires(post): ruby2.4-rubygem-config
Requires(post): ruby2.4-rubygem-terminal-table
%else
Requires(post): ruby2.5
Requires(post): ruby2.5-rubygem-puma
Requires(post): ruby2.5-rubygem-mysql2
Requires(post): ruby2.5-rubygem-nokogiri
Requires(post): ruby2.5-rubygem-thor
Requires(post): ruby2.5-rubygem-versionist
Requires(post): ruby2.5-rubygem-responders
Requires(post): ruby2.5-rubygem-typhoeus
Requires(post): ruby2.5-rubygem-active_model_serializers
Requires(post): ruby2.5-rubygem-fast_gettext
Requires(post): ruby2.5-rubygem-gettext_i18n_rails
Requires(post): ruby2.5-rubygem-config
Requires(post): ruby2.5-rubygem-terminal-table
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

RMT superseeds the main functionality of SMT in SLES 15.

%prep
cp -p %SOURCE2 .

%setup -q
%patch0 -p1
%patch1 -p1

%build

%install
mkdir -p %{buildroot}%{www_base}
cp -ar . %{buildroot}%{www_base}
mkdir -p %{buildroot}%{_bindir}
ln -s %{www_base}/bin/rmt-cli %{buildroot}%{_bindir}
install -D -m 644 %_sourcedir/rmt.8.gz %{buildroot}%_mandir/man8/rmt.8.gz

# systemd
mkdir -p %{buildroot}%{systemd_dir}
install -m 444 service/rmt.target %{buildroot}%{systemd_dir}
install -m 444 service/rmt.service %{buildroot}%{systemd_dir}
install -m 444 service/rmt-migration.service %{buildroot}%{systemd_dir}
mkdir -p %{buildroot}%{_sbindir}
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt
ln -fs %{_sbindir}/service %{buildroot}%{_sbindir}/rcrmt-migration

mkdir -p %{buildroot}%{_sysconfdir}
mv %{_builddir}/rmt.conf %{buildroot}%{_sysconfdir}/rmt.conf

# cleanup unneeded files
rm -r %{buildroot}%{www_base}/service

%files
%defattr(-,root,root)
%attr(-,%{rmt_user},%{rmt_group}) %{www_base}
%config(noreplace) %{_sysconfdir}/rmt.conf
%doc %{_mandir}/man8/rmt.8.gz
%{_bindir}/rmt-cli
%{_sbindir}/rcrmt
%{_sbindir}/rcrmt-migration
%{_libexecdir}/systemd/system/rmt.target
%{_libexecdir}/systemd/system/rmt.service
%{_libexecdir}/systemd/system/rmt-migration.service

%pre
getent group %{rmt_group} >/dev/null || %{_sbindir}/groupadd -r %{rmt_group}
getent passwd %{rmt_user} >/dev/null || \
	%{_sbindir}/useradd -g %{rmt_group} -s /bin/false -r \
	-c "user for RMT" -d %{www_base} %{rmt_user}
%service_add_pre rmt.target rmt.service rmt-migration.service

%post
%service_add_post rmt.target rmt.service rmt-migration.service
cd /srv/www/rmt && runuser -u %{rmt_user} -g %{rmt_group} -- bin/rails secrets:setup >/dev/null
cd /srv/www/rmt && runuser -u %{rmt_user} -g %{rmt_group} -- bin/rails runner -e production "Rails::Secrets.write({'production' => {'secret_key_base' => SecureRandom.hex(64)}}.to_yaml)"

%preun
%service_del_preun rmt.target rmt.service rmt-migration.service

%postun
%service_del_postun rmt.target rmt.service rmt-migration.service

%changelog
