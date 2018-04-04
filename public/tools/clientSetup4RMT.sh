#! /bin/sh

WGET=/usr/bin/wget
OPENSSL=/usr/bin/openssl
CP=/bin/cp
CAT=/bin/cat
CHMOD=/bin/chmod
CUT=/usr/bin/cut
GREP=/usr/bin/grep
RM=/bin/rm
SUSECONNECT=/usr/bin/SUSEConnect
GPG=/usr/bin/gpg
SUPPORTCONFIG=/etc/supportconfig.conf
SUPPORTCONFIGENTRY=VAR_OPTION_UPLOAD_TARGET
SED=/usr/bin/sed

CA_TRUSTSTORE="/etc/ssl/certs/"
CA_GEN_TRUSTSTORE_CMD="/usr/bin/c_rehash"

if [ -d "/etc/pki/trust/anchors/" ] && [ -x "/usr/sbin/update-ca-certificates" ]; then
    CA_TRUSTSTORE="/etc/pki/trust/anchors/"
    CA_GEN_TRUSTSTORE_CMD="/usr/sbin/update-ca-certificates"
elif [ -d $CA_TRUSTSTORE ] && [ -x $CA_GEN_TRUSTSTORE_CMD ]; then
    CA_GEN_TRUSTSTORE_CMD="$CA_GEN_TRUSTSTORE_CMD $CA_TRUSTSTORE"
fi

function usage()
{
    if [ -n "$1" ] ; then
        echo "$1" >&2
        echo ""
    fi

    cat << EOT >&2

  Usage: $0 <registration URL> [--regcert <url>] [--namespace <namespace>] [--regdata <filename>] [--de-register]
  Usage: $0 --host <hostname of the RMT server> [--regcert <url>] [--namespace <namespace>] [--regdata <filename>] [--de-register]
  Usage: $0 --host <hostname of the RMT server> [--fingerprint <fingerprint of server cert>] [--yes] [--regdata <filename>] [--de-register]
         configures a SLE client to register against a different registration server

  Example: $0 https://rmt.example.com/
  Example: $0 --host rmt.example.com --namespace web
  Example: $0 --host rmt.example.com --regcert http://rmt.example.com/certs/rmt.crt

  If --namespace is omitted, no namespace is set and this results in using the
  default production repositories.
EOT

exit 1
}

AUTOACCEPT=""
FINGERPRINT=""
REGDATA=""
REGURL=""
VARIABLE=""
NAMESPACE=""
DE_REGISTER=""
while true ; do
    case "$1" in
        --fingerprint) VARIABLE=FINGERPRINT;;
        --host) VARIABLE=S_HOSTNAME;;
        --regcert) VARIABLE=REGCERT;;
        --regdata) VARIABLE=REGDATA;;
        --namespace) VARIABLE=NAMESPACE;;
        --de-register) DE_REGISTER="Y";;
        --yes) AUTOACCEPT="Y";;
        "") break ;;
        -h|--help) usage;;
        https*) REGURL=$1;;
        *) usage "Unknown option $1";;
    esac
    if [ -n "$VARIABLE" ] ; then
        test -z "$2" && usage "Option $1 needs an argument"
        eval $VARIABLE=\$2
        shift
        VARIABLE=""
    fi
    shift
done

if [ `id -u` != 0 ]; then
    echo "You must be root. Abort."
    exit 1;
fi

if [ -n "$S_HOSTNAME" -a -e $SUSECONNECT ]; then
    REGURL="https://$S_HOSTNAME/"
fi

if [ -z "$REGURL" ]; then
    echo "Missing registration URL. Abort."
    usage
fi

if ! echo $REGURL | grep "^https" > /dev/null ; then
    echo "The registration URL must be a HTTPS URL. Abort."
    exit 1
fi

if ! echo $NAMESPACE | grep -E "^[a-zA-Z0-9_-]*$" > /dev/null ; then
    echo "Invalid characters in namespace. Allowed are [a-zA-Z0-9_-]. Abort."
    exit 1
fi

# BNC #516495: Changing supportconfig URL for uploading tarbals
if [ "${S_HOSTNAME}" != "" ]; then
    if [ -e "${SUPPORTCONFIG}" ]; then
        S_ENTRY="http://${S_HOSTNAME}/upload?appname=supportconfig\&file={tarball}"

        ${SED} --in-place "s|${SUPPORTCONFIGENTRY}[ \t]*=.*$|${SUPPORTCONFIGENTRY}='${S_ENTRY}'|" ${SUPPORTCONFIG}
    fi
fi

if [ -z "$REGCERT" ]; then
    CERTURL=`echo "$REGURL" | awk -F/ '{print "https://" $3 "/rmt.crt"}'`
else
    CERTURL="$REGCERT"
fi

if [ "$AUTOACCEPT" = "Y" ] && [ -z "$FINGERPRINT" ]; then
    echo "Must specify fingerprint with auto accept and auto registration. Abort."
    exit 1
fi

if [ ! -z "$REGDATA" ] && [ ! -f "$REGDATA" ]; then
    echo "Specified file $REGDATA not found."
    exit 1
fi


if [ ! -x $OPENSSL ]; then
    echo "openssl command not found. Abort."
    exit 1
fi

if [ ! -x $CP ]; then
    echo "cp command not found. Abort."
    exit 1
fi

