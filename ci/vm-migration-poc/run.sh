#!/usr/bin/env bash
# Host-side driver: copy the migration test into a VM and run it over ssh.
#
#   ci/vm-migration-poc/run.sh <ssh-target>
#   ci/vm-migration-poc/run.sh root@<ip>
#   VM=<domain> ci/vm-migration-poc/run.sh              # resolve the IP via virsh
#
# Deliberately does NOT manage VM lifecycle -- it does not define, start, or
# stop anything. Bring a VM up however you normally do, then point this at it.
#
# Targets SLES 15 SP7, which is the one distribution with both rmt-server-2.28
# (systemsmanagement:SCC:RMT2) and rmt-server-3.1.0 (systemsmanagement:SCC:RMT)
# published, so the test can do a real zypper upgrade between them.
#
# The RMT packages are fetched HERE and shipped in, rather than having the guest
# add the OBS repos: a registered SLES VM can generally reach updates.suse.com
# but not necessarily download.opensuse.org. Everything else the packages need
# (ruby2.5, ruby3.4, nginx) comes from the guest's own SUSE repos, so the VM
# still has to be registered.
#
# Env:
#   VM=<domain>     resolve the ssh target from libvirt instead of passing one
#   SKIP_FETCH=1    reuse the RPMs already in .rpms/ instead of re-downloading
#   SKIP_REFRESH=1  skip the guest's `zypper refresh` preflight. That refresh
#                   covers every repository a registered SLES has (~40) and can
#                   dominate the runtime; skip it when re-running against a
#                   guest you already refreshed once.
#   KEEP=1          leave the copied files in /root on the guest

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
VM="${VM:-}"
OBS_BASE='https://download.opensuse.org/repositories/systemsmanagement:/SCC:'
SLE_DIR="${SLE_DIR:-SLE_15_SP7}"
RPM_CACHE="$HERE/.rpms"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10)

die() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }
log() { printf '\033[34m==>\033[0m %s\n' "$1"; }

# Pick the newest build of an exact package name out of an OBS directory index.
# Matching on "<name>-<digit>" keeps rmt-server from also matching
# rmt-server-config and rmt-server-pubcloud.
newest_rpm() { # <index-html> <package-name>
  grep -oE "${2}-[0-9][^\"'<>]*\.x86_64\.rpm" "$1" | sort -u -V | tail -1
}

fetch_stream() { # <obs-project> <local-subdir>
  local project="$1" dest="$RPM_CACHE/$2" index
  mkdir -p "$dest"
  index="$(mktemp)"
  # -L matters: download.opensuse.org 302-redirects the larger RPMs to a mirror,
  # and without it curl writes an empty file and still exits 0. -f turns HTTP
  # errors into a non-zero exit.
  curl -fsSL --max-time 60 "$OBS_BASE/$project/$SLE_DIR/x86_64/" -o "$index" \
    || die "could not list $project/$SLE_DIR"

  local pkg file
  for pkg in rmt-server rmt-server-config; do
    file="$(newest_rpm "$index" "$pkg")"
    [[ -n "$file" ]] || die "no $pkg build found in $project/$SLE_DIR"
    if [[ -s "$dest/$file" ]] && rpm -qp "$dest/$file" >/dev/null 2>&1; then
      log "  have $file"
    else
      log "  fetching $file"
      curl -fsSL --max-time 300 -o "$dest/$file" \
        "$OBS_BASE/$project/$SLE_DIR/x86_64/$file" || die "download failed: $file"
      # An empty or truncated RPM would otherwise be silently ignored by zypper,
      # which then resolves rmt-server from the distro repos instead.
      rpm -qp "$dest/$file" >/dev/null 2>&1 \
        || die "downloaded file is not a valid RPM: $dest/$file"
    fi
  done
  rm -f "$index"
}

# --------------------------------------------------------- resolve the target --

