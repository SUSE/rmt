# Repository Mirroring Tool
![Kartoha](https://travis-ci.org/SUSE/rmt.svg?branch=master)

This tool allows you to mirror RPM update repositories in your own private network. Registered organization credentials are required to mirror SUSE repositories.

You can run the application locally using the docker-compose:

```bash
docker-compose up
```

And it will be accessible at http://localhost:8080/ .

## Dependencies

The application is tested only on ruby 2.4.1 and newer. Support of older MRI is not intended.
