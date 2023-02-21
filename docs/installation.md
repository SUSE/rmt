# Installation of RMT

RMT is tested on SLES and openSUSE. We recommend installing RMT on either operating system, however, you always have the option to install it manually elsewhere.

**Notes:**

* You can find a recent openSUSE iso at https://www.opensuse.org/.
* You can get a trial SLES subscription at https://www.suse.com/trials/.

## Installation on Kubernetes with Helm

RMT comes with a helm-chart to easily install and configure on your kubernetes clusters. Save the following chart values

```bash
cat << EOF > helm_values.yml
---
app:
  scc:
    username: <your_proxy_username>
    password: <your_proxy_password>
    products_enable:
      - SLES/15.3/x86_64
      - sle-module-python2/15.3/x86_64
    products_disable:
      - sle-module-legacy/15.3/x86_64
      - sle-module-cap-tools/15.3/x86_64
ingress:
  enabled: true
  hosts:
    - host: your-rmt-example.local
      paths:
        - path: "/"
          pathType: Prefix
  tls:
  - secretName: rmt-cert
    hosts:
    - chart-example.local
EOF
```

and run

`helm install rmtsle oci://registry.suse.com/suse/rmt-helm -f helm_values.yml`

More information can be found [here](https://documentation.suse.com/sles/15-SP4/html/SLES-all/cha-rmt-installation.html#sec-rmt-deploy-kubernetes).

## Installation on SLE 15

1. If your server isn't activated yet, activate it with the command `SUSEConnect -r <regcode>`.
2. Activate the Server Applications Module for your version of SLE:
    * SLE 15 SP2 - `SUSEConnect -p sle-module-server-applications/15.2/x86_64`
    * SLE 15 SP1 - `SUSEConnect -p sle-module-server-applications/15.1/x86_64`
    * SLE 15 - `SUSEConnect -p sle-module-server-applications/15/x86_64`
3. Install RMT and its YaST installation wizard with the command `zypper in rmt-server yast2-rmt`.
4. Run the RMT installation wizard with the command `yast2 rmt` and configure your instance.

## Installation on openSUSE Leap 15

1. Install RMT and its YaST installation wizard with the command `zypper in rmt-server yast2-rmt`.
2. Run the RMT installation wizard with the command `yast2 rmt` and configure your instance.

## Manual installation and configuration

RMT currently gets built [in OBS](https://build.opensuse.org/package/show/systemsmanagement:SCC:RMT/rmt-server) for these distributions: `SLE_15`, `SLE_15_SP1`, `openSUSE_Leap_15.0`, `openSUSE_Leap_15.1`, `openSUSE_Tumbleweed`.
To add the repository, call: (replace `<dist>` with your distribution)

`zypper ar -f https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/<dist>/systemsmanagement:SCC:RMT.repo`

To install RMT, run: `zypper in rmt-server`

After installation configure your RMT instance:

* Prepare the database:
    * Start MySQL/MariaDB by running `systemctl start mysql`
    * Set database `root` user password by running `mysqladmin -u root password`
    * Make sure you can access to the database console as `root` user by running `mysql -u root -p`
    * Create a MySQL/MariaDB user with the following command:
    ```
    mysql -u root -p <<EOFF
    GRANT ALL PRIVILEGES ON \`rmt%\`.* TO rmt@localhost IDENTIFIED BY 'rmt';
    FLUSH PRIVILEGES;
    EOFF
    ```
* See [RMT Configuration Files](https://www.suse.com/documentation/sles-15/book_rmt/data/sec_rmt_config.html)
  in the official RMT documentation for information about `/etc/rmt.conf`.
* Start RMT by running `systemctl start rmt-server`. This will start the RMT server at http://localhost:4224.
* By default, mirrored repositories are saved under `/usr/share/rmt/public`, which is a symlink that points to
`/var/lib/rmt/public`. In order to change destination directory, recreate `/usr/share/rmt/public` symlink to point to the
desired location.
