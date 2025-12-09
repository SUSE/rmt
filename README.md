# Repository Mirroring Tool (RMT)

[![Integration tests](https://github.com/SUSE/rmt/actions/workflows/integrations.yml/badge.svg?branch=master)](https://github.com/SUSE/rmt/actions/workflows/integrations.yml)
[![Code Climate](https://codeclimate.com/github/SUSE/rmt.png)](https://codeclimate.com/github/SUSE/rmt)
[![Coverage Status](https://coveralls.io/repos/SUSE/rmt/badge.svg?branch=master&service=github)](https://coveralls.io/github/SUSE/rmt?branch=master)

## What is RMT?

**RMT** (Repository Mirroring Tool) allows you to mirror RPM repositories in your own private network. This gives you a centralized server for managing software updates for your client systems.
Organization (mirroring) credentials are required to mirror SUSE repositories.

## Key Benefits

- **Local Mirroring**: Keep local copies of SUSE and custom repositories.
- **Client Management**: Register and manage systems that get their updates from RMT.
- **SCC Integration**: Acts as a proxy for the SUSE Customer Center (SCC).
- **Offline Access**: Provide updates to systems in networks without internet access.
- **Bandwidth Savings**: Reduce internet usage by serving updates from a local source.
- **Centralized Updates**: Manage updates for all your SUSE systems from one place.

## Quick Start

### For Users
- **Documentation**: [SUSE Linux Enterprise RMT Guide](https://documentation.suse.com/sles/html/SLES-all/book-rmt.html)
- **CLI Manual**: See [MANUAL.md](MANUAL.md) for `rmt-cli` commands
- **Installation**: Follow our [installation guide](docs/installation.md)

### For Developers
- **Setup**: See [DEVELOPMENT.md](DEVELOPMENT.md) for development environment and testing
- **Contributing**: See our [contribution guide](docs/CONTRIBUTING.md)
- **Rails Guides**: [Rails Documentation](https://guides.rubyonrails.org/) for Rails concepts

## Architecture

RMT is a Ruby on Rails application with a few key components:

- **Web API Server**: A Rails application that serves REST endpoints for clients.
- **CLI Tool**: The `rmt-cli` command-line tool for system administration tasks.
- **Database**: A MySQL or MariaDB database for storing repository metadata and system information.
- **File Storage**: The local filesystem is used to store the mirrored repository files.
- **Rails Engines**: RMT's functionality is broken up into modular engines that can be extended.

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
  (.xz)  Tukaani LZMA algorithm
  (.bz2) Burrows–Wheeler algorithm
  (.zst) Zstandard algorithm
```

If you encounter a repository with different compression and want support in RMT, please open
an [issue](https://github.com/SUSE/rmt/issues) and let the RMT development team know!

## Mirroring non-SUSE repositories using RMT

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
