# SUSE Git-based Package Workflow

This reference documents the git-based workflow for contributing to SUSE packages, including **RMT 3.x**. This workflow applies to packages that have been migrated from the traditional OBS-only approach to the new git-first model.

**Important:** This workflow is for **RMT 3.x (rmt_3 branch)** only. RMT 2.x uses the traditional OBS-only workflow without git package management.

## Repository Locations

- **src.opensuse.org (external):** `https://src.opensuse.org` (public)
  - **Purpose:** openSUSE Factory, Tumbleweed, Leap builds
  - **Build Service:** OBS at `api.opensuse.org`
  - **Access:** Public, no VPN required
  
- **src.suse.de (internal):** `https://src.suse.de` (SUSE internal)
  - **Purpose:** SLE-based product builds
  - **Build Service:** IBS at `api.suse.de`
  - **Access:** Requires SUSE VPN or internal network
  
- **Syncing:** Packages sync automatically between .org and .de instances within minutes (bidirectional)

## Prerequisites

### SSH Access
Always use SSH with the `gitea@` user for write access:
```bash
# General format
git clone gitea@src.opensuse.org:ORGANIZATION/PACKAGE_NAME    # For Factory/Tumbleweed/Leap
git clone gitea@src.suse.de:ORGANIZATION/PACKAGE_NAME          # For SLE builds (VPN required)
```

For RMT 3.x the package lives in the **`pool`** organization — not `systemsmanagement`:
```bash
# SLFO/SLE builds (requires VPN) — the authoritative one
git clone gitea@src.suse.de:pool/rmt-server

# Public mirror (Factory/Leap branches)
git clone gitea@src.opensuse.org:pool/rmt-server
```

**Which repository to use:**
- Working on **Factory/Tumbleweed/Leap**? → Use `src.opensuse.org`
- Working on **SLE products**? → Use `src.suse.de` (VPN required)

### git-lfs is mandatory

`pool/rmt-server` stores `*.tar.bz2`, `*.gz` and other binaries via LFS (see its `.gitattributes`). Install `git-lfs` before cloning or committing, otherwise you will commit unusable pointer files. Confirm a staged tarball became a pointer:
```bash
git show HEAD:rmt-server-<version>.tar.bz2 | head -3   # expect: version https://git-lfs.github.com/spec/v1
```

### Branch Mapping

**For RMT 3.x** (verified via `osc meta pkg <project> rmt-server`):

| Branch | Consumed by | Mechanism |
|---|---|---|
| `slfo-main` | `SUSE:SLFO:Main` | `scmsync` |
| `slfo-1.2` | `SUSE:SLFO:1.2` | `scmsync` |
| `factory` | openSUSE Factory | submit request |
| `leap-16.0`, `leap-16.1` | openSUSE Leap 16.x | submit request |

SLE 15 SP7 is **not** in this repository — it is served by the OBS devel project `systemsmanagement:SCC:RMT` and an IBS maintenance request from `Devel:SCC:RMT`.

