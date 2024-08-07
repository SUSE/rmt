
Start RMT with pubcloud engines enabled:

```
bin/rmt-cli products enable sles/15.6/x86_64
bin/rmt-cli mirror product 2609,2626,2683,2618 # mirror SLE 15.6
RMT_LOAD_ENGINES=1 bin/rails s -b 0.0.0.0
```

```bash
docker run --rm -ti --privileged registry.suse.com/suse/sle15:15.6 /bin/bash

$ zypper rm -y container-suseconnect
$ zypper in -y suseconnect
suseconnect --url http://172.17.0.1:4224
```
