#!/usr/bin/env bash

# RMT-Server Automated Release Script (Idempotent Version)
# Orchestrates Phase 1-5 of the rmt-release-management skill.

set -e

VERSION=""
DRY_RUN=false
OBS_PATH=""
STREAMS=""
RMT_PATH=$(pwd)

usage() {
  echo "Usage: $0 --version <X.Y.Z> --obs-path <PATH> [--dry-run] [--streams \"STREAM1 STREAM2\"]"
  exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --version) VERSION="$2"; shift ;;
    --obs-path) OBS_PATH="$2"; shift ;;
    --streams) STREAMS="$2"; shift ;;
    --dry-run) DRY_RUN=true ;;
    *) usage ;;
  esac
  shift
done

if [[ -z "$VERSION" || -z "$OBS_PATH" ]]; then usage; fi

# Command simulation for dry-run
run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Executing: $@"
  else
    echo "Executing: $@"
    "$@"
  fi
}

echo "Starting idempotent automated release for version $VERSION..."

# Phase 1: Local Development
echo "--- Phase 1: Local Development ---"
mkdir -p public/repo

CURRENT_RUBY_VER=$(grep "VERSION ||=" lib/rmt.rb | sed "s/.*'\(.*\)'.*/\1/")
if [ "$CURRENT_RUBY_VER" == "$VERSION" ]; then
  echo "Version already set to $VERSION in lib/rmt.rb. Skipping sed."
else
  run_cmd sed -i "s/VERSION ||= '.*'/VERSION ||= '$VERSION'/" lib/rmt.rb
fi

CURRENT_SPEC_VER=$(grep "^Version:" package/obs/rmt-server.spec | awk '{print $2}')
if [ "$CURRENT_SPEC_VER" == "$VERSION" ]; then
  echo "Version already set to $VERSION in rmt-server.spec. Skipping sed."
else
  run_cmd sed -i "s/^Version:.*/Version:        $VERSION/" package/obs/rmt-server.spec
fi

run_cmd docker compose build rmt
run_cmd make dist

# Phase 2: OBS Integration
echo "--- Phase 2: OBS Integration ---"
cd "$OBS_PATH"
# Find and remove old tarballs (only if they aren't the target version)
OLD_TARBALLS=$(ls rmt-server-*.tar.bz2 2>/dev/null | grep -v "rmt-server-$VERSION.tar.bz2" || true)
if [[ -n "$OLD_TARBALLS" ]]; then
  for TB in $OLD_TARBALLS; do
    run_cmd rm "$TB"
  done
fi

run_cmd cp "$RMT_PATH/package/obs/"* .
run_cmd osc -A https://api.opensuse.org addremove
run_cmd osc -A https://api.opensuse.org status

# Local build can be skipped if already verified
echo "Local build (osc build) is resource intensive. Skipping in automation unless forced."

# Phase 3: GitHub Release
echo "--- Phase 3: GitHub Release ---"
cd "$RMT_PATH"
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Tag v$VERSION already exists locally. Skipping tagging."
else
  run_cmd git tag -a "v$VERSION" -m "Release v$VERSION"
fi

if git ls-remote --tags origin "v$VERSION" | grep -q "v$VERSION"; then
  echo "Tag v$VERSION already exists on origin. Skipping push."
else
  run_cmd git push origin "v$VERSION"
fi

# Phase 4: Downstream Distribution
echo "--- Phase 4: Downstream Distribution ---"
cd "$OBS_PATH"

if [[ -n "$STREAMS" ]]; then
  echo "Using explicitly provided streams: $STREAMS"
  MAINTAINED_STREAMS=$STREAMS
else
  echo "Identifying maintained streams via IBS..."
  MAINTAINED_STREAMS=$(osc -A https://api.suse.de maintained rmt-server | awk -F'/' '{print $1}')
fi

for STREAM in $MAINTAINED_STREAMS; do
  echo "Submitting request for stream: $STREAM"

  # Try maintenance request first, fall back to submit request if it fails
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Executing: osc -A https://api.suse.de mr Devel:SCC:RMT rmt-server $STREAM"
  else
    echo "Attempting maintenance request (mr) for $STREAM..."
    if osc -A https://api.suse.de mr Devel:SCC:RMT rmt-server "$STREAM" 2>&1; then
      echo "✓ Maintenance request submitted successfully for $STREAM"
    else
      echo "⚠ Maintenance request failed for $STREAM, retrying with submit request (sr)..."
      if osc -A https://api.suse.de sr Devel:SCC:RMT rmt-server "$STREAM" 2>&1; then
        echo "✓ Submit request submitted successfully for $STREAM"
      else
        echo "✗ Both mr and sr failed for $STREAM. Please submit manually."
      fi
    fi
  fi
done

# Phase 5: Helm Chart (Manual Steps Summary)
echo "--- Phase 5: Container & Helm Chart ---"
echo "BCI build is automated. Finalize Helm Chart update in SUSE/helm-charts."
echo "Update Chart.yaml: version, appVersion ($VERSION), BuildTag."
echo "Notify #proj-bci on Slack after PR merge."

echo "Automated release process complete (Dry-run: $DRY_RUN)."
