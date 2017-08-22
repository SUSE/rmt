# Repository Mirroring Tool
![Kartoha](https://travis-ci.org/SUSE/rmt.svg?branch=master)

This tool allows you to mirror RPM repositories in your own private network. Registered organization credentials are required to mirror SUSE Enterprise Linux repositories.

You can run the application locally using the docker-compose:

```bash
docker-compose up
```

And it will be accessible at http://localhost:8080/ .

## Configuration

Available configuration options can be found in `config/rmt.yml` file.

- `mirroring.base_dir` - a directory where repos' files will be stored. Should be under HTTP server public root directory.
- `mirroring.mirror_url_prefix` - subpath to access repos's files for HTTP server.
- `mirroring.mirror_src` - whether to mirror `scr` and `debug` repos or not.
- `http_client` - proxy settings for RMT's HTTP connection for syncing.
- `scc` - your organization credentials for SUSE Enterprise Linux repos mirroring.

## Dependencies

The application is tested only on ruby 2.4.1 and newer. Support of older MRI is not intended.
