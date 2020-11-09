## RMT and SMT

RMT is replacing some functionality of [SMT](https://github.com/SUSE/smt). Following table outlines differences and similarities between the two tools. Last SLE version where SMT is available is 12. From version 15 onward only RMT is offered.

| Feature/Tech      | SMT           | RMT           |
|-------------------|:-------------:|:-------------:|
|Available on SLES11|:heavy_check_mark:|:x:|
|Available on SLES12|:heavy_check_mark:|:x:|
|Available on SLES15|:x:|:heavy_check_mark:|
|Sync products data from SCC|:heavy_check_mark:|:heavy_check_mark:|
|Mirror RPMs from repositories|:heavy_check_mark:|:heavy_check_mark:|
|Selective mirroring(which products to mirror)|:heavy_check_mark:|:heavy_check_mark:|
|Serve RPMs via http|:heavy_check_mark:|:heavy_check_mark:|
|Registration of SLE 15 systems|:heavy_check_mark:|:heavy_check_mark:|
|Registration of SLE 12 systems|:heavy_check_mark:|:heavy_check_mark:|
|Registration of SLE 11 systems|:heavy_check_mark:|:x:|
|Migration support SLE 12 > 15|:heavy_check_mark:|:heavy_check_mark:|
|Staging repositories|:heavy_check_mark:|:x:<sup>[1](#staging)</sup>|
|Air gap sync/mirroring for secure environments|:heavy_check_mark:|:heavy_check_mark:|
|NTLM Proxy support|:heavy_check_mark:|:heavy_check_mark:|
|Custom repositories|:heavy_check_mark:|:heavy_check_mark:|
|YaST installation wizard|:heavy_check_mark:|:heavy_check_mark:|
|YaST management wizard|:heavy_check_mark:|:x:|
|Client management|:heavy_check_mark:|:x:|
|Red Hat 7 and earlier support ([Expanded Support](https://www.suse.com/products/expandedsupport/))|:heavy_check_mark:|:x:|
|Red Hat 8 support ([Expanded Support](https://www.suse.com/products/expandedsupport/))|:heavy_check_mark:|:heavy_check_mark:||Files deduplication|:heavy_check_mark:|:heavy_check_mark:|
|Files deduplication|:heavy_check_mark:|:heavy_check_mark:|
|Data transfer from SMT to RMT|-|:heavy_check_mark:|
|Transfer registration data to SCC|:heavy_check_mark:|:x:<sup>[2](#regup)</sup>|
|Reporting|:heavy_check_mark:|:x:|
|Custom TLS certificates for web-server|:heavy_check_mark:|:heavy_check_mark:|
|Webserver|Apache2|Nginx|
|Database|MariaDB|MariaDB|
|Platform|Perl|Ruby|

<a name="staging">1</a>: Functionality is offered by [SUSE Manager](https://www.suse.com/documentation/suse-best-practices/susemanager/data/susemanager.html).
<a name="regup">2</a>: Registration data transfer to SCC is planned for SLES15 SP2.
