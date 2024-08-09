## Testing public could client registrations locally

Start RMT with pubcloud engines enabled:

```
bin/rmt-cli products enable sles/15.6/x86_64
bin/rmt-cli mirror product 2609,2626,2683,2618 # mirror SLE 15.6
RMT_LOAD_ENGINES=1 bin/rails s -b 0.0.0.0
```

Prepare the client:

```bash
docker run --rm -ti --privileged --network=host registry.suse.com/suse/sle15:15.6 /bin/bash

zypper rm -y container-suseconnect
zypper in -y suseconnect vim less curl
zypper in -y http://updates.suse.de/SUSE/Products/SLE-Module-Public-Cloud/15-SP6/x86_64/product/noarch/cloud-regionsrv-client-10.1.7-150000.6.108.1.noarch.rpm

mv /etc/zypp/repos.d/* /tmp/ # move out BCI repos

# Set regionsrv = 172.17.0.1:4224
#     httpsOnly = false
# in /etc/regionserverclnt.cfg

registercloudguest

```

Register client in PAYG mode, providing instance data:

```
$ suseconnect --url http://172.17.0.1:4224
```




Notes:

* `/usr/lib/zypp/plugins/urlresolver/susecloud` (https://github.com/SUSE-Enceladus/cloud-regionsrv-client) gets the url of the region RMT server and replaces it in the 'susecloud' type zypper services.
* `registercloudguest` logs to /var/log/cloudregister
* Full pubcloud test env: https://confluence.suse.com/pages/viewpage.action?spaceKey=publiccloud&title=Setup+Public+Cloud+Development+Environment
