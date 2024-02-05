#!BuildTag: rmt-ci-container
#!UseOBSRepositories
FROM opensuse/leap:15.5

RUN zypper --non-interactive in make chrpath fdupes gcc libcurl-devel libffi-devel libmysqlclient-devel \
                                libxml2-devel libxslt-devel nodejs sqlite-devel ruby2.5-rubygem-ronn    \
                                rpmbuild systemd gzip tar bzip2 vim curl wget ruby2.5 ruby2.5-devel     \
                                ruby2.5-rubygem-bundler

# Set default bundler to the required version. This way we can easily update ruby in case required
RUN update-alternatives --install /usr/bin/bundle bundle /usr/bin/bundle.ruby2.5 5 && \
    update-alternatives --install /usr/bin/bundler bundler /usr/bin/bundler.ruby2.5 5

VOLUME /usr/src/rmt-server
VOLUME /usr/

ARG SCC_USERNAME
ARG SCC_PASSWORD

# Prepare ruby environment
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

# Add rmt ci/development scripts
RUN mkdir -p /usr/src/rmt-server /usr/local/bin

COPY rmt-build-rpm /usr/local/bin/
COPY rmt-configure /usr/local/bin/
COPY rmt-console /usr/local/bin/
COPY rmt-run-feature-tests /usr/local/bin/

WORKDIR /usr/src/rmt-server
