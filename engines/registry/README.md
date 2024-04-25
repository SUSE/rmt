# Registry
Provide an authentication end point for a container registry.
This supports access control based on system credentials to registry paths that are set to have access restrictions.


The Activations endpoint would perform a validation of the instance metadata when the request has `X-Instance-Data` header and it would update the cache for granting access to the registry

Instance validation and cache:

- If the instance data header is set on the request, instance verification
  and cache handling would be triggered
- If instance metadata is valid, the cache would be updated if expired
  and access to the registry is granted
- If instance metadata is not valid, cache would not be updated and
  access to the registry would be denied
