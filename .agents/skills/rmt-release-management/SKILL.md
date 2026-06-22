---
name: rmt-release-management
description: Management of the rmt-server release lifecycle, including version updates, OBS/IBS packaging, GitHub tagging, and downstream submissions to openSUSE Factory and SLES.
---

# RMT Release Management

This skill guides you through the process of releasing a new version of `rmt-server`.

## Workflow Overview

The release process differs between RMT 2 and RMT 3:

### RMT 2.x (master branch) - Traditional OBS Workflow
- **Branch:** `master`
- **Workflow:** OBS-only (no git-based package management)
- **Build Targets:** SLE 15 SP4, SP5, SP6, SP7
- **Process:** Direct OBS package updates via `osc` commands

### RMT 3.x (rmt_3 branch) - Git-Based Workflow
- **Branch:** `rmt_3`
- **Workflow:** Git-first with OBS integration
- **Repositories:**
  - `src.opensuse.org` - openSUSE Factory, Tumbleweed, Leap builds
  - `src.suse.de` - SLE-based builds (requires VPN/internal network)
- **Process:** Git commits → OBS sync → builds
- See [git-workflow.md](references/git-workflow.md) for details

**Detailed Action Plans:** See [release-workflow.md](references/release-workflow.md) for phase-by-phase instructions.

## Prerequisites & Dependencies

### Tools
- **`osc`**: CLI for interacting with OBS and IBS.
- **`make`**: Required for `make dist`.
- **`git`**: For version control, tagging, and GitHub releases.
- **`git-obs`** (optional): CLI helper for git-based package workflows (fork, clone, PR management).

### Configuration (Project Memory)
To streamline the process, ensure the following path is saved in the project memory:
- **`OBS_WORKSPACE`**: The local path to your OBS checkouts (e.g., `/path/to/obs_workspace`). Use `save_memory` to persist this.

### Version-Specific Constraints

#### RMT 2.x (master branch)
- **Workflow:** Traditional OBS-only (no git package management)
- **Target Streams:** Submit Maintenance Requests (MRs) for **SLE 15 SP4** (LTSS until EOL 2026), **SLE 15 SP5** (LTSS until EOL 2027), **SLE 15 SP6**, and **SLE 15 SP7**
- **Example streams:** `SUSE:SLE-15-SP4:Update`, `SUSE:SLE-15-SP5:Update`, `SUSE:SLE-15-SP6:Update`, `SUSE:SLE-15-SP7:Update`
- **Build Service:** IBS only (`api.suse.de`)

#### RMT 3.x (rmt_3 branch)
- **Workflow:** Git-first with OBS integration
- **Repository Locations:**
  - **src.opensuse.org:** openSUSE Factory, Tumbleweed, Leap
  - **src.suse.de:** SLE-based products (requires VPN)
- **Sync:** Automatic bidirectional sync between .org and .de (within minutes)
- **Target Products:** To be determined based on RMT 3 release schedule

### Access & Accounts

#### Common (RMT 2 & 3)
- **GitHub**: Push access to the RMT repository
- **SMELT**: Access to `https://smelt.suse.de` for codestream identification

#### RMT 2.x Specific
- **IBS**: Account with permissions for `Devel:SCC:RMT` at `https://api.suse.de`
- **Network**: SUSE internal network or VPN for IBS access

#### RMT 3.x Specific
- **OBS (openSUSE)**: Account with permissions for `systemsmanagement:SCC:RMT` at `https://api.opensuse.org`
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

**Output Artifacts:**
- `package/obs/rmt-server-<VERSION>.tar.bz2`
- `package/obs/rmt-cli.8.gz` (Man page)

### 3. Open Build Service (OBS) Workflow

#### RMT 2.x - Traditional OBS Workflow (master branch)
**No git package management.** Work directly with OBS:

**Working Copy Setup:**
- Use IBS API: `-A https://api.suse.de`
- Checkout package: `osc -A https://api.suse.de co Devel:SCC:RMT rmt-server`

**Sync & Stage:**
- Copy files from the RMT repository's `package/obs/` to the OBS working directory
- **Manual Cleanup:** Delete old versioned tarballs (e.g., `rm rmt-server-2.26.tar.bz2`)
- **Update Manifest:** Run `osc addremove` to stage changes

**Commit:** `osc ci` to upload to IBS

#### RMT 3.x - Git-Based Workflow (rmt_3 branch)
**Git-first approach.** Changes go to git repositories first, then sync to OBS.

**Repository Selection:**
- **For Factory/Tumbleweed/Leap:** Use `src.opensuse.org` and OBS at `api.opensuse.org`
- **For SLE products:** Use `src.suse.de` (requires VPN) and IBS at `api.suse.de`

**Working Copy Setup:**
```bash
# For Factory/Tumbleweed/Leap
git clone gitea@src.opensuse.org:systemsmanagement/rmt-server
osc -A https://api.opensuse.org co systemsmanagement:SCC:RMT rmt-server

# For SLE builds (requires VPN)
git clone gitea@src.suse.de:systemsmanagement/rmt-server
osc -A https://api.suse.de co Devel:SCC:RMT rmt-server
```

**Sync & Stage:**
- Commit changes to git first (see [git-workflow.md](references/git-workflow.md))
- **Manual Cleanup:** Delete old versioned tarballs in the OBS directory
- **Sync Files:** Copy from git repo's `package/obs/` to OBS working directory
- **Update Manifest:** Run `osc addremove`

**Commit:** Only after git PR is merged: `osc ci`

**Local Verification:**
- Identify valid build targets: `osc repos`.
- Build locally for verification: `osc build <repo> <arch> --no-verify` (e.g., `osc build 15.6 x86_64 --no-verify`).

**Commit:**
- Commit only after Git merge: `osc ci`.

### 4. Advanced IBS Discovery (SLES)
If `osc maintained rmt-server` does not show a requested codestream (e.g., a specific Service Pack):
- **Search:** Use `osc -A https://api.suse.de search rmt-server | grep Update` to find all available update projects.
- **Verify:** Use `osc -A https://api.suse.de ls <PROJECT> rmt-server` to confirm the package exists before submitting an MR.

### 5. GitHub Release
**Pre-tagging Checks:**
- Verify the remote `origin` points to the authoritative repository: `git remote -v`.
- Check if the tag already exists locally or remotely: `git ls-remote --tags origin v<version>`.

**Tagging & Pushing:**
- **Annotated Tag:** Always use an annotated tag for formal releases to include metadata (tagger, date, message).
  ```bash
  git tag -a v<version> -m "Release v<version>"
  ```
- **Push:** Push the tag to the authoritative remote.
  ```bash
  git push origin v<version>
  ```

**UI Finalization:**
- Navigate to the GitHub "Releases" page and create a formal release from the pushed tag, attaching the changelog.

### 6. Container Image & Helm Chart Updates
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
When submitting maintenance requests (SLES), ensure changelog entries reference relevant bugzilla, jira or fate entries:
- **Bugzilla:** `bsc#123456`
- **Jira:** `jsc#XXX-123456`
- **FATE:** `fate#123456`

Use `osc vc` in the `package/obs/` directory to edit the `.changes` file with proper formatting.

### Pull Requests (agit format)
When contributing via forks, use the agit PR format:
```bash
git push origin <branch>:refs/for/<target-branch>/<pr-title>
```
See [git-workflow.md](references/git-workflow.md) for examples.