**Resources:**
- Branch-to-product mapping: [https://src.suse.de/pool](https://src.suse.de/pool)
- Package explorer: [https://src.suse.de](https://src.suse.de) or [https://src.opensuse.org](https://src.opensuse.org)

## Contribution Workflow

### 1. Fork-Based Workflow (Non-Maintainers)

If you don't have write permissions to the main repository:

#### 1.1. Fork via OBS
```bash
# Fork the package in OBS to create your branch project
osc fork systemsmanagement:SCC:RMT rmt-server

# This creates: home:YourUser:branches:systemsmanagement:SCC:RMT

# Checkout your fork
osc co home:YourUser:branches:systemsmanagement:SCC:RMT rmt-server
```

#### 1.2. Clone Your Fork
```bash
# The fork will have its own git repository
# For Factory/Tumbleweed/Leap
git clone gitea@src.opensuse.org:YourUser/rmt-server

# For SLE builds (VPN required)
git clone gitea@src.suse.de:YourUser/rmt-server

cd rmt-server
```

#### 1.3. Make Changes
```bash
# Create/checkout your working branch
git checkout -b feature-branch

# Make your code changes
vim lib/rmt.rb

# Update the changelog
cd package/obs/
osc vc  # This opens the .changes file editor
cd ../..

# Stage and commit
git add lib/rmt.rb package/obs/rmt-server.changes
git commit -m "Description of changes"
```

#### 1.4. Build and Test
```bash
# Run service files (download sources, generate files, etc.)
osc service mr

# Local build verification
osc build --alternative-project=systemsmanagement:SCC:RMT

# Check build results
osc results -w home:YourUser:branches:systemsmanagement:SCC:RMT rmt-server
```

#### 1.5. Submit Pull Request (agit format)

**BLOCKING GATE (PRs to product branches):** verify the changelog carries a tracker reference (`bsc#NNNNNNN`, `jsc#XXX-NNN` or `fate#NNNNNN`) before pushing — see [Changelog Format Requirements](#changelog-format-requirements):
```bash
head -20 package/obs/rmt-server.changes | grep -Eq 'bsc#[0-9]{6,7}|jsc#[A-Z]+-[0-9]+|fate#[0-9]+' && echo OK || echo "BLOCKER: no tracker reference"
```

agit push works **only with write access to the target repository**. For `pool/rmt-server` a non-maintainer gets:
```
error: User: <id>:<you> with Key: <id>:<key> is not authorized to write to pool/rmt-server.
```
So from a fork, push the branch to your fork and open the PR with `git-obs`:
```bash
git push origin feature-branch
git-obs pr create \
  --source <you>/rmt-server:feature-branch \
  --target pool/rmt-server:slfo-main \
  --title "Your PR title" \
  --description "... (bsc#NNNNNNN)"
```
To update the PR afterwards, push more commits to the same fork branch — no need to recreate it.

**agit PR Format** (maintainers, or forks of repos you can write to):
- Target: `refs/for/<target-branch>/<pr-title>`
- See [https://docs.gitea.com/usage/agit](https://docs.gitea.com/usage/agit) for full documentation

### One source branch per open pull request

`autogits_workflow_pr_bot` closes any PR whose source branch is already used by another open PR:

> This pull request's source branch `X` is also used by another open pull request: pool/rmt-server!N. Pushing commits to a shared source branch (e.g. via "Edit by Maintainers") would affect the other pull request(s), so this pull request is being closed. Please push this change to a uniquely named branch and open a new pull request.

This bites whenever one change targets several product branches — the usual SLFO case, where `slfo-main` and `slfo-1.2` both need the same commit. Create one branch per target off the same commit:
```bash
git branch release-<version>-slfo-1.2 release-<version>-slfo-main
git push origin release-<version>-slfo-main release-<version>-slfo-1.2
```
The bot fires a minute or two *after* creation, and `git-obs pr create` reports success either way, so always re-check:
```bash
git-obs pr get pool/rmt-server#<N>   # expect State: open
```

### PR bots on pool/rmt-server

| Bot | Role |
|---|---|
| `autogits_workflow_pr_bot` | Structural checks; auto-closes shared-source-branch PRs |
| `autogits_obs_staging_bot` | Creates `SUSE:SLFO:<stream>:PullRequest:<id>`, posts a `br.suse.de` build-results link |
| `autobuild-review` | Group review. Approve with a comment `@autobuild-review: approve`, request changes with `@autobuild-review: decline` plus justification. **Do not use the Gitea review UI** for this group; comment edits are ignored, post a new comment to change state. |

### Inspecting PR state via the API

`git-obs pr get` shows state but not comments — auto-close reasons live in the comments:
```bash
TOKEN=$(python3 -c "import yaml;c=yaml.safe_load(open('$HOME/.config/tea/config.yml'));[print(l['token']) for l in c['logins'] if l['name']=='ibs']")
curl -s -H "Authorization: token $TOKEN" \
  https://src.suse.de/api/v1/repos/pool/rmt-server/issues/<N>/comments |
  python3 -c "import json,sys;[print('--',c['user']['login'],':',c['body']) for c in json.load(sys.stdin)]"
```

### 2. Direct Push Workflow (Maintainers)

If you have write permissions:

```bash
# Clone the main repository
# For Factory/Tumbleweed/Leap
git clone gitea@src.opensuse.org:pool/rmt-server

# For SLE builds (VPN required)
git clone gitea@src.suse.de:pool/rmt-server

cd rmt-server

# Create feature branch
git checkout -b feature-branch

# Make changes, commit
git add .
git commit

# Push directly
git push origin feature-branch

# Or push to main (after review)
git push origin main
```

### 3. Using git-obs Tool

The `git-obs` CLI provides shortcuts for common operations:

#### Fork and Clone
```bash
# Fork a package
git-obs repo fork pool/rmt-server

# Clone with SSH
git-obs repo clone pool/rmt-server
```

#### Pull Request Operations
```bash
# Create a PR
git-obs pr create --title="Fix version handling" --description="..." --target-branch=main

# Checkout an existing PR
git-obs pr checkout <PR_NUMBER>

# Review a PR
git-obs pr review pool/rmt-server#<PR_NUMBER>

# View PR details
git-obs pr get pool/rmt-server#<PR_NUMBER>
```

## Release-Specific Workflow

### Phase 2 Integration (OBS Update)

When performing a release, the git workflow integrates with OBS as follows:

1. **Make changes in git:**
   ```bash
   # Update version in git repository
   vim lib/rmt.rb
   vim package/obs/rmt-server.spec
   
   # Update changelog using osc vc in package/obs/
   cd package/obs/
   osc vc
   cd ../..
   
   # Generate tarball
   make dist
   ```

2. **Sync to OBS working copy:**
   ```bash
   # Navigate to your OBS checkout
   cd ~/obs_workspace/systemsmanagement:SCC:RMT/rmt-server
   
   # Delete old tarballs
   rm rmt-server-*.tar.bz2
   
   # Copy new artifacts from git repo
   cp /path/to/rmt/package/obs/* .
   
   # Stage changes
   osc addremove
   osc status
   ```

3. **Commit after git merge:**
   ```bash
   # Only commit to OBS after the git PR is merged
   osc ci
   ```

### Changelog Format Requirements

Changelog entries must reference tracking systems:
- **Bugzilla:** `bsc#NNNNNNN`
- **Jira:** `jsc#XXX-NNN`
- **FATE:** `fate#NNNNNN`

> **BLOCKING GATE:** Before **any** submission (Factory `osc sr`, SLE/SLFO submission, IBS `osc mr`, or an agit PR to a product branch on `src.suse.de` / `src.opensuse.org`), the `package/obs/rmt-server.changes` entry for the release version **must** carry at least one of the references above. An entry without one is a blocker — SUSE maintenance/QA tooling rejects submissions with no trackable reference. Verify:
>
> ```bash
> head -20 package/obs/rmt-server.changes | grep -Eq 'bsc#[0-9]{6,7}|jsc#[A-Z]+-[0-9]+|fate#[0-9]+' && echo OK || echo "BLOCKER: no tracker reference"
> ```

Example:
```
-------------------------------------------------------------------
Mon Jun 22 10:00:00 UTC 2026 - user@suse.com

- Update to version 2.28
  * Fix authentication issue (bsc#1234567)
  * Add new feature (jsc#SCC-12345)
```

## Troubleshooting

### "Branching is not allowed because: This package is developed in git..."

This error occurs when trying to use `osc bco` on a git-migrated package:
```
Server returned an error: HTTP Error 403: Forbidden
Branching is not allowed because: This package is developed in git at
https://src.opensuse.org/systemsmanagement/rmt-server for devel project
systemsmanagement:SCC:RMT -- see https://en.opensuse.org/openSUSE:OBS_to_Git
```

**Solution:** Use the git-based fork workflow instead (see Section 1.1).

### Sync Delays

If changes don't appear between src.suse.de and src.opensuse.org:
- Wait 5-10 minutes for automatic bidirectional sync
- **Factory sync direction:** External (src.opensuse.org) → Internal (src.suse.de)
- **SLE sync direction:** Internal (src.suse.de) → External (src.opensuse.org)
- For pool/slfo-main, ensure source and target branches are correct in your PR

### SSH Permission Denied

If you get "Permission denied (publickey)" when using SSH:
- Ensure your SSH key is added to your Gitea profile
- Use the `gitea@` user (not `git@`)
- Verify the URL format: `gitea@src.opensuse.org:org/package`

## Best Practices

1. **Choose the correct repository:**
   - **Factory/Tumbleweed/Leap** → `src.opensuse.org` + `api.opensuse.org`
   - **SLE products** → `src.suse.de` + `api.suse.de` (VPN required)
2. **Always use SSH clones** with `gitea@` for packages you need to modify
3. **Update .changes file** before generating distribution tarballs
4. **Test builds** using `osc build` before submitting
5. **Fork from the correct branch** for the target product (check /pool mapping)
6. **Use agit PR format** for all pull requests from forks
7. **Include tracker references** (`bsc#NNNNNNN`, `jsc#XXX-NNN`, `fate#NNNNNN`) in changelog entries — this is a blocking gate for every submission, not a nicety
8. **Wait for sync** if working across .org and .de instances (5-10 minutes)
