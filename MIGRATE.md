# SMT to RMT Transition Helper Scripts

RMT is a successor to SMT, but it's a new product and doesn't automatically migrate from SMT. The RMT team
created these scripts to help ease the transition, enabling users to start their RMT experience by transferring some of
their SMT data to RMT.

**Notes:**

* We recommend that you install RMT on a new server. RMT is not a complete replacement for SMT. It has a different
workflow from SMT and also only supports SLE 12 and above. However, nothing stops you from using the same server.

## Caveats

* Staged repositories settings will not be exported
* Disabled custom repositories settings will not be exported
* Products no longer available on the organization subscriptions will not be available
* SMT client jobs will not be exported
* Client patch status data will not be exported

## Exporting SMT Data

The goal of this script is to store all the data that RMT could find useful in a tarball that you can bring to your
RMT server.

What will be exported to RMT:

* SSL certificates (optional)
* Repositories that have been marked to be mirrored
* Custom repositories
* Systems and their product activations

**Notes:**

* If you do choose to export your SSL certificate, please keep it safe.

1. Update your SMT server installation. `smt-data-export` is available in SMT versions >= 3.0.34 on SLE 12 and SMT versions >= 2.0.34 on SLE 11.

2. Run the smt-data-export script:
    a) If you want to export the SSL certificates from SMT:
    ```bash
    smt-data-export
    ```
    b) If you don't want to export the SSL certificates from SMT:
    ```bash
    smt-data-export --no-ssl-export
    ```
4. If all went well, the command should output where the tarball has been stored (e.g. `The exported configuration has
been saved to smt-export.xxxxxx.tar.gz`). Move that file to the RMT
server or note its path if the same server will be used.

## Importing SMT data to RMT

1. Make sure your rmt installation is up-to-date. `rmt-data-import` is available in RMT versions >= 1.0.0.
2. Unpack the tarball containing SMT data to some directory, e.g. `/root/smt-data`.
3. If you chose to export SMT's SSL certificates, copy the SMT CA private key and certificate to `/etc/rmt/ssl/`:
    ```
    cp /root/smt-data/ssl/cacert.key /etc/rmt/ssl/rmt-ca.key
    cp /root/smt-data/ssl/cacert.pem /etc/rmt/ssl/rmt-ca.crt
    ```
4. Run YaST RMT configuration module from YaST command center or by running `yast2 rmt` on the command line.
5. Proceed through the YaST module. If you want to support your old SMT hostname in your new SSL certificate, you can add it as an alternative common name on the SSL setup page.
6. Run `rmt-cli sync` to get the products and repositories data from SCC.
7. Run the `rmt-data-import` to import SMT data:
    ```
    rmt-data-import -d /root/smt-data/
    ```

After this in order for the client machines to consume data from RMT, it would be possible to:
1. Either change `url` parameter in `/etc/SUSEConnect` to point the client machines to RMT instead of SMT.
1. Or change the DNS records to the re-assign SMT's hostname to RMT server.


## Moving the mirrored repositories from SMT to RMT

1. Copy data from `/var/www/htdocs/repo` to `/var/lib/rmt/public/repo`:
    ```
    cp -r /var/www/htdocs/repo/* /var/lib/rmt/public/repo
    ```
2. Adjust owner/group of the files to `_rmt:nginx`:
    ```
    chown -R _rmt:nginx /var/lib/rmt/public/repo
    ```
