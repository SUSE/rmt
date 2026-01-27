## rmt-server Packaging

### For SLE16+

Note: The Build Team has a [detailed documentation](https://confluence.suse.com/spaces/projectmanagement/pages/1506410865/Where+do+I+submit+my+code) about the new version of SLE.

**Important**: Install git-lfs and git-osc (to add the tarball to LFS)

```
zypper in git-lfs git-osc
```

1. Update the version of RMT in the following files:

    `lib/rmt.rb`

    `package/obs/rmt-server.spec`

2. In the root of the repository run `make build-tarball`

3. Create your fork on the right gitea instance at

    https://src.suse.de/pool/rmt-server

    or

    https://src.opensuse.org/pool/rmt-server

4. git clone gitea@src.suse.de:your_username/rmt-server

5. Enter your_username/rmt-server

6. git checkout slfo-1.2

7. Copy the files from <path-to-rmt>/package/obs to here

8. the usual editing, git commit, git push

9. Create a pull request

    => staging setup (aka test build) and pull request to the target project are
    handled automatically by the bots.

===============================================================================================================

### SLE15 SP7


Note: Never push changes to the internal build service `ibs://Devel:SCC:RMT`!
          The repository links to `systemsmanagement:SCC:RMT` and gets updated
          automatically.

Note: Look below for direction on publishing to registry.


* The package is built in OBS at: https://build.opensuse.org/package/show/systemsmanagement:SCC:RMT/rmt-server-3
* To update the version of RMT, you will have to change the following files:
  * `lib/rmt.rb`
  * `package/obs/rmt-server.spec`

1. Checkout/update OBS working copy:
      * If the OBS project is not checked out, check out working copy of OBS project into a separate directory, e.g.:
          ```
          mkdir ~/obs
          cd ~/obs
          osc co systemsmanagement:SCC:RMT rmt-server
          ```
      * Alternatively, if an OBS working copy is already checked out, update the working copy by running `osc up`
2. Run `make dist` in your RMT working directory to build a tarball.
3. Copy the files from the `package/obs` directory to the OBS working directory `systemsmanagement:SCC:RMT/rmt-server`.
4. Examine the changes by running `osc status` and `osc diff`.
5. Stage the changes by running `osc addremove`.
6. Build the package with osc:

    `osc build <repository> <arch> --no-verify`

    The list of all build targets and architectures that are configured for the project can be obtained by running `osc repos`.

7. After the code is reviewed + merged in the git repository: Commit the changes into OBS by running `osc ci`.

#### Tag and Release the New Version on Github

1. Tag the version locally and push it to github:
    ```
    git tag -a v<version> # for example git tag -a v1.0.0
    git push --tags
    ```
2. On github, submit a release for the tag. See https://help.github.com/en/articles/creating-releases for assistance.

#### Submit Requests to openSUSE Factory and SLES

To get a maintenance request accepted, each changelog entry needs to have at
least one reference to a bug or feature request like `bsc#123` or `fate#123`.
CVEs must be accompanied with the corresponding bsc#, even if it is not reported
vs rmt-server.

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

To check out which codestreams RMT is currently maintained, see https://smelt.suse.de/maintained/?q=rmt-server.

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

**Note:**

* When asked whether or not to supersede a request, the answer is usually "no". Saying "yes" would overwrite the previous request made, cancelling the release process for its codestream.

You can check the status of your requests [here](https://build.opensuse.org/package/requests/systemsmanagement:SCC:RMT/rmt-server) and [here](https://build.suse.de/package/requests/Devel:SCC:RMT/rmt-server).

After your requests have been accepted, they still have to pass maintenance testing before they are released to customers. You can check their progress at [maintenance.suse.de](https://maintenance.suse.de/search/?q=rmt-server). If you still need help, the maintenance team can be reached at [maint-coord@suse.de](maint-coord@suse.de) or #maintenance on irc.suse.de.


## Container image and publishing to SUSE registry

SUSE registry houses the rmt-server docker image. The image is built automatically on OBS/IBS, and can be found [here](https://build.opensuse.org/package/show/devel:BCI:SLE-15-SP7/rmt-server-image).
The BCI build process generates it from [here](https://github.com/SUSE/BCI-dockerfile-generator/tree/main/src/bci_build/package/rmt-server).
It is getting published here: `registry.suse.com/suse/rmt-server` and is available in the registry catalogue at  [registry.suse.com/repositories/rmt](https://registry.suse.com/repositories/rmt).


#### Helm chart update process

RMT helm chart is defined [here](https://github.com/SUSE/helm-charts.git) and published at `registry.suse.com/suse/rmt-helm`.

Edit `rmt-helm/Chart.yaml` to update the chart version (`version`) and rmt-version (`appVersion`). The `BuildTag` version needs to be updated. Look at this example [pull-request](https://github.com/SUSE/helm-charts/pull/5) bumping the version.

Reach out to the BCI team (Dirk Mueller or `#proj-bci` slack channel) to trigger the release of the helm-chart.
