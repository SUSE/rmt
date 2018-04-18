# SMT to RMT Transition Helper Scripts

RMT is a successor to SMT, but it's a new product and does not have an officially supported migration path. The RMT team
created these scripts to help ease the transition, enabling users to start their RMT experience by transferring some of
their SMT data to RMT.

**Notes:**

* These scripts are community supported only.
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
* Repositories that have been marked to be mirrored.
* Custom repositories.
* Systems and their product activations.

**Notes:**

* If you do choose to export your SSL certificate, please keep it safe.

1. Copy over the `smt-data-export` script to your SMT server. The script is located at
https://github.com/SUSE/rmt/blob/master/contrib/smt-to-rmt-helpers/smt-data-export or you can download it directly with
the following command.
    ```bash
    wget https://raw.githubusercontent.com/SUSE/rmt/master/contrib/smt-to-rmt-helpers/smt-data-export
    ```
2. Make the script executable:
    ```bash
    chmod +x smt-data-export
    ```
3.
    a) If you want to export the SSL certificates from SMT:
    ```bash
    ./smt-data-export
    ```
    b) If you don't want to export the SSL certificates from SMT:
    ```bash
    ./smt-data-export --no-ssl-export
    ```
4. If all went well, the command should output where the tarball has been stored (e.g. `The exported configuration has
been saved to smt-export.xxxxxx.tar.gz`). Move that file to the RMT
server or note its path if the same server will be used.

## Importing SMT data to RMT

1. Upload the tarball containing SMT data and `rmt-data-import` script to the RMT server
1. Unpack the tarball containing SMT data to some directory, e.g. `/root/smt-data`
1. Decrypt the SMT CA private key to `/usr/share/rmt/ssl/`:
    ```
    openssl rsa -in /root/smt-data/ssl/cacert.key -out /usr/share/rmt/ssl/rmt-ca.key
    ```
1. Copy the SMT CA certificate to `/usr/share/rmt/ssl/`:
    ```
    cp /root/smt-data/ssl/cacert.pem /usr/share/rmt/ssl/rmt-ca.crt
    ```
1. Run YaST RMT configuration module from YaST command center or by running `yast2 rmt` on the command line;
1. Go through setup steps of the YaST module. On the SSL setup page it is possible to add alternative common names (e.g., the hostname of the SMT server in case it is desirable to perform a switch) 
1. Run `rmt-cli sync` to get the products and repositories data from SCC;
1. Run the `rmt-data-import` to import SMT data:
    ```
    ./rmt-data-import /root/smt-data-export/
    ```

After this in order for the client machines to consume data from RMT, it would be possible to:
1. Either change `url` parameter in `/etc/SUSEConnect` to point the client machines to RMT instead of SMT;
1. Or change the DNS records to the re-assign SMT's hostname to RMT server.
