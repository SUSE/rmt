## Testing public cloud PAYG client registrations locally

Start RMT with pubcloud engines enabled:

```
bin/rmt-cli products enable sles/15.6/x86_64
bin/rmt-cli mirror product 2609,2626,2683,2618 # mirror SLE 15.6
RMT_LOAD_ENGINES=1 bin/rails s -b 0.0.0.0
```

Run client container:

`docker run --rm -ti --privileged --network=host registry.suse.com/suse/sle15:15.6 /bin/bash`

In the container prepare the needed packages:

```bash
zypper rm -y container-suseconnect
zypper in -y suseconnect vim less curl
zypper in -y http://updates.suse.de/SUSE/Products/SLE-Module-Public-Cloud/15-SP6/x86_64/product/noarch/cloud-regionsrv-client-10.1.7-150000.6.108.1.noarch.rpm

mv /etc/zypp/repos.d/* /tmp/ # move out BCI repos
```

Patch the `susecloud` zypp resolver to point to the local RMT without relying on a region server. Replace the RESOLVEURL in `/usr/lib/zypp/plugins/urlresolver/susecloud`:

```
def RESOLVEURL(self, headers, body):
    repo_url = 'http://172.17.0.1:4224' + headers.get('path')
    repo_credentials = headers.get('credentials')
    repo_url += '?credentials=' + repo_credentials
    self.answer(
        'RESOLVEDURL',
        {'X-Instance-Data': ''},
        repo_url
    )
```

Create a test instance_data file: `echo "<instance_data/>" > /tmp/idata.xml`

Register client in PAYG mode:

`suseconnect --url http://172.17.0.1:4224 --instance-data /tmp/idata.xml`


## Testing public cloud BYOS registrations


Register the client base product by providing a valid registration code:

`suseconnect --url http://172.17.0.1:4224 -r <regcode> --instance-data /tmp/idata.xml`


## Testing public cloud HYBRID registrations


Mirror a non-free extension in RMT:

```
bin/rmt-cli products enable sle-module-live-patching/15.6/x86_64
bin/rmt-cli mirror product 2664 # mirror SLE 15.6
```

Register the client base product with PAYG, then the extension with BYOS:

```
suseconnect --url http://172.17.0.1:4224 --instance-data /tmp/idata.xml
suseconnect --url http://172.17.0.1:4224 -r <regcode> -p sle-module-live-patching/15.6/x86_64 --instance-data /tmp/idata.xml`
```


## Notes

* `/usr/lib/zypp/plugins/urlresolver/susecloud` (https://github.com/SUSE-Enceladus/cloud-regionsrv-client) gets the url of the region RMT server and replaces it in the 'susecloud' type zypper services.
* `registercloudguest` logs to /var/log/cloudregister
* Full pubcloud test env: https://confluence.suse.com/pages/viewpage.action?spaceKey=publiccloud&title=Setup+Public+Cloud+Development+Environment
