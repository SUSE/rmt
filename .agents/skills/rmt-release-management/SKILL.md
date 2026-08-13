---
name: rmt-release-management
description: Management of the rmt-server release lifecycle, including version updates, OBS/IBS packaging, GitHub tagging, and downstream submissions to openSUSE Factory and SLES.
---

# RMT Release Management

This skill guides you through the process of releasing a new version of `rmt-server`.

## Workflow Overview

The release process differs between RMT 2 and RMT 3:

> **Project split (as of 2026):** RMT v2 and v3 now live in **separate** packaging projects on both build services. RMT v2 has its own `...:RMT2` project; the original `...:RMT` project is now **v3-only**.
>
> | Version | OBS (`api.opensuse.org`) | IBS (`api.suse.de`) | Git branch |
> |---|---|---|---|
> | **v2** | `systemsmanagement:SCC:RMT2` | `Devel:SCC:RMT2` | `master` |
> | **v3** | `systemsmanagement:SCC:RMT` | `Devel:SCC:RMT` | `rmt_3` |

### RMT 2.x (master branch) - Traditional OBS Workflow
- **Branch:** `master`
- **Workflow:** OBS-only (no git-based package management) — unchanged; only the project names moved to the `...:RMT2` suffix
- **Projects:** OBS `systemsmanagement:SCC:RMT2` (openSUSE builds) and IBS `Devel:SCC:RMT2` (SLE maintenance)
- **Build Targets:** SLE 15 SP4, SP5, SP6, SP7
- **Process:** Direct OBS/IBS package updates via `osc` commands

### RMT 3.x (rmt_3 branch) - Git-Based Workflow
- **Branch:** `rmt_3`
- **Workflow:** Git-first with OBS integration
- **Projects:** OBS `systemsmanagement:SCC:RMT` (the main project, now v3-only) and IBS `Devel:SCC:RMT`
- **Package git repository:** `pool/rmt-server` — **not** `systemsmanagement/rmt-server`
  - `gitea@src.suse.de:pool/rmt-server` - SLFO/SLE builds (requires VPN/internal network)
  - `gitea@src.opensuse.org:pool/rmt-server` - public mirror (Factory/Leap branches)
- **Branch → target mapping** (verified against `osc meta pkg`):

  | Branch | Consumed by | Mechanism |
  |---|---|---|
  | `slfo-main` | `SUSE:SLFO:Main` → SLES **16.1** | `scmsync` |
  | `slfo-1.2` | `SUSE:SLFO:1.2` → SLES **16.0** | `scmsync` |
  | `factory`, `leap-16.0`, `leap-16.1` | openSUSE Factory / Leap 16.x | submit request |

  Note the naming trap: `slfo-1.2` is the *older* product (16.0); `slfo-main` is the rolling branch that becomes 16.1.

- **Two parallel delivery paths:**
  - **SLFO / SLES 16** → fork PR against `pool/rmt-server` (`slfo-main`, `slfo-1.2`, **one source branch each**); the scmsync bot builds and forwards.
  - **SLE 15 SP7** → OBS devel project `systemsmanagement:SCC:RMT`, then IBS `osc mr Devel:SCC:RMT rmt-server SUSE:SLE-15-SP7:Update`.
- **Never commit to IBS `Devel:SCC:RMT` directly** — it is a `_link` to `openSUSE.org:systemsmanagement:SCC:RMT` and follows the OBS project automatically.
- See [git-workflow.md](references/git-workflow.md) for details

**Detailed Action Plans:** See [release-workflow.md](references/release-workflow.md) for phase-by-phase instructions.

## Release Gates / Preconditions

