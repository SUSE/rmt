# RMT 2.x installed from its published RPM, on the distro it shipped for.
#
# 2.28 binaries currently live in systemsmanagement:SCC:RMT/15.6 (the pre-split
# location); systemsmanagement:SCC:RMT2 publishes the SLE_15_SP6 flavour.
ARG BASE_IMAGE=opensuse/leap:15.6
FROM ${BASE_IMAGE}

ARG RMT_OLD_REPO=https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/15.6/
ARG RMT_OLD_VERSION=

RUN zypper --non-interactive --gpg-auto-import-keys addrepo --refresh "${RMT_OLD_REPO}" rmt-old \
 && zypper --non-interactive --gpg-auto-import-keys refresh \
 && zypper --non-interactive install --no-recommends \
      "rmt-server${RMT_OLD_VERSION:+=${RMT_OLD_VERSION}}" mariadb-client \
 && zypper clean --all

CMD ["sleep", "infinity"]
