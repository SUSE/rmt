rmt-cli(8) -- control and configure your RMT server
===========================================================================

## DESCRIPTION

`rmt-cli` is the command line interface to control and configure a local RMT server.

RMT allows you to mirror RPM repositories in your own private network.
It also is a registration proxy for SUSE systems.


## PREREQUISITE

Before you use `rmt-cli` for the first time, you must finish the initial setup of your RMT server.
On SUSE Linux Enterprise 16, you do the initial setup with the Ansible playbook from the `ansible-rmt-server` package.
The playbook installs MariaDB and nginx and creates the RMT database.
It also creates the SSL certificates, writes `/etc/rmt.conf` and starts the RMT services.

Do these steps as root on the RMT server:

  1. Install the playbook:

     `zypper install ansible-rmt-server`

  2. Open the file `/usr/share/ansible/rmt/group_vars/all.yml`.
     Set `RMT_ORGANIZATION_USERNAME` and `RMT_ORGANIZATION_PASSWORD` to your organization credentials.
     You get these credentials from the [SUSE Customer Center](https://scc.suse.com/).

  3. Run the playbook:

     `cd /usr/share/ansible/rmt`

     `ansible-playbook site.yml`

On SUSE Linux Enterprise 16, the `ansible` package contains the Ansible collections that the playbook needs.
On other systems, install the collections before you run the playbook:

`ansible-galaxy collection install -r requirements.yml`


## USAGE

All commands accept the `-d` (`--debug`) flag, which shows debug output.

  * `rmt-cli version`, `rmt-cli --version`:
    Shows the RMT version.

  * `rmt-cli sync`:
    RMT comes with a preconfigured systemd timer to automatically get the latest product and repository data from the SUSE Customer Center overnight.
    This command triggers the same synchronization instantly.

  * `rmt-cli systems list [--limit number] [--all] [--csv] [--proxy-byos-mode]`:
    Lists systems registered against RMT, with the most recent registration first.

    Use the `--limit number` flag to set how many systems the command shows. The default is 20.

    Use the `--all` flag to list all systems.

    Use the `--csv` flag to output the list in CSV format.

    Use the `--proxy-byos-mode` flag to list only BYOS systems that use RMT as a proxy.

  * `rmt-cli systems scc-sync`:
    Forwards local RMT systems to SCC.

  * `rmt-cli systems remove TARGET`:
    Removes a system and its activations from RMT.

    Example:

    `rmt-cli systems remove SCC_e740f34145b84523a184ace764d0d597`

  * `rmt-cli systems purge [--no-confirmation] [--before date] [--quiet]`:
    Removes inactive systems.
    By default, RMT removes the systems that did not contact RMT in the last 3 months.

    Use the `--no-confirmation` flag so the command does not ask you for
    confirmation.

    Use the `--before date` flag to set a different date. Systems that did not contact RMT after this date are inactive.
    The date format is `year-month-day`.

    Use the `--quiet` flag so the command does not show all the systems that
    match the inactive criteria before deletion.

    Example:

    `rmt-cli systems purge --no-confirmation --before 2022-02-28 --quiet`

  * `rmt-cli products list [--all] [--csv] [--release-stage stage] [--name name] [--version version] [--arch arch]`:
    Lists the products that are enabled for mirroring.

    Use the `--all` flag to list all available products.

    Use the `--csv` flag to output the list in CSV format.

    Use the `--release-stage stage` flag to list only products in this release stage. Possible values are `beta` and `released`.

    Use the `--name name` flag to list all products whose name matches `name`.

    Use the `--version version` flag to list all products whose version matches `version`.

    Use the `--arch arch` flag to list all products whose architecture matches `arch`.

  * `rmt-cli products enable <id | string>...`:
    Enable mirroring of product repositories by a list of product IDs or product strings.

    Use the `--all-modules` flag to enable all free modules for a product.

    Examples:

    `rmt-cli products enable SLES/16.0`

    `rmt-cli products enable 1575`

    `rmt-cli products enable SLES/16.0/x86_64 1743`

    `rmt-cli products enable --all-modules SLES/16.0`

  * `rmt-cli products disable <id | string>...`:
    Disable mirroring of product repositories by a list of product IDs or product strings.

    Examples:

    `rmt-cli products disable SLES/16.0`

    `rmt-cli products disable 1575`

    `rmt-cli products disable SLES/16.0/x86_64 1743`

  * `rmt-cli products show <id | string>`:
    Displays product with all its repositories and their attributes.

    Examples:

    `rmt-cli products show SLES/16.0/x86_64`

  * `rmt-cli clean packages [--dry-run] [--verbose] [--non-interactive]`:
    Removes locally mirrored dangling files and their database entries.
    The command reads the metadata of each repository that has a `repomd.xml` file.
    A *dangling* file agrees with both of these conditions:

      * The repository metadata does not list the file.
      * The file is at least 2 days old.

    Use the `--dry-run` flag to generate a report of all files without actually cleaning files or database entries.

    Use the `--verbose` flag to print detailed information of each cleaned file.

    Use the `--non-interactive` flag to skip confirmation before proceeding with the cleaning process.

  * `rmt-cli repos clean [--no-confirmation]`:
    Removes locally mirrored files of repositories which are not marked to be mirrored.

    Use the `--no-confirmation` flag to avoid user interaction and auto accept confirmation
    dialogs.

  * `rmt-cli repos list [--all] [--csv]`:
    Lists the repositories that are enabled for mirroring.

    Use the `--all` flag to list all available repositories.

    Use the `--csv` flag to output the list in CSV format.

  * `rmt-cli repos enable <id>...`:
    Enable mirroring of repositories by a list of repository IDs.

    Examples:

    `rmt-cli repos enable 2526`

    `rmt-cli repos enable 2526 3263`

  * `rmt-cli repos disable <id>...`:
    Disable mirroring of repositories by a list of repository IDs.

    Examples:

    `rmt-cli repos disable 2526`

    `rmt-cli repos disable 2526 3263`

  * `rmt-cli mirror [all]`:
    In its default configuration, RMT mirrors its enabled product repositories automatically once every night.
    This command starts this mirroring process manually. Changes made to repository mirroring settings while mirroring is in progress are respected by the mirroring process.

  * `rmt-cli mirror repository <id>...`:
    Mirrors only the enabled repositories with the given repository IDs.

    Example:

    `rmt-cli mirror repository 2526 3263`

  * `rmt-cli mirror product <id | string>...`:
    Mirrors only the enabled repositories of the given products.

    Example:

    `rmt-cli mirror product SLES/16.0/x86_64`

    All `mirror` commands accept the `--do-not-raise-unpublished` flag.
    With this flag, a product in the alpha or beta stage does not cause the command to fail.

When all enabled repositories are fully mirrored, you can register your client systems against RMT by running `SUSEConnect --url https://<RMT hostname>` on the client machine.
After successful registration the repositories from RMT will be used by `zypper` on the client machine.


**Custom repositories**

  * `rmt-cli repos custom list [--csv]`:
    Lists all your custom repositories.

    Use the `--csv` flag to output the list in CSV format.

  * `rmt-cli repos custom add <url> <name> [--id id]`:
    Adds a new custom repository.
    Use the `--id id` flag to set the ID of the repository. If you do not set it, RMT creates the ID from the name.

    Examples:

    `rmt-cli repos custom add https://download.opensuse.org/repositories/Virtualization:/containers/SLE_12_SP3/ Virtualization:Containers`

    `rmt-cli repos custom add https://download.opensuse.org/repositories/Virtualization:/containers/SLE_12_SP3/ Virtualization:Containers --id containers_sle_12_sp3`

  * `rmt-cli repos custom enable <id>...`:
    Enables mirroring for a list of custom repositories.

  * `rmt-cli repos custom disable <id>...`:
    Disables mirroring for a list of custom repositories.

  * `rmt-cli repos custom remove <id>`:
    Removes a custom repository.

  * `rmt-cli repos custom products <id> [--csv]`:
    Lists the products attached to the custom repository with given id.

    Use the `--csv` flag to output the list in CSV format.

  * `rmt-cli repos custom attach <id> <product id>`:
    Attaches an existing custom repository to a product.

  * `rmt-cli repos custom detach <id> <product id>`:
    Detaches an existing custom repository from a product.


**Offline mode**

RMT supports disconnected setups, in which an RMT does not need a connection to the internet, but takes all data and repository files from a portable storage device.
A similar functionality was available in SMT. However, connecting an SMT with an RMT this way is not supported.

The offline mode requires some initial setup steps:

  * `rmt-cli export data <path>`:
    Run this on an online RMT to get the latest data from SUSE Customer Center and save it as JSON files at the specified path.

  * `rmt-cli import data <path>`:
    Run this on the offline RMT to read the JSON files from given path and fill the local database with data.

You can now run the usual `rmt-cli repos enable <id>` or `rmt-cli products enable <id>` commands on the offline RMT to select the repositories you want to enable for mirroring here.

  * `rmt-cli export settings <path>`:
    Run this on the offline RMT to save the settings for enabled repositories at given path as `repos.json`.

After you have finished above setup steps, you can mirror repositories regularly to and from a portable storage device, which you first mount on the online, and later on the offline RMT to carry the files over:

  * `rmt-cli export repos <path>`:
    Run this regularly on the online RMT to mirror the set of repositories specified in the `repos.json` at given path.
    The mirrored repository files will be stored in subdirectories of the same path.

  * `rmt-cli import repos <path>`:
    Run this on the offline RMT to copy over all files of the enabled repositories from given path.


## CONFIGURATION

The RMT configuration is in the file `/etc/rmt.conf`.
The Ansible playbook from the [PREREQUISITE][] section writes this file from the variables in `/usr/share/ansible/rmt/group_vars/all.yml`.
The file `/usr/share/ansible/rmt/roles/rmt/defaults/main.yml` lists all variables and their default values.

To change a setting, set the variable in `group_vars/all.yml` and run `ansible-playbook site.yml` again.
If you edit `/etc/rmt.conf` directly, the next playbook run overwrites your changes.

After you change `/etc/rmt.conf`, restart RMT to load the new configuration:

`systemctl restart rmt-server`

**SSL certificates & HTTPS**

By default access to API endpoints consumed by `SUSEConnect` is limited to HTTPS only.
The playbook creates these files:

- Certificate: `/etc/rmt/ssl/rmt-server.crt`
- Private key: `/etc/rmt/ssl/rmt-server.key`
- CA certificate: `/etc/rmt/ssl/rmt-ca.crt`

The CA certificate signs the server certificate.
nginx uses the certificate and the private key for HTTPS.
nginx also makes the CA certificate available at `https://<RMT hostname>/rmt.crt`.
The server certificate is valid for the hostname, the fully qualified domain name and the main IPv4 address of the server.
To use other names, set the `rmt_ssl_subject_alt_names` variable in `group_vars/all.yml`, for example `["DNS:rmt.example.org", "IP:192.0.2.10"]`.
Client machines must trust the RMT certificate before they can register.

To register a client system on the command line, use the `rmt-client-setup` script.
RMT provides the script at `http://<RMT hostname>/tools/rmt-client-setup`.
The script downloads the certificate from `https://<RMT hostname>/rmt.crt` and imports it into the trusted store of the client.
Then it runs `SUSEConnect` to register the client with RMT.

The script needs only the hostname of the RMT server, for example:

`wget http://rmt.example.org/tools/rmt-client-setup`

`chmod +x ./rmt-client-setup`

`./rmt-client-setup --host rmt.example.org`

**Mirroring settings**

The `mirroring` section lets you adjust mirroring behavior.

  * `mirroring.mirror_drpm`:
    Whether to mirror delta (extension = `.drpm`) RPM packages or not. Defaults
    to `true` if absent.
  * `mirroring.mirror_src`:
    Whether to mirror source (arch = `src`) RPM packages or not. Defaults to `false`.
  * `mirroring.revalidate_repodata`:
    Whether to re-validate repodata content and packages when the repodata did not change. Defaults to `true` if absent.
  * `mirroring.dedup_method`:
    Whether to deduplicate files by a hardlink or copy. Possible values are:
    `hardlink`, `copy`. Defaults to `hardlink`.
  * `mirroring.redirect_repo_hosts`:
    List of hostnames from which repos will not get mirrored, but clients get redirected there.
    The playbook does not write this setting. To use it, add it to `/etc/rmt.conf` manually.
    If you run the playbook again, add the setting again.

**HTTP client settings**

The `http_client` section defines RMT's global HTTP connection settings.

  * `http_client.proxy`:
    The URL of the HTTP proxy server. If this setting is empty, RMT does not use a proxy.
  * `http_client.proxy_auth`:
    Determines proxy authentication mechanism, possible values are:
    `none`, `basic`, `digest`, `gssnegotiate`, `ntlm`, `digest_ie`.
    If this setting is empty, RMT lets the HTTP library select the mechanism.
  * `http_client.proxy_user`, `http_client.proxy_password`:
    The user name and the password for the proxy. If you set both, RMT uses them.
  * `http_client.verbose`:
    Whether to log details of each HTTP request. Defaults to `false`.
  * `http_client.low_speed_limit`, `http_client.low_speed_time`:
    If the speed stays below `low_speed_limit` bytes per second for `low_speed_time` seconds, RMT stops the download.
    The defaults are `512` and `120`.

**Logging**

In the `log_level` section you can configure the verbosity of RMT.

  * `rails` setting:
    Sets the log level of the RMT server, possible values are:
    `debug`, `info`, `warn`, `error`. Defaults to `info`.
  * `cli` setting:
    Sets the log level of the RMT cli, possible values are:
    `debug`, `info`. Defaults to `info`.
    Setting this to `debug` has the same effect as running `rmt-cli` with the `-d` switch.

**Web server settings**

The `web_server` section lets you tune the performance of your RMT server.

  * `web_server.min_threads` setting:
    Specifies the minimum threads count an RMT server worker should spawn.
    Acceptable values: Integer greater than or equal to 1.
  * `web_server.max_threads` setting:
    Specifies the maximum threads count an RMT server worker should spawn.
    Acceptable values: Integer greater than or equal to 1.
  * `web_server.workers` setting:
    Specifies the number of web workers for RMT.
    Acceptable values: Integer greater than or equal to 1.

**Settings for accessing SUSE repositories**

The `scc` section contains your organization credentials for mirroring SUSE repositories from SUSE Customer Center.
Your organization credentials can be obtained from the [SUSE Customer Center](https://scc.suse.com/).

  * `scc.sync_systems`:
    Whether the systemd timer forwards registered systems to SCC, like `rmt-cli systems scc-sync`. Defaults to `true`.


## FEEDBACK

Do you have suggestions for improvement? Let us know!
Go to *https://github.com/SUSE/rmt/issues/new* and create a new issue and describe what you think could be improved.
Feedback is always welcome!
