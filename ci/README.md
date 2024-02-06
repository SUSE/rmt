## RMT CI setup

Our CI setup runs the following steps:

### Lint and unit tests

workflow definition: [.github/workflows/lint-unit.yml](https://github.com/SUSE/rmt/blob/master/.github/workflows/lint-unit.yml)

This workflow runs rubocop to check if the source is well formated and afterwards unit tests and engine unit tests. At last it checks
if version in RMT and the rpm spec file matches.

**Running it locally**

There is no special mechanism needed to run these steps locally. Check the workflow for hints how to run unit tests

### CLI feature tests

workflow definition: [.github/workflows/features.yml](https://github.com/SUSE/rmt/blob/master/.github/workflows/features.yml)

This workflow runs our simple CLI feature tests und build the rpm beforehand to see the system working with an installed RMT rpm.

**Running it locally**

To run feature tests locally, you need:

- A checkout of RMT
- A running mysql database
- Proxy credentials to synchronize product information with SCC

```
# Fetch the CI container
$ export IMAGE="registry.opensuse.org/systemsmanagement/scc/containers/15.5/rmt-ci-container:latest"

# Build RMT rpms with the CI container the resulting rpms are in tmp/artifacts/
$ docker run --rm -it -v $(pwd):/usr/src/rmt-server $IMAGE 'ci/rmt-build-rpm'

# Run feature tests in the CI container
# Note: Running --network=host isn't stricly required if you setup mysql access otherwise
$ docker run --rm -it -v $(pwd):/usr/src/rmt-server --network=host $IMAGE bash -c 'ci/rmt-build-rpm && ci/rmt-configure && ci/rmt-run-feature-tests'
```

### The CI container

Our CI container is built here: https://build.opensuse.org/package/show/systemsmanagement:SCC:containers/rmt-ci-container

On push to Github master the rebuilt of the container is triggered
