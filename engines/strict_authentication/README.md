# StrictAuthentication

This engine enables strict authentication for accessing the service.
It checks if the authenticated system has the product the service belongs to activated.

Works only in conjunction with the `zypper_auth` engine, that injects the `plugin:/susecloud` prefix into the service + repo urls, so that zypper includes the system credentials as authorization headers.


