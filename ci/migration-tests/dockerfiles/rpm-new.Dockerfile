# RMT 3.x target distro. Installs the *previous* 3.x release so the suite can
# perform a real `zypper up` to 3.1.0 and exercise the %post upgrade branch
# ($1 -eq 2), which a fresh install never reaches.
ARG BASE_IMAGE=opensuse/leap:16.0
FROM ${BASE_IMAGE}

ARG RMT_NEW_REPO=https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/16.0/
ARG RMT_PREV_VERSION=3.0.0

# rmt-server-config also exists in the Leap 16.0 distro repos under a different
# vendor; pull both from the OBS repo so the later upgrade is a plain version
# bump rather than a blocked vendor change.
RUN zypper --non-interactive --gpg-auto-import-keys addrepo --refresh "${RMT_NEW_REPO}" rmt-new \
 && zypper --non-interactive --gpg-auto-import-keys refresh \
 && zypper --non-interactive install --no-recommends --allow-vendor-change \
      "rmt-server=${RMT_PREV_VERSION}" "rmt-server-config=${RMT_PREV_VERSION}" mariadb-client \
 && zypper clean --all

CMD ["sleep", "infinity"]
