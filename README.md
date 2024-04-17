# Repository Mirroring Tool
[![Integration tests](https://github.com/SUSE/rmt/actions/workflows/integrations.yml/badge.svg?branch=master)](https://github.com/SUSE/rmt/actions/workflows/integrations.yml)
[![Code Climate](https://codeclimate.com/github/SUSE/rmt.png)](https://codeclimate.com/github/SUSE/rmt)
[![Coverage Status](https://coveralls.io/repos/SUSE/rmt/badge.svg?branch=master&service=github)](https://coveralls.io/github/SUSE/rmt?branch=master)

This tool allows you to mirror RPM repositories in your own private network.
Organization (mirroring) credentials are required to mirror SUSE repositories.

The [SLE RMT Book](https://documentation.suse.com/sles/15-SP5/html/SLES-all/book-rmt.html) contains
the end-user documentation for RMT. `man` pages for `rmt-cli` are located in the file [MANUAL.md](MANUAL.md).

If you would like to contribute to RMT, please see our [contribution guide](docs/CONTRIBUTING.md).

If you would like to compare RMT to its predecessor SMT, please see our [writeup](docs/smt_and_rmt.md).

## Supported repository types and compressions:

RMT allows mirroring the following types of repositories:

```
  (rpm) repomd                  - fully supported
  (deb) debian flat structure   - experimental
  (deb) debian nested structure - experimental
```

Check [Debian Repository Format](https://wiki.debian.org/DebianRepository/Format) for more information
regarding Debian repository structure and [createrepo](http://createrepo.baseurl.org/) repository
for information about the repomd format.

Due to a huge possible variety of compression formats used in repositories. RMT does support the
following compression formats:

```
  (.gz)  GNU Gzip compression algorithm
  (.bz2) Burrows–Wheeler algorithm
  (.zst) Zstandard algorithm
```

If you encounter a repository with different compression and want support in RMT, please open
an [issue](https://github.com/SUSE/rmt/issues) and let the RMT development team know!

## Mirroring none SUSE repositories using RMT

RMT provides a mechanism to mirror custom repositories, named custom repositories.

```
$ rmt-cli repos custom add <URL> <identifier>

```

For `repomd` based repositories, the URL must lead to the top level directory of the repository (in which the `repodata` directory can be found)
**Example:**

```
$ rmt-cli repos custom add https://download.opensuse.org/tumbleweed/repo/oss/ tumbleweed
```

For `debian` based repositories, the URL must specify the release directory
**Example:**

```
$ rmt-cli repos custom add http://ftp.debian.org/debian/dists/sid/ debian-unstable
```

## Installation of RMT

Please view our [guide](docs/installation.md) to assist you in the RMT installation process.

## Development setup of RMT

Check out [development readme](DEVELOPMENT.md) for more information.

## Feedback

Do you have suggestions for improvement? Let us know!

Go to [Issues](https://github.com/SUSE/rmt/issues/new), create a new issue and describe what you think could be improved.

Feedback is always welcome!

## Security Policy

Please see our [security policy](docs/SECURITY.md) for more information.
