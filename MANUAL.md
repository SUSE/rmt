rmt-cli(8) -- control and configure your RMT server
===========================================================================

## DESCRIPTION

`rmt-cli` is the command line interface to control and configure a local RMT server.

RMT allows you to mirror RPM repositories in your own private network.
It also is a registration proxy for SUSE systems.


## PREREQUISITE

Before using `rmt-cli` for the first time, you have to finish the initial setup of your RMT server.
The recommended way to do this is the **RMT Yast module**.
You can install and run this wizard like this:

`zypper install yast2-rmt`

`yast2 rmt`


## USAGE

  * `rmt-cli sync`:
    RMT comes with a preconfigured systemd timer to automatically get the latest product and repository data from the SUSE Customer Center over night.
    This command triggers the same synchronization instantly.

  * `rmt-cli products list [--all] [--csv]`:
    Lists the products that are enabled for mirroring.

    Use the `--all` flag to list all available products.

    Use the `--csv` flag to output the list in CSV format.

  * `rmt-cli products enable <id | string>...`:
    Enable mirroring of product repositories by a list of product IDs or product strings.

    Use the `--all-modules` flag to enable all free modules for a product.

    Examples:

    `rmt-cli products enable SLES/15`

    `rmt-cli products enable 1575`

    `rmt-cli products enable SLES/15/x86_64 1743`

    `rmt-cli products enable --all-modules SLES/15`

  * `rmt-cli products disable <id | string>...`:
    Disable mirroring of product repositories by a list of product IDs or product strings.

    Examples:

    `rmt-cli products disable SLES/15`

    `rmt-cli products disable 1575`

    `rmt-cli products disable SLES/15/x86_64 1743`
  
  * `rmt-cli products show <id | string>`:
  	Displays product with all its repositories and their attributes.
  	
  	Examples:
  	
  	`rmt-cli products show SLES/15/x86_64`

  * `rmt-cli repos list [--all] [--csv]`:
    Lists the repositories that are enabled for mirroring.

    Use the `--all` flag to list all available repositories.

    Use the `--csv` flag to output the list in CSV format.

  * `rmt-cli repos enable <id>...`:
    Enable mirroring of repositories by a list of repository IDs

    Examples:

    `rmt-cli repos enable 2526`

    `rmt-cli repos enable 2526 3263`

  * `rmt-cli repos disable <id>...`:
    Disable mirroring of repositories by a list of repository IDs

    Examples:

    `rmt-cli repos disable 2526`

    `rmt-cli repos disable 2526 3263`

  * `rmt-cli mirror`:
    In its default configuration, RMT mirrors its enabled product repositories automatically once every night.
    This command starts this mirroring process manually. Changes made to repository mirroring settings while mirroring is in progress are respected by the mirroring process.

When all enabled repositories are fully mirrored, you can register your client systems against RMT by running `SUSEConnect --url https://<RMT hostname>` on the client machine.
After successful registration the repositories from RMT will be used by `zypper` on the client machine.


**Custom repositories**

  * `rmt-cli repos custom list [--csv]`:
    Lists all your custom repositories.

    Use the `--csv` flag to output the list in CSV format.

  * `rmt-cli repos custom add <url> <name>`:
    Adds a new custom repository, for example:

    `rmt-cli repos custom add https://download.opensuse.org/repositories/Virtualization:/containers/SLE_12_SP3/ Virtualization:Containers`

  * `rmt-cli repos custom enable <id>`:
    Enables mirroring for a custom repository.

  * `rmt-cli repos custom disable <id>`:
    Disables mirroring for a custom repository.

  * `rmt-cli repos custom remove <id>`:
    Removes a custom repository.

  * `rmt-cli repos custom products <id>`:
    Lists the products attached to the custom repository with given id.

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

As described in the [PREREQUISITE][] section, the recommended way to perform initial configuration of RMT is using its YaST module.
The YaST RMT module will take care of configuring SCC credentials, setting up the database and creating SSL certificates.
However, if you want to reconfigure specific settings manually, this section tells you how.

All available configuration options can be found in the `/etc/rmt.conf` file.

**SSL certificates & HTTPS**

By default access to API endpoints consumed by `SUSEConnect` is limited to HTTPS only.
nginx is configured to use SSL certificate and private key from the following locations:

- Certificate: `/etc/rmt/ssl/rmt-server.crt`
- Private key: `/etc/rmt/ssl/rmt-server.key`


YaST RMT module generates a custom certificate authority which is used to sign HTTPS certificates, which means that in order to register, this certificate authority must be trusted by the client machines:

- For registrations during installation from the media or with YaST Registration module, a message will appear, prompting to trust the server certificate.

- For registering a client system on the command line, use the `rmt-client-setup` script. It is provided at the following URL:
`http://<RMT hostname>/tools/rmt-client-setup`.

The script requires only the RMT server hostname as a mandatory parameter, e.g.:

`wget http://rmt.example.org/tools/rmt-client-setup`

`chmod +x ./rmt-client-setup`

`./rmt-client-setup http://rmt.example.org`

Executing this script will import the RMT CA's certificate into the trusted store and after that, run `SUSEConnect` to register the client with the RMT.

**Mirroring settings**

The `mirroring` section lets you adjust mirroring behavior.

  * `mirroring.mirror_src`:
    Whether to mirror source (arch = `src`) RPM packages or not.

**HTTP client settings**

The `http_client` section defines RMT's global HTTP connection settings.

  * `http_client.proxy_auth` setting:
    Determines proxy authentication mechanism, possible values are:
    `none`, `basic`, `digest`, `gssnegotiate`, `ntlm`, `digest_ie`, `ntlm_wb`

**Settings for accessing SUSE repositories**

The `scc` section contains your organization credentials for mirroring SUSE repositories from SUSE Customer Center.
Your organization credentials can be obtained from the [SUSE Customer Center](https://scc.suse.com/).


## FEEDBACK

Do you have suggestions for improvement? Let us know!
Go to *https://github.com/SUSE/rmt/issues/new* and create a new issue and describe what you think could be improved.
Feedback is always welcome!
