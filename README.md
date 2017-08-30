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



```
rmt -- Repository Mirroring Tool

Copyright (C) 2017, Ivan Kapelyukhin and contributors, SUSE Linux GmbH
See CONTRIBUTORS file for the list of contributors

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

SUSE Linux GmbH
Maxfeldstr. 5
D-90409 Nürnberg
Tel: +49 (0)911 740 53 - 0
Email: info@suse.com
Registrierung/Registration Number: HRB 21284 AG Nürnberg
Geschäftsführer/Managing Director: Jeff Hawn, Jennifer Guild, Felix Imendörffer
Steuernummer/Sales Tax ID: DE 192 167 791
Erfüllungsort/Legal Venue: Nürnberg
```
