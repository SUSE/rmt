# SCC Suma API

Mainly used in Public Cloud instances

SUMa needs access to SCC information
To access this information, SCC has several endpoints
Only a subset of SCC endpoints are needed to mirror
the specific repository information to RMT

In order to access said endpoints, some authentication is needed
So SUMa to verify that the instance metadata is valid if the endpoints need
authentication, this verification is based on `InstanceVerification` engine
