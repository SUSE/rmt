# RMT Airgap

## Inital Setup

### On the Online RMT

- `rmt-cli export scc-data /mnt/usb` will get the required JSON responses from SCC and save them as files at the specified path.

### On the Offline RMT

- `rmt-cli import scc-data /mnt/usb` will read the JSON-files from given path and fill the local database.
- Now use `repos enable` (or `products enable`) to mark repos for mirroring.
- `rmt-cli export settings` saves your settings at path as `repos.json`.

## Regular workflow

### On the Online RMT

- `rmt-cli export repos` will look for the `repos.json` at given path and mirror these repos directly to that path.

### On the Offline RMT

- `rmt-cli import repos` will mirror all repos which are enabled in the database, from the given path.
