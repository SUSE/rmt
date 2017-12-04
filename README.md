# Repository Mirroring Tool
[![Build Status](https://travis-ci.org/SUSE/rmt.svg?branch=master)](https://travis-ci.org/SUSE/rmt)
[![Dependency Status](https://gemnasium.com/SUSE/rmt.svg)](https://gemnasium.com/SUSE/rmt)
[![Code Climate](https://codeclimate.com/github/SUSE/rmt.png)](https://codeclimate.com/github/SUSE/rmt)
[![Coverage Status](https://coveralls.io/repos/SUSE/rmt/badge.svg?branch=master&service=github)](https://coveralls.io/github/SUSE/rmt?branch=master)

This tool allows you to mirror RPM repositories in your own private network.
Organization (mirroring) credentials are required to mirror SUSE repositories.

## Installation and configuration

RMT currently gets built for these distributions: `SLE_12_SP2`, `SLE_12_SP3`, `openSUSE_Leap_42.2`, `openSUSE_Leap_42.3`, `openSUSE_Tumbleweed`.
To add the repository, call: (replace `<dist>` with your distribution)

`zypper ar -f https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/<dist>/systemsmanagement:SCC:RMT.repo`

Note that on SLES 12 and openSUSE Leap 42.2 you will need to add another repository which provides ruby 2.4, like:
`https://download.opensuse.org/repositories/OBS:/Server:/Unstable/SLE_12_SP3/OBS:Server:Unstable.repo`

To install RMT, run: `zypper in rmt`

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

* Run `rmt-cli scc sync` to download available products and repositories data for your organization from SCC
* Run `rmt-cli products list` to see the list of products that are available for your organization
* Run `rmt-cli repos list --all` to see the list of all repositories available
* Use the `rmt-cli repos enable` command to choose which product repositories to mirror, for example:
  ```
  rmt-cli repos enable SLES/12.2/x86_64
  ```
  The above command would select the mandatory (`pool`, `updates`) SLES 12 SP2 repositories to be mirrored.
  Alternatively, you can specify repository ID to choose individual repositories.
* Run `rmt-cli mirror` to mirror selected repositories and make their content available through RMT
* Register client against RMT by running `SUSEConnect --url https://rmt_hostname`
  After successful registration the repositories from RMT will be used by `zypper` on the client machine.

### Offline Mode

RMT supports disconnected setups, similiar to [how SMT does](https://www.suse.com/documentation/sles-12/book_smt/data/smt_disconnected.html). Follow these steps to set it up:

#### Inital Setup

##### On the Online RMT

- `rmt-cli export scc-data /mnt/usb` will get the required JSON responses from SCC and save them as files at the specified path.

##### On the Offline RMT

- `rmt-cli import scc-data /mnt/usb` will read the JSON-files from given path and fill the local database.
- Now use `repos enable` (or `products enable`) to mark repos for mirroring.
- `rmt-cli export settings` saves your settings at path as `repos.json`.

#### Regular workflow

##### On the Online RMT

- `rmt-cli export repos /mnt/usb` will look for the `repos.json` at given path and mirror these repos directly to that path.

##### On the Offline RMT

- `rmt-cli import repos` will mirror all repos which are enabled in the database, from the given path.


### openSUSE and other RPM based products

To mirror repositories that are not delivered via SCC, you can run for example:

`rmt-cli mirror https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/openSUSE_Leap_42.3/ foo/bar`

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

* Setup MySQL/MariaDB:

Allow the rmt user from `config/rmt.local.yml` to login to your MySQL/MariaDB server:

```
mysql -u root -p <<EOFF
GRANT ALL PRIVILEGES ON \`rmt%\`.* TO rmt@localhost IDENTIFIED BY 'rmt';
FLUSH PRIVILEGES;
EOFF
```

* Install the dependencies by running `bundle install`
* Create databases by running `rails db:create db:migrate`
* Override the default settings in `config/rmt.local.yml`:
    * Add your organization credentials to `scc` section
    * Modify database settings, i.e.:
    ```yaml
    database: &database
      host: localhost
      username: rmt
      password: rmt
      database: rmt_development
      adapter: mysql2
      encoding: utf8
      timeout: 5000
      pool: 5

    database_development:
      <<: *database
      database: rmt_development

    database_test:
      <<: *database
      database: rmt_test
    ```
* Run `rails server` to run the web-server

### Packaging

The package is build in the OBS at: https://build.opensuse.org/package/show/systemsmanagement:SCC:RMT/rmt
To initialize the package directory go to `package/` and run: `osc co systemsmanagement:SCC:RMT rmt -o .`

To build the package with updated sources, call `make dist` and then build for your distribution with:

`osc build <dist> x86_64 --no-verify` where <dist> can be one of: `SLE_12_SP2`, `SLE_12_SP3`, `openSUSE_Leap_42.2`, `openSUSE_Leap_42.3`, `openSUSE_Tumbleweed`

### With docker-compose

You can run the application locally using docker-compose:

```bash
docker-compose up
```

And it will be accessible at http://localhost:8080/ .
