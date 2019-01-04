# RegistrationSharing

Registration sharing for HA setups.

## Configuration

Plug-in can be configured by parameters in `regsharing` section of RMT configuration file, e.g.:

```
regsharing:
  peers:
    - example.com
    - example.org
  api_secret: s3cr3t_t0k3n
  smt_allowed_ips:
    - 123.123.123.123
  data_dir: /srv/regsharing/data-dir
  ca_path: /srv/regsharing/ca
```

* `peers` -- list of hostnames/IP addresses, to which registration data will be shared;
* `api_secret` -- shared API secret;
* `smt_allowed_ips` -- list of IPs from which regsharing requests are accepted that use legacy SMT regsharing API;
* `data_dir` (optional) -- directory for persisting shared data state, `/var/lib/rmt/regsharing` is used if not set;
* `ca_path` (optional) -- path to CA trust store (for peer certificates that aren't trusted by CAs in the system-wide trust store). 

## Rake tasks

The plugin provides `regsharing:sync` rake task, which does a one-shot sync of changed systems to the peer servers.

## systemd

The plugin provides `rmt-server-regsharing.service` (which runs `rake regsharing:sync`) and `rmt-server-regsharing.timer` that runs `rmt-server-regsharing.service` every 30 seconds:

Run:

* `systemctl start rmt-server-regsharing.timer` to start the timer;
* `systemctl enable rmt-server-regsharing.timer` to start it after boot.