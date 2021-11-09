# SccProxy
Engine to handle BYOS, that use RMT as an SCC proxy,
instances registration and activations


1. BYOS instance supplies registration code (regcode) during registration, if the regcode is valid
then, system is announced and product is registered against SCC.
2. BYOS instance, once registered, can activate products included in that subscription

in the BYOS instance, do

if `registercloudguest` is not installed:
```bash
SUSEConnect -r <regcode>
SUSEConnect -p Public Cloud Module
SUSEConnect -d
zypper in cloud-regionsrv-client
```
once installed, then
```
registercloudguest -r regcode
SUSEConnect -p <product>
SUSEConnect -d -p <other_product>
```
to de-register
```bash
registercloudguest --clean
```
