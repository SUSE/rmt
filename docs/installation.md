# Installation of RMT v2.x

RMT v2.x releases are tested on the SLE 15 codestreams. We recommend installing RMT on an actively supported SLE 15 service pack, however, you always have the option to install it manually elsewhere.

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
      - SLES/15.7/x86_64
      - sle-module-desktop-applications/15.7/x86_64
    products_disable:
      - sle-module-legacy/15.7/x86_64
      - sle-we/15.7/x86_64
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

```bash
$ helm install rmtsle oci://registry.suse.com/suse/rmt-helm -f helm_values.yml
```

More information can be found [here](https://documentation.suse.com/sles/15-SP7/html/SLES-all/cha-rmt-installation.html#sec-rmt-deploy-kubernetes).

## Installation on SLE 15

1. If your server isn't activated yet, activate it with the command `SUSEConnect -r <regcode>`.
2. Activate the Server Applications Module for your version of SLE 15 if not already activated:
    * SLE 15 SP7 - `SUSEConnect -p sle-module-server-applications/15.7/x86_64`
    * SLE 15 SP6 - `SUSEConnect -p sle-module-server-applications/15.6/x86_64`
    * SLE 15 SP5 - `SUSEConnect -p sle-module-server-applications/15.5/x86_64`
    * SLE 15 SP4 - `SUSEConnect -p sle-module-server-applications/15.4/x86_64`
3. Install RMT and its YaST installation wizard with the command `zypper in rmt-server yast2-rmt`.
4. Run the RMT installation wizard with the command `yast2 rmt` and configure your instance.

## Manual installation and configuration

RMT currently gets built [in OBS](https://build.opensuse.org/package/show/systemsmanagement:SCC:RMT2/rmt-server) for these active distributions: `SLE_15_SP4`, `SLE_15_SP5`, `SLE_15_SP6`, `SLE_15_SP7`.
To add an appropriate zypper repository, run: (replace `<dist>` with your distribution)

```bash
$ zypper ar -f https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT2/<dist>/systemsmanagement:SCC:RMT2.repo
```

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
* See [RMT Configuration Files](https://documentation.suse.com/sles/15-SP7/html/SLES-all/cha-rmt-tools.html#sec-rmt-config)
  in the official RMT documentation for information about `/etc/rmt.conf`.
* Start RMT by running `systemctl start rmt-server`. This will start the RMT server at http://localhost:4224.
* By default, mirrored repositories are saved under `/usr/share/rmt/public`, which is a symlink that points to
`/var/lib/rmt/public`. In order to change destination directory, recreate `/usr/share/rmt/public` symlink to point to the
desired location.