if [ ! -x $CAT ]; then
    echo "cat command not found. Abort."
    exit 1
fi

if [ "$AUTOACCEPT" = "Y" ] && [ ! -x $CUT ]; then
    echo "cut command not found. Abort."
    exit 1
fi

if [ ! -x $GREP ]; then
    if [ -x "/bin/grep" ]; then
        GREP=/bin/grep
    else
        echo "grep command not found. Abort."
        exit 1
    fi
fi

if [ ! -x $RM ]; then
    echo "rm command not found. Abort."
    exit 1
fi

if [ ! -x $CHMOD ]; then
    echo "chmod command not found. Abort."
    exit 1
fi

if [ ! -x $SUSECONNECT ]; then
    echo "registration command not found. Abort."
    exit 1
fi

if [ -x "$SUSECONNECT" ] && [ -e /etc/zypp/credentials.d/SCCcredentials ]; then
    if [ -n "$DE_REGISTER" ]; then
        echo "De-registering system..."
        $SUSECONNECT --de-register
        $SUSECONNECT --cleanup
    else
        echo "The system is already registered. Please de-register first by calling:"
        echo "$> SUSEConnect --de-register"
        echo "$> SUSEConnect --cleanup"
        exit 1
    fi
fi

if [ ! -x $GPG ]; then
    echo "gpg command not found. Abort."
    exit 1
fi


TEMPFILE=`mktemp /tmp/rmt.crt.XXXXXX`

if [ -x $WGET ]; then
    $WGET --secure-protocol TLSv1_2 --no-verbose -q --no-check-certificate --dns-timeout 10 --connect-timeout 10 --output-document $TEMPFILE $CERTURL
    if [ $? -ne 0 ]; then
        echo "Download failed. Abort."
        exit 1
    fi
else
    echo "Binary to download the certificate not found. Please install wget. Abort."
    exit 1
fi

if [ "$AUTOACCEPT" = "Y" ]; then
    SFPRINT=`/usr/bin/openssl x509 -in $TEMPFILE -noout -fingerprint | /usr/bin/cut -d= -f2`
    MATCH=`/usr/bin/awk -vs1="$SFPRINT" -vs2="$FINGERPRINT" 'BEGIN { if ( tolower(s1) == tolower(s2) ){ print 1 } }'`
    if [ "$MATCH" != "1" ]; then
        echo "Server fingerprint: $SFPRINT and given fingerprint:  $FINGERPRINT do not match, not accepting cert. Abort."
        exit 1
    fi
else

    $OPENSSL x509 -in $TEMPFILE -text -noout

    read -p "Do you accept this certificate? [y/n] " YN

    if [ "$YN" != "Y" -a "$YN" != "y" ]; then
        echo "Abort."
        exit 1
    fi
fi

ISRES=0

if [ -d $CA_TRUSTSTORE ]; then
    $CP $TEMPFILE $CA_TRUSTSTORE/rmt-server.pem
    $CHMOD 0644 $CA_TRUSTSTORE/rmt-server.pem

    $CA_GEN_TRUSTSTORE_CMD > /dev/null
fi

rm -f $TEMPFILE

#
# check for keys on the rmt server to import
#
TMPDIR=`mktemp -d /tmp/rmtsetup-XXXXXXXX`;

KEYSURL=`echo "$REGURL" | awk -F/ '{print "https://" $3 "/repo/keys/"}'`

if [ -z $TMPDIR ]; then
    echo "Cannot create tmpdir. Abort."
    exit 1
fi

$WGET --quiet --mirror --no-parent --no-host-directories --directory-prefix $TMPDIR --cut-dirs 2 $KEYSURL

for key in `ls $TMPDIR/*.key 2>/dev/null`; do

    if [ -z $key ]; then
        continue
    fi

    if [ "$key" == "$TMPDIR/res-signingkeys.key" -a $ISRES -eq 0 ]; then
        # this is no RES system, so we do not need this key
        continue
    fi

    mkdir $TMPDIR/.gnupg

    $GPG --no-default-keyring --quiet --no-greeting --no-permission-warning --homedir  $TMPDIR/.gnupg --import $key

    $GPG --no-default-keyring --no-greeting --no-permission-warning --homedir $TMPDIR/.gnupg --list-public-keys --with-fingerprint

    if [ "$AUTOACCEPT" = "Y" ]; then
        echo "Accepting key"
        rm -rf $TMPDIR/.gnupg/
    else
        read -p "Trust and import this key? [y/n] " YN
        rm -rf $TMPDIR/.gnupg/
        if [ "$YN" != "Y" -a "$YN" != "y" ]; then
            continue ;
        fi
    fi

    rpm --import $key
done

rm -rf $TMPDIR/

echo "Client setup finished."

if [ -z "$AUTOACCEPT" ]; then
    read -p "Start the registration now? [y/n] " YN

    if [ "$YN" != "Y" -a "$YN" != "y" ]; then
        exit 0;
    fi
fi

if [ -x "$SUSECONNECT" ]; then
    if [ -n "$NAMESPACE" ]; then
        NAMESPACE="--namespace $NAMESPACE"
    fi

    echo "$SUSECONNECT --write-config --url $REGURL $NAMESPACE"
    $SUSECONNECT --write-config --url $REGURL $NAMESPACE
else
    echo "No registration client found."
    exit 1
fi

