#!/bin/bash

NAME="$(basename $0)"
OUTPUT_FILE=""
TEMP_DIR=""
TEMP_PATH=""
EXPORT_SSL=0

SMT_CONFIG=${SMT_CONFIG:-/etc/smt.conf}
APACHE_CONFIG=${APACHE_CONFIG:-/etc/apache2}
SSL_PATH=${SSL_PATH:-/etc/ssl}

SMT_MYSQL_USER=""
SMT_MYSQL_PASSWORD=""
SMT_MYSQL_DATABASE=""

# -- UTILITY ------------------------------------------------------------------

function warn() { echo -ne "\033[31m$@\033[0m\n"; }

# reads a configuration parameter from smt.conf
function smt_conf_value() {
  local key=$1
  grep -oP "$key\s*=\s*\K.*" $SMT_CONFIG
}

function usage() {
  echo "Usage: $NAME [OUTPUT] [--no-ssl-export]"
  echo ""
  echo "   OUTPUT           The output file path"
  echo "   --no-ssl-export  Do not export ssl certificates to the resulting"
  echo "                    tarball"
  echo ""
  echo "Export smt configuration and data to a tarball"
  echo ""
}

# -- DATABASE -----------------------------------------------------------------

function smt_mysql() {
  local query="$1"
  mysql -u $SMT_MYSQL_USER -p$SMT_MYSQL_PASSWORD -sN -e "$query" $SMT_MYSQL_DATABASE
}

function smt_read_all_enabled_products() {
  local query="select DISTINCT(p.PRODUCTDATAID) from Products p
                join ProductCatalogs pc on p.ID = pc.PRODUCTID
                join Catalogs c on c.ID = pc.CATALOGID

                where c.DOMIRROR = 'Y'
                and c.SRC='S'
                and c.STAGING = 'N'"

  smt_mysql "$query" | awk '{print $1}'
}

function smt_read_all_enabled_repos() {
  local query="select c.CATALOGID from Catalogs c
                 where c.DOMIRROR = 'Y'
                 and c.SRC='S'
                 and c.STAGING = 'N'"

  smt_mysql "$query" | awk '{print $1}'
}


function smt_read_all_enabled_custom_repos() {
  local query="select p.PRODUCTDATAID, c.NAME, c.EXTURL from Products p
                 join ProductCatalogs pc on p.ID = pc.PRODUCTID
                 join Catalogs c on c.ID = pc.CATALOGID

                 where c.DOMIRROR='Y'
                 and c.SRC='C'
                 and c.STAGING = 'N'"

  smt_mysql "$query" | awk '{print $1 "," $2 "," $3}'
}

function smt_read_all_systems() {
  local query="select c.GUID, c.SECRET, c.HOSTNAME from Clients c"

  smt_mysql "$query" | awk '{print $1 "," $2 "," $3}'
}

function smt_read_all_activations() {
  local query="select r.GUID, p.PRODUCTDATAID from Registration r
                 join Products p on p.ID = r.PRODUCTID"

  smt_mysql "$query" | awk '{print $1 "," $2}'
}

# -- STEPS --------------------------------------------------------------------

function step_init_environment() {
  local dburl=""

  TEMP_DIR="$(mktemp -p /tmp -d ${NAME}.XXXXXXXX)"
  TEMP_PATH="${TEMP_DIR}/smt-export"
  mkdir $TEMP_PATH

  SMT_MYSQL_USER=$(smt_conf_value "user")
  SMT_MYSQL_PASSWORD=$(smt_conf_value "pass")

  dburl=$(smt_conf_value "config")
  SMT_MYSQL_DATABASE=$(echo "$dburl" | grep -oP '(?<=(database=)).*(?=(;host))')
}

function step_export_smt() {
  local temp_ssl_path="$TEMP_PATH/ssl"
  local yast_migration_pem="YaST_Default_CA__smt-migration_.pem"

  # copy all configurations
  cp $SMT_CONFIG $TEMP_PATH/smt.conf

  smt_read_all_enabled_products > $TEMP_PATH/enabled_products.csv
  smt_read_all_enabled_repos > $TEMP_PATH/enabled_repos.csv
  smt_read_all_enabled_custom_repos > $TEMP_PATH/enabled_custom_repos.csv
  smt_read_all_systems > $TEMP_PATH/systems.csv
  smt_read_all_activations > $TEMP_PATH/activations.csv

  if [[ $EXPORT_SSL == 0 ]]; then
    warn "Warning:"
    warn "Your server SSL certificates have been exported. Make sure to keep the tarball safe!"
    warn "You can disable the export of SSL certificates by adding --no-ssl-export"
    warn "to this command."

    # copy ssl files
    mkdir $temp_ssl_path

    cp $SSL_PATH/openssl.cnf $temp_ssl_path
    cp $SSL_PATH/ca-bundle.pem $temp_ssl_path
    cp -r $SSL_PATH/servercerts $temp_ssl_path

    if [ -f $SSL_PATH/certs/$yast_migration_pem ]; then
      cp $SSL_PATH/certs/$yast_migration_pem $temp_ssl_path
    fi
  fi

  cp /etc/hostname $TEMP_PATH/
}

function step_create_tarball() {
  if [[ "$OUTPUT_FILE" == "" ]]; then
    local stamp=$(date +%m%d%Y%H%M%S)
    OUTPUT_FILE="$PWD/smt-export.${stamp}.tar.gz"
  fi

  pushd $TEMP_DIR &> /dev/null
  tar -zcvf $OUTPUT_FILE smt-export 1> /dev/null
  popd &> /dev/null
}

function step_cleanup_environment() {
  rm -r $TEMP_DIR
}

# -- MAIN ---------------------------------------------------------------------

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$1" == "--no-ssl-export" ]]; then
  EXPORT_SSL=1
  shift
fi

if [[ "$1" != "" ]]; then
  OUTPUT_FILE="$1"
fi

if [[ "$2" == "--no-ssl-export" ]]; then
  EXPORT_SSL=1
fi

step_init_environment
step_export_smt
step_create_tarball
step_cleanup_environment
