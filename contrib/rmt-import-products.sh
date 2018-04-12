#!/bin/bash

NAME="$(basename $0)"

SMT_TAR_FILE=""
SMT_TAR_DIR="smt-export"

# -- UTILITY ------------------------------------------------------------------
function warn() { echo -ne "\033[31m$@\033[0m\n"; }
function step() { echo -ne "$@...\n"; }
function action() { echo -ne " \033[32m::\033[0m $@\n"; }

function tar_read_file() {
  local path="$SMT_TAR_DIR/$1"

  tar xfO $SMT_TAR_FILE $path
}

function tar_has_file() {
  local path="$SMT_TAR_DIR/$1"

  if tar tf $SMT_TAR_FILE $path &> /dev/null; then
    return 0
  fi
  return 1
}

function usage() {
  echo "Usage: $NAME TARBALL"
  echo ""
  echo "    TARBALL              Tarball created by the 'smt-export' script."
  echo ""
  echo "Import and enable products from 'smt-export' tarball to rmt."
}

# -- STEPS --------------------------------------------------------------------
function step_validate_environment() {
  if [[ ! -f $SMT_TAR_FILE ]]; then
    usage
    exit 0
  fi

  if ! which rmt-cli &> /dev/null; then
    warn "Fatal:"
    warn "No rmt commandline client found! Make sure that rmt-server is"
    warn "installed and running before importing products."
    exit 1
  fi
}

function step_enable_products() {
  local enabled=0

  if ! tar_has_file "enabled_products.csv"; then
    warn "Fatal:"
    warn "Could not read products from $SMT_TAR_FILE!"
    exit 1
  fi

  step "Enableing products from exported configuration"
  while read product; do
    if ! rmt-cli products enable $product; then
      action "failed to enable product with ID $product"
    else
      enabled=$((enabled + 1))
    fi
  done < <(tar_read_file "enabled_products.csv")
  action "$enabled products enabled!"

}

# -- MAIN ---------------------------------------------------------------------

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "" ]]; then
  usage
  exit 0
fi

SMT_TAR_FILE="$1"

step_validate_environment
step_enable_products
