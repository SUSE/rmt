Registry engine configuration
=============================

**Container registry settings**

The `registry` setting lets you adjust behavior of the container registry integration.

  * `token_expiration` setting:
    Specifies the timeout, from issuance, of the authentication/authorization token used by container clients (e.g. podman, docker).
    Default value is 8 hours.
    Acceptable values: Integer greater than 1, in seconds.
