# Development Setup

## Overview

This guide will walk you through setting up a local environment. 
RMT is a Ruby on Rails application, so a basic understanding of Rails will be helpful.

What you'll need to get started:
- Ruby and Ruby on Rails 
- MySQL or MariaDB database.
- System dependencies.

## Setup

1. Install the system dependencies
    ```
    sudo zypper in libxml2-devel libxslt-devel libmariadb-devel sqlite3-devel gcc
    ```
2. Install the ruby version specified in the `.ruby-version` [file](.ruby-version).
    Check your version with:
    ```
    ruby --version
    ```
    If you need to install the required Ruby version, use your system's package manager or a Ruby version manager like rbenv.
    
3. Install and setup the database:

   **Default: MariaDB or MySQL server**
    ```
    sudo zypper in mariadb
    sudo systemctl enable mariadb
    sudo systemctl start mariadb
    ```
    Log into the MariaDB or MySQL server as root and create the RMT database user:
    ```
    mysql -u root -p <<EOFF
    GRANT ALL PRIVILEGES ON \`rmt%\`.* TO rmt@localhost IDENTIFIED BY 'rmt';
    FLUSH PRIVILEGES;
    EOFF
    ```

    **Experimental: SQLite**

    For development purposes it can be easier to run with SQLite, to avoid extra dependencies.
    To run RMT with SQLite, switch the database adapter in `config/rmt.yml` to `sqlite3`.

4. **Background jobs:** If you plan on implementing background jobs (via [Active Job](https://guides.rubyonrails.org/v6.1/active_job_basics.html)), you will need to install or utilize a service compatible with the Redis API. We recommend [Valkey](https://valkey.io/), a BSD-licensed server, which is packaged for (open)SUSE distributions:

    ```
    sudo zypper in valkey
    sudo systemctl enable --now valkey
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

### Development Setup - docker-compose

In order to run the application locally using docker-compose:

1. Copy the `.env.example` file to `.env`.
2. Add your organization credentials to `.env` file. Mirroring credentials can
   be obtained from the [SUSE Customer
   Center](https://scc.suse.com/organization). At this point you might also want
   to tweak the `EXTERNAL_PORT` environment variable from this file if you want
   to expose the main service with a port different than the default one.
3. Build the image (can be also used to update gems)
    ```
    make build
    ```
   Note that this will change the permissions on the `public` folder so anyone
   can access it (i.e. `chmod -R 0777 public`). This is needed so the docker
   container can write into this specific directory which is protected by default
   by the `rmt-cli` tool.
4. Run the server (Ctrl-C to terminate)
    ```
    make server
    ```
   The server will be started in the foreground and must be terminated to get
   back to the user's shell session.
   NOTE: If you want to interact with the RMT server, leave this running.
5. Shell access (Ctrl-D or `exit` to terminate)
    ```
    make shell
    ```
   This will start an interactive shell session within the `rmt` container that
   must be exited to return to the user's shell session.
   NOTE: You will need to run this in a separate user shell session (window) if
   you want to leave the RMT instance started by `make server` up and running.

After doing all this, there will be `http://localhost:${EXTERNAL_PORT}` exposed
to the network of the host, and you will be able to register clients by using
this url. At this point, though, notice that there are two ways to run clients
in a dockerized fashion as well.

First of all, you can run a client from a custom container (e.g. generated from
the `SUSE/connect` repository). With this in mind, be aware that you need to be
on the same network namespace as the host (or the `docker-compose` setup). You
can manage this with the `--network` flag of the `docker run` command. One easy
way to achieve this is to set the network as the one from the host: `docker run
--network=host <...>`. Moreover, notice that `dmidecode`, which is run by
`SUSEConnect`, will try to access some privileged devices (e.g. `/dev/mem`). By
default this will also fail, which is why some users simply pass the
`--privileged` flag to workaround this. This is certainly a solution, but it's
cleaner to simply add the needed capabilities and the needed devices. In
conclusion, for a clean run of a client, you could run the following command:

``` sh
$ docker run --rm --network=host --cap-add=sys_rawio --device /dev/mem:/dev/mem -ti <your-docker-image> /bin/bash
> SUSEConnect -r <regcode> --url http://localhost:${EXTERNAL_PORT}
```

Another option is to simply attach a new session into the running `rmt` service,
which already has the needed devices and capabilities. Thus, you could do
something like this:

``` sh
$ docker-compose exec rmt /bin/bash
> SUSEConnect -r <regcode> --url http://localhost:${EXTERNAL_PORT}
```

All in all, the code you might be working on sits as a volume inside of the
Docker container. Thus, you will be able to code as usual and the Docker
container will behave as if you were working entirely locally.

## Development Workflow

### Testing

RMT uses RSpec for testing. Run tests with:

``` sh
# All tests
bundle exec rspec

# Specific categories
bundle exec rspec spec/models/      # Models
bundle exec rspec spec/controllers/ # Controllers  
bundle exec rspec spec/lib/rmt/    # Libraries

# With coverage
bundle exec rspec --format progress
```

**Feature Tests with Act**: You can also run the feature tests from the GitHub Actions workflow locally using [Act](https://github.com/nektos/act).

``` sh
# 1. Install the GitHub CLI and log in
# https://cli.github.com/
gh auth login

# 2. Install the Act extension
gh extension install nektos/gh-act

# 3. Run the tests
act pull_request
```

**Coverage**: SimpleCov tracks coverage (target: 100%)  
**Database**: Tests use separate test database, automatically managed

### Development Commands
``` sh
# Start the development server
bundle exec rails server

# Run database migrations
bundle exec rails db:migrate

# Access Rails console
bundle exec rails console

# Generate new components
bundle exec rails generate model Product name:string
bundle exec rails generate controller Api::Products
```

### Key Development Files
- **`app/models/`**: Database models and business logic
- **`app/controllers/`**: API endpoints and request handling
- **`config/routes.rb`**: URL routing and API endpoints
- **`lib/rmt/`**: Core RMT functionality
- **`spec/`**: Test files (RSpec framework)

## API Documentation

RMT partially implements the [SUSE Customer Center API](https://scc.suse.com/connect/v4/documentation). You can read the details of each endpoint to find out whether they are supported by RMT.

## Troubleshooting

### Common Test Issues

**Database Connection Error**: Ensure MariaDB is running and `rmt` user exists  
**Gem Installation Error**: Install Ruby dev headers: `sudo zypper install ruby2.5-devel`  

### Getting Help

- **Rails Guides**: [Rails Documentation](https://guides.rubyonrails.org/)
- **RSpec**: [RSpec Documentation](https://rspec.info/)
- **Issues**: [GitHub Issues](https://github.com/SUSE/rmt/issues)