> **BLOCKING GATE — tracker reference required.** Before **any** submission (openSUSE Factory `osc sr`, SLE/SLFO submission, IBS maintenance request `osc mr`, or an agit PR to a product branch on `src.suse.de` / `src.opensuse.org`), `package/obs/rmt-server.changes` **must** contain an entry for the release version, and that entry **must** carry at least one valid tracker reference:
>
> - **Bugzilla:** `bsc#NNNNNNN`
> - **Jira:** `jsc#XXX-NNN`
> - **FATE:** `fate#NNNNNN`
>
> A changelog entry with no tracker reference is a **blocker**: do not submit until one is added. SUSE maintenance/QA tooling rejects submissions whose changelog has no trackable reference — the reference is what links the update to a bug/feature record for release notes and QA.
>
> **Verify before submitting:**
> ```bash
> head -20 package/obs/rmt-server.changes | grep -Eq 'bsc#[0-9]{6,7}|jsc#[A-Z]+-[0-9]+|fate#[0-9]+' && echo OK || echo "BLOCKER: no tracker reference"
> ```

## Prerequisites & Dependencies

### Tools
- **`osc`**: CLI for interacting with OBS and IBS.
- **`make`**: Required for `make dist`.
- **`git`**: For version control, tagging, and GitHub releases.
- **`git-obs`** (optional): CLI helper for git-based package workflows (fork, clone, PR management).
- **`git-lfs`** (RMT 3.x): required — tarballs and man pages in `pool/rmt-server` are stored via LFS (see its `.gitattributes`). Without it you commit broken pointer files.

### Configuration (Project Memory)
To streamline the process, ensure the following path is saved in the project memory:
- **`OBS_WORKSPACE`**: The local path to your OBS checkouts (e.g., `/path/to/obs_workspace`). Use `save_memory` to persist this.

### Version-Specific Constraints

#### RMT 2.x (master branch)
- **Workflow:** Traditional OBS/IBS (no git package management)
- **Devel Projects:** OBS `systemsmanagement:SCC:RMT2` (`api.opensuse.org`) and IBS `Devel:SCC:RMT2` (`api.suse.de`)
- **Target Streams:** Submit Maintenance Requests (MRs) from `Devel:SCC:RMT2` for **SLE 15 SP4** (LTSS until EOL 2026), **SLE 15 SP5** (LTSS until EOL 2027), **SLE 15 SP6**, and **SLE 15 SP7**
- **Example streams:** `SUSE:SLE-15-SP4:Update`, `SUSE:SLE-15-SP5:Update`, `SUSE:SLE-15-SP6:Update`, `SUSE:SLE-15-SP7:Update`

#### RMT 3.x (rmt_3 branch)
- **Workflow:** Git-first with OBS integration
- **Repository Locations:** `pool/rmt-server` on both instances
  - **src.suse.de:** SLFO / SLE-based products (requires VPN)
  - **src.opensuse.org:** public mirror, Factory/Leap branches
- **Sync:** Automatic bidirectional sync between .org and .de (within minutes)
- **Target Streams:** `SUSE:SLFO:Main` and `SUSE:SLFO:1.2` (via `slfo-main` / `slfo-1.2` scmsync), plus `SUSE:SLE-15-SP7:Update` (via IBS `osc mr` from `Devel:SCC:RMT`)

### Access & Accounts

#### Common (RMT 2 & 3)
- **GitHub**: Push access to the RMT repository
- **SMELT**: Access to `https://smelt.suse.de` for codestream identification

#### RMT 2.x Specific
- **OBS (openSUSE)**: Account with permissions for `systemsmanagement:SCC:RMT2` at `https://api.opensuse.org`
- **IBS**: Account with permissions for `Devel:SCC:RMT2` at `https://api.suse.de`
- **Network**: SUSE internal network or VPN for IBS access

#### RMT 3.x Specific
- **OBS (openSUSE)**: Account with permissions for `systemsmanagement:SCC:RMT` (the main, v3-only project) at `https://api.opensuse.org`
- **Gitea (.org)**: SSH key configured at `src.opensuse.org` for Factory/Tumbleweed/Leap
- **Gitea (.de)**: SSH key configured at `src.suse.de` for SLE builds (requires VPN)
- **Network**: VPN required for `src.suse.de` and SLE-related operations

### Critical Files
- `lib/rmt.rb`: Source for version string.
- `package/obs/rmt-server.spec`: RPM spec file.
- `package/obs/*`: Support files to be synced to OBS.

