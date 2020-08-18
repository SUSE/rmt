# Repository Mirroring Tool
[![Build Status](https://travis-ci.org/SUSE/rmt.svg?branch=master)](https://travis-ci.org/SUSE/rmt)
[![Code Climate](https://codeclimate.com/github/SUSE/rmt.png)](https://codeclimate.com/github/SUSE/rmt)
[![Coverage Status](https://coveralls.io/repos/SUSE/rmt/badge.svg?branch=master&service=github)](https://coveralls.io/github/SUSE/rmt?branch=master)

This tool allows you to mirror RPM repositories in your own private network.
Organization (mirroring) credentials are required to mirror SUSE repositories.

The [SLE RMT Book](https://documentation.suse.com/sles/15-SP2/html/SLES-all/book-rmt.html) contains the end-user documentation for RMT. `man` pages for `rmt-cli` are located in the file [MANUAL.md](MANUAL.md).

If you would like to contribute to RMT, please see our [contribution guide](docs/CONTRIBUTING.md).

If you would like to compare RMT to its predecessor SMT, please see our [writeup](docs/smt_and_rmt.md).

## Dependencies

Supported Ruby versions are 2.5.0 and newer.

## Installation of RMT

Please view our [guide](docs/installation.md) to assist you in the RMT installation process.

## Development Setup

* Install the dependencies:
    * `sudo zypper in libxml2-devel libxslt-devel libmariadb-devel`
    * `bundle install`
* Setup MySQL/MariaDB. The following command creates a user rmt with the password rmt and grants it access to any database starting with word `rmt`:
    ```
    mysql -u root -p <<EOFF
    GRANT ALL PRIVILEGES ON \`rmt%\`.* TO rmt@localhost IDENTIFIED BY 'rmt';
    FLUSH PRIVILEGES;
    EOFF
    ```
* Copy the file `config/rmt.yml` to `config/rmt.local.yml`. With this file, override the following default settings:
    * Add your organization credentials to `scc` section.
    * Add your MySQL credentials to the database section.
* Create the development database by running the command `rails db:create db:migrate`.
* Run the command `rails server` to start the web server.

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

## API documentation

RMT partially implements the [SUSE Customer Center API](https://scc.suse.com/connect/v4/documentation). You can read the details of each endpoint to find out whether they are supported by RMT.

## Feedback

Do you have suggestions for improvement? Let us know!

Go to [Issues](https://github.com/SUSE/rmt/issues/new), create a new issue and describe what you think could be improved.

Feedback is always welcome!

## Security Policy

Please see our [security policy](docs/SECURITY.md) for more information.
