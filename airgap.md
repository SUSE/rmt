# RMT Airgap

## Inital Setup

### On the Online RMT

- In the config, set airgap-offline to `false` (default) and set airgap-path to the location where the portable
  storage will be mounted.
- Mount the portable storage at this path.
- `rmt-cli sync airgap`
  In online mode, this will get the required JSON responses from SCC and save them as files at the specified airgap-path.
  In case the user has some sort of auto-mount and the path is dynamic, it can also be specified via the `--path` option. (Same for the offline part below)

### On the Offline RMT

- In the config, set airgap/offline to `true` and set airgap-path to the location where the portable storage will be mounted.
- Mount the portable storage at this path.
- `rmt-cli sync airgap`
  In offline mode, this will read the JSON-files from airgap-path and fill the local database.
- Now use `repos` or `products enable` to mark repos for mirroring.
- `rmt-cli repos dumpdb`
  Saves your settings on the portable storage as `repo_ids.json`.

  __Note:__ The name and place for this command is still a WIP to me. Any ideas?

## Regular workflow

### On the Online RMT

- Mount the portable storage at its path.
- `rmt-cli mirror airgap`
  In online mode, this will look for the `repo_id.json` at the airgap-path and mirror these repos directly to the portable storage.

### On the Offline RMT

- Mount the portable storage at its path.
- `rmt-cli mirror airgap`
  In offline mode, this will mirror all repos which are enabled in the database, from the portable storage.