## Automated Release

### RMT 2.x Only
For RMT 2.x releases, use the bundled `release.sh` script. This script orchestrates Phases 1 through 5 for the traditional OBS workflow.

**Note:** This script is for RMT 2.x (master branch) only. RMT 3.x requires git-based workflow integration.

### Usage
```bash
./scripts/release.sh --version <X.Y.Z> --obs-path <PATH> [--dry-run] [--streams "STREAM1 STREAM2"]
```

**Parameters:**
- `--version`: The target version for the release (e.g., `2.28`).
- `--obs-path`: The local path to the IBS `rmt-server` package directory.
- `--dry-run`: (Optional) Simulates all commands without executing them.
- `--streams`: (Optional) Space-separated list of specific IBS streams (e.g., `"SUSE:SLE-15-SP6:Update SUSE:SLE-15-SP7:Update"`). If omitted, defaults to all maintained streams.

**Pre-flight Checks:**
- Ensure you are on the `master` branch (RMT 2.x).
- Ensure you are in the RMT repository root.
- Ensure `docker`, `osc`, and `git` are configured.

## Common Tasks

### 1. Update Version Strings
To update the version across the codebase:
- **Ruby:** Update `VERSION` in `lib/rmt.rb`.
- **RPM:** Update `Version:` in `package/obs/rmt-server.spec`.

### 2. Build Source Tarball
**Environment Requirement:** For RMT 2.x (master branch), the build **must** be executed within the Docker container to ensure Ruby 2.5.9 is used. Modern host environments (e.g., Ruby 3.4+) will fail to compile native extensions for locked gems.

**Pre-flight Checks:**
- Ensure `public/repo` exists (create if missing: `mkdir -p public/repo`).
- Verify Docker image is built: `docker compose build rmt`.

Run the following in the project root:
```bash
make dist
```

`make dist` uses `docker compose run -it`, which fails without a TTY (CI, background agents). In that case run the equivalent directly:
```bash
docker compose run --rm -v "$PWD":/srv/www/rmt rmt make build-tarball
```

Note that `build-tarball` depends on `clean`, which deletes `package/obs/*.tar.bz2` — back up the current tarball first if it is the only copy.

**Output Artifacts:**
- `package/obs/rmt-server-<VERSION>.tar.bz2`
- `package/obs/rmt-cli.8.gz` (Man page)

### 3. Open Build Service (OBS) Workflow

#### RMT 2.x - Traditional OBS Workflow (master branch)
**No git package management.** Work directly with OBS:

**Working Copy Setup:**
- openSUSE builds: `osc -A https://api.opensuse.org co systemsmanagement:SCC:RMT2 rmt-server`
- SLE maintenance (VPN): `osc -A https://api.suse.de co Devel:SCC:RMT2 rmt-server`

**Sync & Stage:**
- Copy files from the RMT repository's `package/obs/` to the OBS working directory
- **Manual Cleanup:** Delete old versioned tarballs (e.g., `rm rmt-server-2.26.tar.bz2`)
- **Update Manifest:** Run `osc addremove` to stage changes

**Commit:** `osc ci` to upload to IBS

**Build Verification:**
- Wait for builds to complete: `osc -A https://api.suse.de results --watch`
- Verify build success for maintained streams before proceeding to release tagging and IBS submissions

#### RMT 3.x - Git-Based Workflow (rmt_3 branch)
**Git-first approach.** Changes go to git repositories first, then sync to OBS.

**Repository Selection:**
- **For Factory/Tumbleweed/Leap:** Use `src.opensuse.org` and OBS at `api.opensuse.org`
- **For SLE products:** Use `src.suse.de` (requires VPN) and IBS at `api.suse.de`

**Working Copy Setup:**
```bash
# Package git repository (SLFO/SLE — requires VPN)
git clone gitea@src.suse.de:pool/rmt-server        # or your fork: gitea@src.suse.de:<user>/rmt-server

# Public mirror (Factory/Leap branches)
git clone gitea@src.opensuse.org:pool/rmt-server

# OBS devel project (SLE 15 SP7 + openSUSE builds)
osc -A https://api.opensuse.org co systemsmanagement:SCC:RMT rmt-server
```

