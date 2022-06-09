SUSE Repository Management Container
====================================

SUSE RMT container running on opensuse/leap:15.1 and mariadb:10.3.

The container is used for syncing repositories from SUSE Customer Center, enabling repositories based on specific versions of SUSE and mirroring the enabled repositories.

Example
-------
Set of basic commands for `rmt-cli` that can be run against the SUSE RMT Container if ever needed to run manually.

* Syncing RMT Container to SCC
    ```
    docker-compose exec rmt rmt-cli sync
    ```

* Listing repositories that are available
    ```
    docker-compose exec rmt rmt-cli repos list --all
    ```

* Enabling repositories
    ```
    docker-compose exec rmt rmt-cli repo enable <IDS_COMMA_SEPARATED>
    ```

* Mirroring repositories that have been enabled
    ```
    docker-compose exec rmt rmt-cli mirror
    ```

* Other options available if needed
    ```
    docker-compose exec rmt rmt-cli help
    ```

Mirrored Repository Location
----------------------------
The repositories that were mirrored are located at `/data`, which is defined within the `docker-compose.yml`.
```
...
volumes:
    - /data:/usr/share/rmt/public/repo
...
```