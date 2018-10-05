### rmt-server Packaging

Note: Never push changes to the internal build service `ibs://Devel:SCC:RMT`!
          The repository links to `systemsmanagement:SCC:RMT` and gets updated
          automatically.


* The package is built in OBS at: https://build.opensuse.org/package/show/systemsmanagement:SCC:RMT/rmt-server
* To update the version of RMT, you will have to change the following files:
  * `Makefile`
  * `lib/rmt.rb`
  * `package/rmt-server.spec`

1. Checkout/update OBS working copy:
      * If the OBS project is not checked out, check out working copy of OBS project into a separate directory, e.g.:
          ```
          mkdir ~/obs
          cd ~/obs
          osc co systemsmanagement:SCC:RMT rmt-server
          ```
      * Alternatively, if an OBS working copy is already checked out, update the working copy by running `osc up`
2. Run `make dist` in your RMT working directory to build a tarball.
3. Copy the files from the `package` directory to the OBS working directory.
4. Build the package with osc:

    `osc build <repository> <arch> --no-verify`

    The list of all build targets and architectures that are configured for the project can be obtained by running `osc repos`.

5. Examine the changes by running `osc status` and `osc diff`.
6. Stage the changes by running `osc addremove`.
7. Commit the changes into OBS by running `osc ci`.

#### Submit Requests to openSUSE Factory and SLES

To get a maintenance request accepted, each changelog entry needs to have at
least one reference to a bug or feature request like `bsc#123` or `fate#123`.

Note: If you want to disable automatic changes made by osc (e.g. License string)
      use the `--no-cleanup` switch. Can be used with commands like `osc mr`, `osc sr`
      and `osc ci`.

##### Factory First

To submit a request to openSUSE Factory, issue this commands in the console:

```bash
osc sr systemsmanagement:SCC:RMT rmt-server openSUSE:Factory
```

##### Submit maintenance updates for SLES to the Internal Build Service

###### Get target codestreams where to submit

To check out which codestreams the package is currently maintained in, run:

```bash
osc -A https://api.suse.de maintained rmt-server
```

For a more detailed view which target codestreams are in which state, check out: [Codestream overview](https://maintenance.suse.de/maintained/?package=rmt-server)

###### Submit updates

For each maintained codestream you need to create a new maintenance request:

```bash
osc -A https://api.suse.de mr Devel:SCC:RMT rmt-server SUSE:SLE-15:Update
```

Note: In case the `mr` (maintenance request) command is not working properly,
      try `sr` (submit request) command.


Example:

```bash
$ osc -A https://api.suse.de maintained rmt-server
SUSE:SLE-15:Update/rmt-server

$ osc -A https://api.suse.de mr Devel:SCC:RMT rmt-server SUSE:SLE-15:Update
Using target project 'SUSE:Maintenance'
17362323
```

You can check the status of your requests [here](https://build.opensuse.org/package/requests/systemsmanagement:SCC:RMT/rmt-server) and [here](https://build.suse.de/package/requests/Devel:SCC:RMT/rmt-server).

After your requests have been accepted, they still have to pass maintenance testing before they are released to customers. You can check their progress at [maintenance.suse.de](https://maintenance.suse.de/search/?q=rmt-server). If you still need help, the maintenance team can be reached at [maint-coord@suse.de](maint-coord@suse.de) or #maintenance on irc.suse.de.