**Do not check out or commit `Devel:SCC:RMT` on IBS** — it is a `_link` to the OBS project and updates itself. Use it only as the *source* of a maintenance request.

**Sync & Stage:**
- Commit changes to git first (see [git-workflow.md](references/git-workflow.md))
- **Manual Cleanup:** Delete old versioned tarballs in the OBS directory
- **Sync Files:** Copy from git repo's `package/obs/` to OBS working directory
- **Update Manifest:** Run `osc addremove`

**Commit:** Only after git PR is merged: `osc ci`

**Build Verification:**
- For OBS (Factory/Tumbleweed/Leap): `osc -A https://api.opensuse.org results --watch`
- For IBS (SLE): Verify IBS Devel:SCC:RMT package matches OBS submission and builds successfully:
  ```bash
  osc -A https://api.suse.de checkout Devel:SCC:RMT rmt-server /tmp/ibs-verify
  osc -A https://api.suse.de results Devel:SCC:RMT rmt-server --watch
  ```
- Wait for builds to stabilize before proceeding to release tagging and stream submissions

### 4. Advanced IBS Discovery (SLES)
If `osc -A https://api.suse.de maintained rmt-server` does not show a requested codestream (e.g., a specific Service Pack):
- **Search:** Use `osc -A https://api.suse.de search rmt-server | grep Update` to find all available update projects.
- **Verify:** Use `osc -A https://api.suse.de ls <PROJECT> rmt-server` to confirm the package exists before submitting an MR.

### 5. Git Tagging and GitHub Release

#### Git Tagging (Automated)
**Pre-tagging Checks:**
- Verify the remote `origin` points to the authoritative repository: `git remote -v`.
- Check if the tag already exists locally or remotely: `git ls-remote --tags origin v<version>`.

**Create and Push Tag:**
- **Annotated Tag:** Always use an annotated tag for formal releases to include metadata (tagger, date, message).
  ```bash
  git tag -a v<version> -m "Release v<version>"
  ```
- **Push:** Push the tag to the authoritative remote.
  ```bash
  git push origin v<version>
  ```

#### GitHub Release Creation (Manual UI Step)
After the git tag is pushed, create a GitHub Release via the web UI:
- Navigate to the GitHub "Releases" page
- Click "Draft a new release"
- Select the pushed tag (e.g., `v<version>`)
- Add release notes and changelog
- Publish the release

**Note:** Git tagging and GitHub Releases are distinct operations. The tag is a git object; a GitHub Release is a UI feature that combines a tag with release notes and optional artifacts.

### 6. Factory Submission (RMT 3.x)

For RMT 3.x releases, submit to openSUSE Factory to make the package available in Tumbleweed/Leap.

> **Check the ground truth first.** As of the 3.1 release, `openSUSE:Factory` has **no** `rmt-server` package (`osc ls openSUSE:Factory rmt-server` → 404), and the `factory` / `leap-16.0` / `leap-16.1` branches of `pool/rmt-server` are stale at 2.18. A submission is therefore a **new-package** submission (legal/licensedigger review, staging), not a routine version update — treat it as its own piece of work, not a step in the release. Verify with `osc ls openSUSE:Factory rmt-server` before assuming otherwise.

