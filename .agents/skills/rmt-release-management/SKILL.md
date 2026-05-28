---
name: rmt-release-management
description: Management of the rmt-server release lifecycle, including version updates, OBS/IBS packaging, GitHub tagging, and downstream submissions to openSUSE Factory and SLES.
---

# RMT Release Management

This skill guides you through the process of releasing a new version of `rmt-server`.

## Workflow Overview

The release process follows a 5-phase lifecycle. See [release-workflow.md](references/release-workflow.md) for the detailed action plan and visual graph.

## Prerequisites & Dependencies

### Tools
- **`osc`**: CLI for interacting with OBS and IBS.
- **`make`**: Required for `make dist`.
- **`git`**: For version control, tagging, and GitHub releases.

### Configuration (Project Memory)
To streamline the process, ensure the following path is saved in the project memory:
- **`OBS_WORKSPACE`**: The local path to your OBS checkouts (e.g., `/path/to/obs_workspace`). Use `save_memory` to persist this.

### RMT 2.x Release Constraints
- **Target Streams:** For RMT 2.x (master branch) releases, only submit Maintenance Requests (MRs) for **SLE 15 SP6** and **SLE 15 SP7**.
  - Example streams: `SUSE:SLE-15-SP6:Update`, `SUSE:SLE-15-SP7:Update`.

### Access & Accounts
- **OBS**: Account with permissions for `systemsmanagement:SCC:RMT`.
- **IBS**: Account with permissions for `Devel:SCC:RMT` at `https://api.suse.de`.
- **GitHub**: Push access to the RMT repository.
- **SMELT**: Access to `https://smelt.suse.de` for codestream identification.

### Critical Files
- `lib/rmt.rb`: Source for version string.
- `package/obs/rmt-server.spec`: RPM spec file.
- `package/obs/*`: Support files to be synced to OBS.

## Automated Release

For a streamlined release process, use the bundled `release.sh` script. This script orchestrates Phases 1 through 5.

### Usage
```bash
./scripts/release.sh --version <X.Y.Z> --obs-path <PATH> [--dry-run] [--streams "STREAM1 STREAM2"]
```

**Parameters:**
- `--version`: The target version for the release (e.g., `2.28`).
- `--obs-path`: The local path to the OBS `rmt-server` package directory.
- `--dry-run`: (Optional) Simulates all commands without executing them.
- `--streams`: (Optional) Space-separated list of specific IBS streams (e.g., `"SUSE:SLE-15-SP6:Update SUSE:SLE-15-SP7:Update"`). If omitted, defaults to all maintained streams.

**Pre-flight Checks:**
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
**Working Copy Setup:**
- If `~/.oscrc` is missing, explicitly use the API URL: `-A https://api.opensuse.org`.
- Confirm the project name (e.g., `systemsmanagement:SCC:RMT`) using `osc ls`.

**Sync & Stage:**
- **Manual Cleanup:** Delete old versioned tarballs (e.g., `rm rmt-server-2.26.tar.bz2`) in the OBS directory before syncing.
- **Sync Files:** Copy all contents from the RMT repository's `package/obs/` to the local OBS working directory.
- **Update Manifest:** Run `osc addremove` to stage the new tarball and remove the old one.

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
When submitting maintenance requests (SLES), ensure changelog entries reference relevant bugzilla or fate entries (e.g., `bsc#123456`).
