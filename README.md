# Repository Mirroring Tool
[![Build Status](https://travis-ci.org/SUSE/rmt.svg?branch=master)](https://travis-ci.org/SUSE/rmt)
[![Code Climate](https://codeclimate.com/github/SUSE/rmt.png)](https://codeclimate.com/github/SUSE/rmt)
[![Coverage Status](https://coveralls.io/repos/SUSE/rmt/badge.svg?branch=master&service=github)](https://coveralls.io/github/SUSE/rmt?branch=master)

This tool allows you to mirror RPM repositories in your own private network.
Organization (mirroring) credentials are required to mirror SUSE repositories.

The [SLE RMT Book](https://documentation.suse.com/sles/15-SP2/html/SLES-all/book-rmt.html) contains the end-user documentation for RMT. `man` pages for `rmt-cli` are located in the file [MANUAL.md](MANUAL.md).

If you would like to contribute to RMT, please see our [contribution guide](docs/CONTRIBUTING.md).

If you would like to compare RMT to its predecessor SMT, please see our [writeup](docs/smt_and_rmt.md).

## Installation of RMT

Please view our [guide](docs/installation.md) to assist you in the RMT installation process.

## Development Setup

1. Install the system dependencies:
    ```
    sudo zypper in libxml2-devel libxslt-devel libmariadb-devel gcc
    ```
2. Install the ruby version specified in the `.ruby-version` [file](.ruby-version).
3. Install and start either the MariaDB or MySQL server:
    ```
    sudo zypper in mariadb
    sudo systemctl enable mariadb
    sudo systemctl start mariadb
    ```
4. Log into the MariaDB or MySQL server as root and create the RMT database user:
    ```
    mysql -u root -p <<EOFF
    GRANT ALL PRIVILEGES ON \`rmt%\`.* TO rmt@localhost IDENTIFIED BY 'rmt';
    FLUSH PRIVILEGES;
    EOFF
    ```
5. Clone the RMT repository:
    ```
    git clone git@github.com:SUSE/rmt.git
    ```
6. Install the ruby dependencies:
    ```
    cd rmt
    bundle install
    ```
7. Copy the file `config/rmt.yml` to `config/rmt.local.yml`. With this file, override the following default settings:
    * Add your organization credentials to `scc` section.
    * Ensure that the `database` section is correct.
8. Create the directory `/var/lib/rmt` and ensure that your current user owns it.
    ```
    sudo mkdir /var/lib/rmt
    sudo chown -R $(id -u):$(id -g) /var/lib/rmt
    ```
9. Create the development database:
    ```
    bin/rails db:create db:migrate
    ```
10. Verify that RMT works:
    * Run the command `bin/rails server -b 0.0.0.0` to start the web server.
    * Run the command `bin/rmt-cli sync` to sync RMT with SCC.

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
