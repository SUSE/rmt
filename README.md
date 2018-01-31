# Repository Mirroring Tool
[![Build Status](https://travis-ci.org/SUSE/rmt.svg?branch=master)](https://travis-ci.org/SUSE/rmt)
[![Dependency Status](https://gemnasium.com/SUSE/rmt.svg)](https://gemnasium.com/SUSE/rmt)
[![Code Climate](https://codeclimate.com/github/SUSE/rmt.png)](https://codeclimate.com/github/SUSE/rmt)
[![Coverage Status](https://coveralls.io/repos/SUSE/rmt/badge.svg?branch=master&service=github)](https://coveralls.io/github/SUSE/rmt?branch=master)

This tool allows you to mirror RPM repositories in your own private network.
Organization (mirroring) credentials are required to mirror SUSE repositories.

## Installation and configuration

RMT currently gets built for these distributions: `SLE_15`, `SLE_12_SP2`, `SLE_12_SP3`, `openSUSE_Leap_42.2`, `openSUSE_Leap_42.3`, `openSUSE_Tumbleweed`.
To add the repository, call: (replace `<dist>` with your distribution)

`zypper ar -f https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/<dist>/systemsmanagement:SCC:RMT.repo`

Note that on SLES 12 and openSUSE Leap 42.2 you will need to add another repository which provides ruby 2.4, like:
`https://download.opensuse.org/repositories/OBS:/Server:/Unstable/SLE_12_SP3/OBS:Server:Unstable.repo`

To install RMT, run: `zypper in rmt-server`

After installation configure your RMT instance:

* You can create a MySQL/MariaDB user with the following command:
```
mysql -u root -p <<EOFF
GRANT ALL PRIVILEGES ON \`rmt\`.* TO rmt@localhost IDENTIFIED BY 'rmt';
FLUSH PRIVILEGES;
EOFF
```
* See the "Configuration" section for how to configure the options in `/etc/rmt.conf`.
* Start RMT by running `systemctl start rmt`. This will start the RMT server at http://localhost:4224.
* By default, mirrored repositories are saved under `/usr/share/rmt/public`, which is a symlink that points to
`/var/lib/rmt/public`. In order to change destination directory, recreate `/usr/share/rmt/public` symlink to point to the
desired location.

## Usage

### SUSE products

* Run `rmt-cli sync` to download available products and repositories data for your organization from SCC
* Run `rmt-cli products --all` to see the list of products that are available for your organization
* Run `rmt-cli repos --all` to see the list of all repositories available
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
* Run `rmt-cli repos custom attachments ID` to list the products attached to a custom repository.
* Run `rmt-cli repos custom attach ID PRODUCT_ID` to attach an existing custom repository to a product.
* Run `rmt-cli repos custom detach ID PRODUCT_ID` to detach an existing custom repository from a product.

### Offline Mode

RMT supports disconnected setups, similar to [how SMT does](https://www.suse.com/documentation/sles-12/book_smt/data/smt_disconnected.html).

The supported scenarios are shown in the table below:

| Online | Offline      |
|--------|--------------|
| SMT    | SMT          |
| SMT    | SUSE Manager |
| RMT    | RMT          |
| RMT    | SUSE Manager |

Connecting an SMT with an RMT this way is not supported.

#### Inital Setup

##### On the Online RMT

- `rmt-cli export scc-data /mnt/usb` will get the required JSON responses from SCC and save them as files at the specified path.

##### On the Offline RMT

- `rmt-cli import scc-data /mnt/usb` will read the JSON-files from given path and fill the local database.
- Now use `rmt-cli repos enable` or `rmt-cli products enable` to mark repos for mirroring.
- `rmt-cli export settings /mnt/usb` saves your settings at given path as `repos.json`.

#### Regular workflow

##### On the Online RMT

- `rmt-cli export repos /mnt/usb` will look for the `repos.json` at given path and mirror these repos directly to that path.

##### On the Offline RMT

- `rmt-cli import repos /mnt/usb` will mirror all repos which are enabled in the database, from the given path.


### openSUSE and other RPM based products

To mirror repositories that are not delivered via SCC, you can run for example:

`rmt-cli mirror custom https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/openSUSE_Leap_42.3/ foo/bar`

This will mirror the repository content to `public/repo/foo/bar` and make it available at http://hostname:4224/repo/foo/bar.

## Configuration

Available configuration options can be found in the `etc/rmt.conf` file.

### Mirroring settings

- `mirroring.mirror_src` - whether to mirror source (arch = `src`) repos or not.

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

## Dependencies

Supported Ruby versions are 2.4.1 and newer.

## Development setup

* Install the dependencies by running `bundle install`
* Copy the file `config/rmt.yml` to `config/rmt.local.yml` to override the default settings:
    * Add your organization credentials to `scc` section
    * Add your MySQL credentials

* Setup MySQL/MariaDB:

* Grant the just configured database user access to your database. The following command will grant access to the default user `rmt` with password `rmt` (run it as root):

```
mysql -u root <<EOFF
GRANT ALL PRIVILEGES ON \`rmt%\`.* TO rmt@localhost IDENTIFIED BY 'rmt';
FLUSH PRIVILEGES;
EOFF
```
* Create databases by running `rails db:create db:migrate`
* Run `rails server` to run the web-server

### Packaging

The package is built in the OBS at: https://build.opensuse.org/package/show/systemsmanagement:SCC:RMT/rmt-server

1. Checkout/update OBS working copy:
      * If the OBS project is not checked out, check out working copy of OBS project into a separate directory, e.g.:
          ```
          mkdir ~/obs
          cd ~/obs
          osc co systemsmanagement:SCC:RMT rmt-server
          ```
      * Alternatively, if OBS working copy is already checked out, update the working copy by running `osc up`
2. In Git working directory, run `make dist` to build a tarball;
3. Copy files from `package` directory to OBS working directory;
4. Build the package with updated sources, call `make dist` and then build for your distribution by running:

    `osc build <repository> <arch> --no-verify`

    The list of all build targets and architectures that configured for the project can be obtained by running `osc repos`.

5. Examine the changes by running `osc status` and `osc diff`;
6. Stage the changes by running `osc addremove`;
7. Commit the changes into OBS by running `osc ci`.

### Running with docker-compose

In order to run the application locally using docker-compose:

1. Copy `.env.example` file to `.env`;
2. Add your organization credentials to `.env` file. Mirroring credentials can be obtained from the [SUSE Customer Center](https://scc.suse.com/organization);
3. Start the containers by running `docker-compose up`. Running `docker-compose up -d` will start the containers in the background;
4. Execute commands in the container, e.g.:
    ```bash
    docker-compose exec rmt rmt-cli repos --help
    ```
    Alternatively, running `docker-compose exec rmt bash` will start the shell inside the container.
5. The web server will be accessible at [http://localhost:8080/](http://localhost:8080/), this URL can be used for registering clients.
