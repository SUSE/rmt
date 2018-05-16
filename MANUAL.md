# Repository Mirroring Tool

This tool allows you to mirror RPM repositories in your own private network.
Organization (mirroring) credentials are required to mirror SUSE repositories.

## Usage

### SUSE products

* Run `rmt-cli sync` to download available products and repositories data for your organization from SCC
* Run `rmt-cli products list --all` to see the list of products that are available for your organization
* Run `rmt-cli repos list --all` to see the list of all repositories available
* Use the `rmt-cli products enable` command to choose which product repositories to mirror, for example:

  ```
  rmt-cli products enable SLES/12.2/x86_64
  ```

  The above command would select the mandatory (`pool`, `updates`) SLES 12 SP2 repositories to be mirrored.
  Alternatively, you can choose to mirror an individual repository with `rmt-cli repos enable REPO_ID`, for example:

  ```
  rmt-cli repos enable 2189
  ```

  The above command would enable mirroring for the SLES 12 SP3 Updates repository.
* Run `rmt-cli mirror` to mirror selected repositories and make their content available through RMT
* Register client against RMT by running `SUSEConnect --url https://rmt_hostname`
  After successful registration the repositories from RMT will be used by `zypper` on the client machine.

### Custom Repositories

* Run `rmt-cli repos custom add URL NAME` to add a new custom repository, for example:

  ```
  rmt-cli repos custom add https://download.opensuse.org/repositories/Virtualization:/containers/SLE_12_SP3/ Virtualization:Containers
  ```

* Run `rmt-cli repos custom list` to list all custom repositories.
* Run `rmt-cli repos custom enable ID` to enable mirroring for a custom repository.
* Run `rmt-cli repos custom disable ID` to disable mirroring for a custom repository.
* Run `rmt-cli repos custom remove ID` to remove a custom repository.
* Run `rmt-cli repos custom products ID` to list the products attached to a custom repository.
* Run `rmt-cli repos custom attach ID PRODUCT_ID` to attach an existing custom repository to a product.
* Run `rmt-cli repos custom detach ID PRODUCT_ID` to detach an existing custom repository from a product.

### Offline Mode

RMT supports disconnected setups, similar to how SMT did.
Connecting an SMT with an RMT this way is not supported.

#### Inital Setup

##### On the Online RMT

- `rmt-cli export data /mnt/usb` will get the required JSON responses from SCC and save them as files at the specified path.

##### On the Offline RMT

- `rmt-cli import data /mnt/usb` will read the JSON-files from given path and fill the local database.
- Now use `rmt-cli repos enable` or `rmt-cli products enable` to mark repos for mirroring.
- `rmt-cli export settings /mnt/usb` saves your settings at given path as `repos.json`.

#### Regular workflow

##### On the Online RMT

- `rmt-cli export repos /mnt/usb` will look for the `repos.json` at given path and mirror these repos directly to that path.

##### On the Offline RMT

- `rmt-cli import repos /mnt/usb` will mirror all repos which are enabled in the database, from the given path.

## Configuration

Available configuration options can be found in the `etc/rmt.conf` file.

The recommended way to perform initial configuration is using the [YaST RMT module](https://github.com/SUSE/yast2-rmt).
The YaST RMT module will take care of configuring SCC credentials, setting up the database and creating SSL certificates.

### SSL certificates & HTTPS

By default access to API endpoints consumed by SUSEConnect is limited to HTTPS only.
nginx is configured to use SSL certificate and private key from the following locations:

* Certificate: /usr/share/rmt/ssl/rmt-server.crt
* Private key: /usr/share/rmt/ssl/rmt-server.key

YaST RMT module generates a custom certificate authority which is used to sign HTTPS certificates, which means that in order to register, this certificate authority must be trusted by the client machines.

* When registration is performed during installation from the media or with YaST Registration module, a message will appear, prompting to trust the server certificate.

* `rmt-client-setup` script is provided for registering on the command line at the following URL: `http://rmt.hostname/tools/rmt-client-setup`.
The script requires only the RMT server hostname as a mandatory parameter, e.g.:

    ```bash
    ./rmt-client-setup https://rmt.hostname/
    ```

    Executing this script will import the RMT CA's certificate into the trusted store and after that run SUSEConnect to register the client with the RMT.

### Mirroring settings

- `mirroring.mirror_src` - whether to mirror source (arch = `src`) RPM packages or not.

### HTTP client settings

`http_client` section defines RMT's global HTTP connection settings.

- `http_client.proxy_auth` setting determines proxy authentication mechanism, possible values are:
    * `none`
    * `basic`
    * `digest`
    * `gssnegotiate`
    * `ntlm`
    * `digest_ie`
    * `ntlm_wb`

### SCC settings for accessing SUSE repositories

The `scc` section contains your organization credentials for mirroring SUSE repositories.
Your organization credentials can be obtained from the [SUSE Customer Center](https://scc.suse.com/organization).

## Feedback

Do you have suggestions for improvement? Let us know!

Go to [Issues](https://github.com/SUSE/rmt/issues/new), create a new issue and describe what you think could be improved.

Feedback is always welcome!
