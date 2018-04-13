# SMT to RMT Transition Helper Scripts

RMT is a successor to SMT, but it's a new product and does not have an officially supported migration path. The RMT team
created these scripts to help ease the transition, enabling users to start their RMT experience by transferring some of
their SMT data to RMT.

**Notes:**

* These scripts are community supported only.
* We recommend that you install RMT on a new server. RMT is not a complete replacement for SMT. It has a different
workflow from SMT and also only supports SLE 12 and above. However, nothing stops you from using the same server.

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

## Importing Enabled Repositories from SMT to RMT

The following steps require a fully working RMT instance and a tarball of the SMT data from the section "Exporting SMT
Data".

1. Copy over the `rmt-import-repos` script to your running RMT server. The script is located at
https://github.com/SUSE/rmt/blob/master/contrib/smt-to-rmt-helpers/rmt-import-repos or you can download it directly with
the following command.
    ```bash
    wget https://raw.githubusercontent.com/SUSE/rmt/master/contrib/smt-to-rmt-helpers/rmt-import-repos
    ```
2.
    a) If you want to import all repositories including custom repositories:
    ```bash
    ./rmt-import-repos /path/to/smt-export.xxxx.tar.gz
    ```
    b) If you don't want to import custom repositories:
    ```bash
    ./rmt-import-repos --no-custom-repos /path/to/smt-export.xxxx.tar.gz
    ```
    c) If you only want to import custom repositories:
    ```bash
    ./rmt-import-repos --only-custom-repos /path/to/smt-export.xxxx.tar.gz
    ```
