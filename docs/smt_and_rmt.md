## Comparison of features between SMT, RMT and SUSE Manager

RMT replaces some functionality of [SMT](https://github.com/SUSE/smt).
The following table outlines the differences and similarities between the three tools.
The last SUSE Linux Enterprise Server version where SMT is available is 12 SP5.
From SUSE Linux Enterprise Server 15 onward, only RMT or SUMA is available.

> Note: RMT is fully maintained and receives new features, bug fixes, and perfomance improvements.
> SMT no longer receives new features, only critical security and bug fixes.
> You can [migrate an SMT server to RMT](https://documentation.suse.com/sles/15-SP2/html/SLES-all/cha-rmt-migrate.html).

| Feature/Tech      | SMT           | RMT           | SUMA          |
|-------------------|:-------------:|:-------------:|:-------------:|
|Available on SLES 11|:heavy_check_mark:|:x:|:x:|
|Available on SLES 12|:heavy_check_mark:|:x:|:x:|
|Available on SLES 15|:x:|:heavy_check_mark:|:heavy_check_mark:|
|Sync products data from SCC|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Mirror RPMs from repositories|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Select which products to mirror|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Serve RPMs via http/https|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Registration of SLE 15 systems|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Registration of SLE 12 systems|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Registration of SLE 11 systems|:heavy_check_mark:|:x:|:heavy_check_mark:|
|Registration of openSUSE Leap 15 systems|:x:|:x:|:heavy_check_mark:|
|Registeation of non-SUSE products (RHEL, Ubuntu, etc)|:x:|:x:|:heavy_check_mark:|
|Red Hat 7 and earlier support ([Expanded Support](https://www.suse.com/products/expandedsupport/))|:heavy_check_mark:|:x:|:heavy_check_mark:|
|Red Hat 8 support ([Expanded Support](https://www.suse.com/products/expandedsupport/))|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Support for migrating SLE 12 systems to 15|:warning:<sup>[1](#partial-migration)</sup>|:heavy_check_mark:|:heavy_check_mark:|
|Support for migrating SLE 15 SPx systems to 15 SPx+1|:warning:<sup>[1](#partial-migration)</sup>|:heavy_check_mark:|:heavy_check_mark:|
|Staging repositories|:heavy_check_mark:|:x:<sup>[2](#staging)</sup>|:heavy_check_mark:|
|Air gap sync/mirroring for secure environments|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|NTLM Proxy support|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Custom repositories|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|YaST installation wizard|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Management wizard|:heavy_check_mark: (Yast)|:x:|:heavy_check_mark: (SUMA WebUI)|
|Client management|:heavy_check_mark:|:x:|:heavy_check_mark:|
|File deduplication|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Transfer registration data to SCC|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Reporting|:heavy_check_mark:|:x:|:heavy_check_mark:|
|Custom TLS certificates for web-server|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Clean up data from repositories that are not used any longer|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|Bash completion|:x:|:heavy_check_mark:|:x:|
|Available on [openSUSE Leap 15](https://github.com/SUSE/rmt/blob/master/docs/installation.md#installation-on-opensuse-leap-15)|:x:|:heavy_check_mark:<sup>[3](#self-support)</sup>|:heavy_check_mark: (Uyuni, #self-support)|
|Option to [run as container](https://github.com/SUSE/rmt/blob/master/README.md#development-setup---docker-compose)|:x:|:heavy_check_mark:<sup>[3](#self-support)</sup>|:x:|
|Easy development setup |:x:|:heavy_check_mark:|:heavy_check_mark:|
|100% test [coverage](https://coveralls.io/github/SUSE/rmt?branch=master)|:x:|:heavy_check_mark:|:x:|
|[Plugin functionality](https://github.com/SUSE/rmt/blob/master/docs/PLUGINS.md)|:x:|:heavy_check_mark:|:heavy_check_mark:|
|Webserver|Apache2|Nginx|Apache2 and Tomcat|
|Database|MariaDB|MariaDB|PostgreSQL|
|Platform|Perl|Ruby|Java and Python|

<a name="partial-migration">1</a>: SMT only partially supports migrating systems to SLE 15. SLE 15 is composed of multiple [modules and extensions](https://documentation.suse.com/sles/15-SP2/html/SLES-all/art-modules.html).
Some modules are not required, as they provide additional functionality.
RMT fully supports migrations into and within SLE 15, so it will only add the minimal required modules.
SMT does not fully support these migrations, and it will enable all available modules on the system.\
<a name="staging">2</a>: This functionality is offered by [SUSE Manager](https://www.suse.com/documentation/suse-best-practices/susemanager/data/susemanager.html).\
<a name="self-support">3</a>: Only available with [self-support](https://www.suse.com/support/self-support/).