**Prerequisites:**
- OBS workspace configured with `systemsmanagement:SCC:RMT/rmt-server` checked out
- Package already committed and built in the source project
- **BLOCKING GATE:** the `package/obs/rmt-server.changes` entry for this version contains at least one tracker reference (`bsc#NNNNNNN`, `jsc#XXX-NNN` or `fate#NNNNNN`) — see [Release Gates / Preconditions](#release-gates--preconditions). Do not run `osc sr` until this passes:
  ```bash
  head -20 package/obs/rmt-server.changes | grep -Eq 'bsc#[0-9]{6,7}|jsc#[A-Z]+-[0-9]+|fate#[0-9]+' && echo OK || echo "BLOCKER: no tracker reference"
  ```

**Submission Process:**

1. **Check for existing submit requests:**
   ```bash
   osc -A https://api.opensuse.org request list systemsmanagement:SCC:RMT rmt-server openSUSE:Factory
   ```

2. **Create submit request:**
   ```bash
   osc -A https://api.opensuse.org sr systemsmanagement:SCC:RMT rmt-server openSUSE:Factory \
     -m "Submit rmt-server <version> to Factory
   
   Update rmt-server to version <version>.
   
   Key changes:
   - Updated to Ruby X.Y.Z and Rails A.B.C
   - Security: [CVE fixes with bsc# references]
   
   Bug fixes:
   - bsc#XXXXXX: [Description]
   - bsc#YYYYYY: [Description]
   "
   ```

3. **Monitor the request:**
   ```bash
   osc -A https://api.opensuse.org request show <request-id>
   ```
   
   Automated reviewers will check:
   - **factory-auto**: Automated validation (changelog order, spec file syntax, etc.)
   - **licensedigger**: License compliance check
   - **factory-staging**: Manual review and staging

**If Request is Rejected:**

1. **Check the rejection reason:**
   ```bash
   osc -A https://api.opensuse.org request show <request-id>
   ```
   Look for the rejection message under the failed reviewer.

2. **Fix the issue in the git repository:**
   ```bash
   # Edit the problematic file(s)
   vim package/obs/rmt-server.changes  # or .spec, etc.
   
   # Commit the fix
   git add package/obs/rmt-server.changes
   git commit -m "Fix: <description of issue>"
   ```

3. **Update the OBS package:**
   ```bash
   # Copy fixed file(s) to OBS workspace
   cp package/obs/rmt-server.changes <OBS-workspace>/systemsmanagement:SCC:RMT/rmt-server/
   
   # Commit to OBS
   cd <OBS-workspace>/systemsmanagement:SCC:RMT/rmt-server
   osc -A https://api.opensuse.org ci -m "Fix: <description>"
   ```

4. **Create new submit request superseding the rejected one:**
   ```bash
   osc -A https://api.opensuse.org sr systemsmanagement:SCC:RMT rmt-server openSUSE:Factory \
     --supersede <rejected-request-id> \
     -m "Submit rmt-server <version> to Factory (fixed <issue>)
   
   [Same description as before]
   
   Fixed: <description of what was corrected>"
   ```

**Common Issues:**

- **Changelog not in sequence**: Entries must be in reverse chronological order (newest date first)
- **Missing dependencies**: Add required BuildRequires to `.spec` file
- **License issues**: Verify License field uses correct SPDX format

### 6b. SLFO and SLE 15 SP7 Submissions (RMT 3.x)

**SLFO / SLES 16** — PR against `pool/rmt-server` from a **fork**. Both `slfo-main` (→ 16.1) and `slfo-1.2` (→ 16.0) need the update.

> **CONSTRAINT — one source branch per pull request.** `autogits_workflow_pr_bot` auto-closes any PR whose source branch is shared with another open PR ("Pushing commits to a shared source branch … would affect the other pull request(s)"). Since SLFO needs two PRs, create **two branches** off the same commit, one per target. Verified the hard way during 3.1.0: PR #7 was auto-closed the moment PR #8 reused `release-3.1.0`.

> **CONSTRAINT — agit push requires write access.** `git push origin <branch>:refs/for/<target>/<title>` against `pool/rmt-server` fails for non-maintainers with `User: <you> with Key: <key> is not authorized to write to pool/rmt-server.` Use the fork + `git-obs pr create` route below.

```bash
# in the fork clone (origin = gitea@src.suse.de:<you>/rmt-server, upstream = pool/rmt-server)
git fetch --all --prune
git checkout -b release-<version>-slfo-main upstream/slfo-main
# ... copy package/obs artifacts, commit (git-lfs handles the tarball) ...

# one branch per target, both at the same commit
git branch release-<version>-slfo-1.2 release-<version>-slfo-main
git push origin release-<version>-slfo-main release-<version>-slfo-1.2

for t in slfo-main slfo-1.2; do
  git-obs pr create \
    --source <you>/rmt-server:release-<version>-$t \
    --target pool/rmt-server:$t \
    --title "Update to rmt-server <version>" \
    --description "Version <version> (bsc#NNNNNNN)"
done
```
`--source` / `--target` take `<owner>/<repo>:<branch>`. Add `--dry-run` to check first.

After creating, **verify the bots did not close the PRs** — auto-close arrives within a minute or two and `git-obs pr create` reports success regardless:
```bash
git-obs pr get pool/rmt-server#<N>          # expect State: open
```
A healthy PR picks up `autogits_obs_staging_bot` (posts a `br.suse.de` build-results link for `SUSE:SLFO:<stream>:PullRequest:<id>`) and `autobuild-review` (group review; approve via a `@autobuild-review: approve` comment, not the Gitea review UI).

Staging builds and forwarding to `SUSE:SLFO:Main` / `SUSE:SLFO:1.2` are handled by those bots.

**SLE 15 SP7** — classic maintenance request from the OBS devel project via its IBS link:
```bash
osc -A https://api.suse.de maintained rmt-server           # confirm the codestream is live
osc -A https://api.suse.de mr Devel:SCC:RMT rmt-server SUSE:SLE-15-SP7:Update
```
When asked whether to supersede an existing request, the answer is normally **no** — superseding cancels the release process for that codestream.

**Both paths are gated** on the changelog tracker reference — see [Release Gates / Preconditions](#release-gates--preconditions).

### 7. Container Image & Helm Chart Updates
**Container Image:**
- The image build is automated via BCI pipelines but should be monitored at [devel:BCI:SLE-15-SP7/rmt-server-image](https://build.opensuse.org/package/show/devel:BCI:SLE-15-SP7/rmt-server-image).
- Verification: Check `registry.suse.com/suse/rmt-server` for the new tag once the RPM is published.

**Helm Chart (Manual):**
- **Repository:** Clone [SUSE/helm-charts](https://github.com/SUSE/helm-charts.git).
- **Edit `rmt-helm/Chart.yaml`:**
  - `version`: Update the Helm chart version.
  - `appVersion`: Update to the new RMT version (e.g., `2.27`).
  - `BuildTag`: Update the container image build tag.
- **Submission:** Submit a PR for the changes.
- **Coordination:** After the PR is merged, notify the BCI team in the `#proj-bci` Slack channel to trigger the release.

## Formatting Requirements

### Changelog Entries
Every changelog entry for a release **must** reference a relevant bugzilla, jira or fate entry:
- **Bugzilla:** `bsc#NNNNNNN`
- **Jira:** `jsc#XXX-NNN`
- **FATE:** `fate#NNNNNN`

**This is a blocking gate for all submissions** (Factory `osc sr`, SLE/SLFO submissions, IBS `osc mr`, agit PRs to product branches) — an entry without a tracker reference must be fixed before submitting. Verify with:
```bash
head -20 package/obs/rmt-server.changes | grep -Eq 'bsc#[0-9]{6,7}|jsc#[A-Z]+-[0-9]+|fate#[0-9]+' && echo OK || echo "BLOCKER: no tracker reference"
```

Use `osc vc` in the `package/obs/` directory to edit the `.changes` file with proper formatting.

### Pull Requests
Two mechanisms exist; pick by access level:

| | Maintainer (write access) | Contributor (fork) |
|---|---|---|
| Mechanism | agit push | fork + `git-obs pr create` |
| Command | `git push origin <branch>:refs/for/<target>/<title>` | `git-obs pr create --source <you>/rmt-server:<branch> --target pool/rmt-server:<target>` |

For `pool/rmt-server` the fork route is the normal one — agit push is rejected without write access.

**One source branch per open PR.** Reusing a branch across two PRs gets the earlier one auto-closed by `autogits_workflow_pr_bot`. Name branches per target, e.g. `release-3.1.0-slfo-main` / `release-3.1.0-slfo-1.2`.

See [git-workflow.md](references/git-workflow.md) for examples.
