# Repository Mirroring Tool
![Kartoha](https://travis-ci.org/SUSE/rmt.svg?branch=master)

This tool allows you to mirror RPM repositories in your own private network. Registered organization credentials are required to mirror SUSE Enterprise Linux repositories.

You can run the application locally using the docker-compose:

```bash
docker-compose up
```

And it will be accessible at http://localhost:8080/ .

## Usage

### SLE products

1. Run `rmt-scc sync` to download available products and repositories data from SCC
2. Use `rmt-repos` command to choose which repositories to mirror, for example:
    ```
    rmt-repos enable SLES/12.2/x86_64
    ```
    The above command would enable mandatory SLES 12 SP2 repositories.
3. Run `rmt-mirror` to download selected repositories
4. Register client against RMT by running `SUSEConnect --url https://rmt_hostname`
    After successful registration repositories from RMT will be added to `zypper` on the client machine. 

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

A file `SUSE/Updates/SLE-SERVER/12/x86_64/update/x86_64/package-42.0.x86_64.rpm` would be stored at:

```
/var/rmt/mirrored_repos/SUSE/Updates/SLE-SERVER/12/x86_64/update/x86_64/package-42.0.x86_64.rpm
^^^^^^^^^^^^^^^^^^^^^^^^
        base_dir
```

And accessible at the following URL:

```
http://hostname/my_rmt_mirror/SUSE/Updates/SLE-SERVER/12/x86_64/update/x86_64/package-42.0.x86_64.rpm
               ^^^^^^^^^^^^^^^
              mirror_url_prefix
```

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

##### SCC settings for accessing SLES repositories

`scc` section contains your organization credentials for mirroring SUSE Enterprise Linux repositories.
Organization credentials can be obtained at [SUSE Customer Center](https://scc.suse.com). 

## Dependencies

Supported Ruby versions are 2.4.1 and newer.

## Deployment for development

1. Install PostgreSQL
2. Create a user for RMT to use
3. Configure DB settings in `config/database.yml`
4. Install the dependencies by running `bundle install`
5. Create databases by running `rails db:create`
6. Migrate DB schema by running `rails db:migrate` 
7. Run `rails server` to run the web-server
