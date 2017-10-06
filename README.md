# Repository Mirroring Tool
![Kartoha](https://travis-ci.org/SUSE/rmt.svg?branch=master)

This tool allows you to mirror RPM repositories in your own private network.
Organization (mirroring) credentials are required to mirror SUSE repositories.

## Installation

RMT currently gets build for these distributions: `SLE_12_SP2`, `SLE_12_SP3`, `openSUSE_Leap_42.2`, `openSUSE_Leap_42.3`, `openSUSE_Tumbleweed`.
To add the repository, please call: (replace `<dist>` with your distribution)

`zypper ar -f https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/<dist>/systemsmanagement:SCC:RMT.repo`

Please note that on SLES 12 and openSUSE Leap 42.2 you will need to add another repository which provides ruby 2.4, like:
`https://download.opensuse.org/repositories/OBS:/Server:/Unstable/SLE_12_SP3/OBS:Server:Unstable.repo`

To install rmt, please run: `zypper in rmt`

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

## Configuration

Available configuration options can be found in `config/rmt.yml` file.

##### Mirroring settings

- `mirroring.mirror_src` - whether to mirror source (arch = `src`) repos or not.
- `mirroring.base_dir` - a directory where mirrored files will be stored. HTTP server should be configured to serve files from this directory under `mirroring.mirror_url_prefix`.
- `mirroring.mirror_url_prefix` - URL path that will be used to access mirrored files on the HTTP server.

For example, for a given configuration values:
```
mirroring:
    mirror_url_prefix: /my_rmt_mirror/
    base_dir:  /var/rmt/mirrored_repos/
```

The file `SUSE/Updates/SLE-SERVER/12/x86_64/update/x86_64/package-42.0.x86_64.rpm` would be stored at:

`/var/rmt/mirrored_repos/SUSE/Updates/SLE-SERVER/12/x86_64/update/x86_64/package-42.0.x86_64.rpm`

And accessible at the following URL:

`http://hostname/my_rmt_mirror/SUSE/Updates/SLE-SERVER/12/x86_64/update/x86_64/package-42.0.x86_64.rpm`

##### HTTP client settings

`http_client` section defines RMT's global HTTP connection settings.

- `http_client.proxy_auth` setting determines proxy authentication mechanism, possible values are:
    * `none`
    * `basic`
    * `digest`
    * `gssnegotiate`
    * `ntlm`
    * `digest_ie`
    * `ntlm_wb`

##### SCC settings for accessing SUSE repositories

The `scc` section contains your organization credentials for mirroring SUSE repositories.
Your organization credentials can be obtained at [SUSE Customer Center](https://scc.suse.com).

## Dependencies

Supported Ruby versions are 2.4.1 and newer.

## Development setup

* Setup MySQL/MariaDB:

Allow the rmt user from `config/database.yml` to login to your MySQL/MariaDB server:

```
mysql -u root -p <<EOFF
GRANT ALL PRIVILEGES ON \`rmt\_%\`.* TO rmt@localhost identified by 'rmt';
FLUSH PRIVILEGES;
EOFF
```

* Install the dependencies by running `bundle install`
* Create databases by running `rails db:create db:migrate`
* Add your organization credentials to `config/rmt.yml`
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
