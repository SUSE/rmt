## RMT CI setup

Our CI setup runs the following steps:

### Lint and unit tests

workflow definition: [.github/workflows/lint-unit.yml](../.github/workflows/lint-unit.yml)

This workflow runs rubocop to check if the source is well formated and afterwards unit tests and engine unit tests. At last it checks
if version in RMT and the rpm spec file matches.

**Running it locally**

There is no special mechanism needed to run these steps locally. Check the workflow for hints how to run unit tests

### CLI feature tests

workflow definition: [.github/workflows/features.yml](../.github/workflows/features.yml)

This workflow runs our simple CLI feature tests und build the rpm beforehand to see the system working with an installed RMT rpm.

**Running it locally**

To run feature tests locally, you need:

- A checkout of RMT
- A running mysql database
- Proxy credentials to synchronize product information with SCC

```
# Fetch the CI container
$ export IMAGE="registry.opensuse.org/systemsmanagement/scc/containers/opensuse_tumbleweed/rmt-ci-container-ruby3.4:latest"

# Build RMT rpms with the CI container the resulting rpms are in tmp/artifacts/
$ docker run --rm -it -v $(pwd):/usr/src/rmt-server $IMAGE 'ci/rmt-build-rpm'

# Run feature tests in the CI container
# Note: Running --network=host isn't stricly required if you setup mysql access otherwise
$ docker run --rm -it -v $(pwd):/usr/src/rmt-server --network=host $IMAGE bash -c 'ci/rmt-build-rpm && ci/rmt-configure && ci/rmt-run-feature-tests'
```

### systemd based Feature Tests

workflow definition: [.github/workflows/systemd-features.yml](../.github/workflows/systemd-features.yml)

This workflow runs feature tests inside a systemd-enabled container.
Two distro variants are tested via a matrix: openSUSE Tumbleweed (Ruby 4.0)
and SLE 16.0 (Ruby 3.4).

To facilitate this it builds the RMT rpms and then installs them, which
should pull in any dependencies such as MariaDB. Further systemd is used,
where possible, to manage the full service lifecycle (MariaDB → RMT
migration → RMT server) allowing this test workflow to simulate a real
production deployment path.

**Running it locally via Makefile**

```bash
# ensure the .env file is setup appropriately
$ if [[ ! -e .env ]]; then cp .env.example .env; ${EDITOR:-vi} .env; fi

# Full pipeline (default: SLE 16.0)
$ make ci-all

# Full pipeline for openSUSE Tumbleweed
$ make ci-all CI_DISTRO=tumbleweed

# Step-by-step (for debugging, default SLE 16.0)
$ make ci-env-check      # Confirms that CI required environment variables are set
$ make ci-build          # Build the CI Docker image
$ make ci-up             # Start the systemd container
$ make ci-wait           # Wait for systemd to be fully initialized
$ make ci-start-mariadb  # Initialize and start MariaDB (depends on ci-wait)
$ make ci-setup-database # Create the RMT database user
$ make ci-build-rpms     # Install Ruby deps, build RPMs, validate packaging
$ make ci-install-rpms   # Install RPMs, create config, set up database
$ make ci-tests          # Run feature tests
$ make ci-down           # Stop and remove the container
$ make ci-shell          # Open interactive shell in the container
$ make ci-logs           # Follow container logs
$ make ci-status         # Show container status

# Step-by-step for openSUSE Tumbleweed
$ make ci-all CI_DISTRO=tumbleweed
```

### The CI container

Our CI container is built here: https://build.opensuse.org/package/show/systemsmanagement:SCC:containers/rmt-ci-container

On push to Github main the rebuild of the container is triggered
