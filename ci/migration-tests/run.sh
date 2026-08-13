#!/usr/bin/env bash
# RMT migration test runner.
#
#   ci/migration-tests/run.sh                 # every suite
#   ci/migration-tests/run.sh 01 04           # selected suites
#   ci/migration-tests/run.sh --baseline      # (re)generate the 2.x baseline dump
#   ci/migration-tests/run.sh --clean         # tear the stack down
#
# Environment:
#   BASELINE_REF   git ref to migrate from            (default v2.28)
#   RMT_RPM_DIR    dir of locally built rmt-server RPMs for suite 02
#   KEEP_UP=1      leave containers running afterwards

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

usage() { sed -n '2,16p' "$0" | sed 's/^# \?//'; exit "${1:-0}"; }

cleanup() {
  if [[ "${KEEP_UP:-0}" == '1' ]]; then
    log 'KEEP_UP=1 — leaving containers running'
  else
    log 'tearing down the migration-test stack'
    compose down --remove-orphans --volumes >/dev/null 2>&1 || true
  fi
}

SUITES=()
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage ;;
    --clean)
      compose down --remove-orphans --volumes
      git -C "$REPO_ROOT" worktree prune
      rm -rf "$REPO_ROOT/.migtest" "$ARTIFACTS_DIR"/*
      log 'cleaned'; exit 0 ;;
    --baseline)
      exec "$MIGTEST_DIR/lib/baseline.sh" --force ;;
    [0-9][0-9]) SUITES+=("$arg") ;;
    *) die "unknown argument '$arg' (try --help)" ;;
  esac
done

if (( ${#SUITES[@]} == 0 )); then
  SUITES=(01 02 03 04)
fi

require_cmd docker
docker compose version >/dev/null 2>&1 || die 'docker compose v2 is required'

mkdir -p "$ARTIFACTS_DIR"
trap cleanup EXIT

# Suite 01 needs a baseline dump; generate it on demand.
if [[ " ${SUITES[*]} " == *' 01 '* && ! -f "$(baseline_path)" ]]; then
  log "no baseline at $(basename "$(baseline_path)") yet — generating one"
  "$MIGTEST_DIR/lib/baseline.sh"
fi

declare -A RESULT
overall=0

for s in "${SUITES[@]}"; do
  script=$(ls "$MIGTEST_DIR/suites/${s}-"*.sh 2>/dev/null | head -1)
  [[ -n "$script" ]] || die "no suite matching '$s'"

  echo
  printf '%s%s%s\n' "$C_BLU" "$(printf '=%.0s' {1..72})" "$C_OFF"
  printf '%s %s%s\n'  "$C_BLU" "$(basename "$script")" "$C_OFF"
  printf '%s%s%s\n' "$C_BLU" "$(printf '=%.0s' {1..72})" "$C_OFF"

  if bash "$script"; then
    RESULT[$s]='PASS'
  else
    RESULT[$s]='FAIL'
    overall=1
  fi
done

echo
printf '%s%s%s\n' "$C_BLU" "$(printf '=%.0s' {1..72})" "$C_OFF"
echo 'migration test summary'
for s in "${SUITES[@]}"; do
  name=$(basename "$(ls "$MIGTEST_DIR/suites/${s}-"*.sh | head -1)" .sh)
  if [[ "${RESULT[$s]}" == 'PASS' ]]; then
    printf '  %sPASS%s  %s\n' "$C_GRN" "$C_OFF" "$name"
  else
    printf '  %sFAIL%s  %s\n' "$C_RED" "$C_OFF" "$name"
  fi
done
echo "artifacts: ${ARTIFACTS_DIR#"$REPO_ROOT"/}"

exit $overall