if [[ -z "$TARGET" && -n "$VM" ]]; then
  log "looking up an address for domain '$VM'"
  # The default source only reports addresses libvirt itself handed out, and
  # returns nothing for a guest on a network it does not run DHCP for. Fall back
  # to the lease file and then the guest agent before giving up.
  ip=''
  for src in '' lease agent arp; do
    ip="$(virsh -c qemu:///system domifaddr "$VM" ${src:+--source "$src"} 2>/dev/null \
          | awk '$1 != "lo" && /ipv4/ {split($NF, a, "/"); print a[1]; exit}')"
    [[ -n "$ip" ]] && break
  done
  [[ -n "$ip" ]] || die "could not determine an IP for '$VM' -- is it running? (virsh -c qemu:///system domifaddr $VM --source lease)"
  TARGET="root@$ip"
  log "resolved $VM -> $TARGET"
fi

[[ -n "$TARGET" ]] || die "usage: $0 <ssh-target>   (or VM=<domain> $0)"
[[ -f "$HERE/baseline-2.28.sql" ]] || die "missing $HERE/baseline-2.28.sql"

# ------------------------------------------------------------ fetch the RPMs --

# Only the 3.x packages are fetched. The 2.x baseline comes from the guest's own
# SLE-Module-Server-Applications, which ships rmt-server 2.28 -- that is what a
# customer upgrading from SP7's supported RMT actually starts from, and it is
# more faithful than the OBS RMT2 rebuild.
if [[ "${SKIP_FETCH:-0}" == '1' ]]; then
  log 'SKIP_FETCH=1 -- reusing the cached RPMs'
  [[ -d "$RPM_CACHE/v3" ]] || die "no cached RPMs in $RPM_CACHE/v3"
else
  log "fetching rmt-server 3.x from systemsmanagement:SCC:RMT/$SLE_DIR"
  fetch_stream RMT v3
fi

# Keep only the newest build, so a stale cached RPM cannot be picked up by the
# guest's glob.
for pkg in rmt-server rmt-server-config; do
  # shellcheck disable=SC2012
  ls "$RPM_CACHE/v3"/${pkg}-[0-9]*.x86_64.rpm 2>/dev/null | sort -V | head -n -1 \
    | while read -r stale; do log "  pruning stale $(basename "$stale")"; rm -f "$stale"; done
done
log "v3: $(cd "$RPM_CACHE/v3" && echo *.rpm)"

# -------------------------------------------------------------- run it -------

log "checking ssh to $TARGET"
ssh "${SSH_OPTS[@]}" "$TARGET" 'test "$(id -u)" -eq 0' \
  || die "cannot ssh to $TARGET as root (key auth required; password prompts will not work here)"

log 'copying the test, the baseline and the RPMs into the VM'
ssh "${SSH_OPTS[@]}" "$TARGET" 'rm -rf /root/rmt-rpms && mkdir -p /root/rmt-rpms' || die 'could not prepare /root on the guest'
scp "${SSH_OPTS[@]}" -q "$HERE/guest-migration-test.sh" "$HERE/baseline-2.28.sql" "$TARGET:/root/" \
  || die 'scp failed'
scp "${SSH_OPTS[@]}" -qr "$RPM_CACHE/v3" "$TARGET:/root/rmt-rpms/" \
  || die 'scp of the RPMs failed'

mkdir -p "$HERE/artifacts"
LOG="$HERE/artifacts/last-run.log"

log "running the migration test inside the VM (full log: $LOG)"
echo
# -tt so systemctl/journalctl output is not buffered until the end.
ssh "${SSH_OPTS[@]}" -tt "$TARGET" \
  "chmod +x /root/guest-migration-test.sh && BASELINE=/root/baseline-2.28.sql RPM_DIR=/root/rmt-rpms SKIP_REFRESH=${SKIP_REFRESH:-0} /root/guest-migration-test.sh" \
  2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}

if [[ "${KEEP:-0}" != '1' ]]; then
  ssh "${SSH_OPTS[@]}" "$TARGET" 'rm -rf /root/rmt-rpms /root/guest-migration-test.sh /root/baseline-2.28.sql' 2>/dev/null
fi

echo
if (( rc == 0 )); then
  log 'VM migration PoC passed'
else
  log "VM migration PoC failed (exit $rc)"
fi
exit $rc
