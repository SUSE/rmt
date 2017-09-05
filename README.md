# Repository Mirroring Tool
![Kartoha](https://travis-ci.org/SUSE/rmt.svg?branch=master)

This tool allows you to mirror RPM repositories in your own private network.
Organization (mirroring) credentials are required to mirror SUSE repositories.

## Usage

### SUSE products

* Run `rmt-scc sync` to download available products and repositories data for your organization from SCC
* Run `rmt-products list` to see the list of products that are available for your organization
* Use the `rmt-repos` command to choose which product repositories to mirror, for example:
  ```
  rmt-repos enable SLES/12.2/x86_64
  ```
  The above command would select the mandatory (`pool`, `updates`) SLES 12 SP2 repositories to be mirrored.
* Run `rmt-mirror` to mirror selected repositories and make their content available through RMT
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

* Setup PostgreSQL:

ensure that your local /var/lib/pgsql/data/pg_hba.conf looks like

```
local   all             all                                    peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
```

That is needed to allow glue user authenticate via md5 password. The file is created on first postgres start.
Allow the rmt user from `config/database.yml` to login to your postgresql server:

```
read -d '' DBS_QUERY <<EOFF
CREATE USER rmt WITH PASSWORD 'rmt';
ALTER ROLE glue with CREATEDB LOGIN;
EOFF
sudo -u postgres psql template1 -c "$DBS_QUERY"
```

* Install the dependencies by running `bundle install`
* Create databases by running `rails db:create db:migrate`
* Add your organization credentials to `config/rmt.yml`
* Run `rails server` to run the web-server


### With docker-compose

You can run the application locally using docker-compose:

```bash
docker-compose up
```

And it will be accessible at http://localhost:8080/ .

