FROM opensuse/tumbleweed:latest

RUN zypper --non-interactive install --no-recommends \
        timezone wget gcc-c++ libffi-devel git-core zlib-devel \
        libxml2-devel libxslt-devel cron libmariadb-devel mariadb-client sqlite3-devel \
        vim ruby3.4 ruby3.4-devel ruby3.4-rubygem-bundler SUSEConnect jq bzip2 gzip \
        make automake autoconf binutils glibc-devel libyaml-devel && \
    update-alternatives --install /usr/bin/bundle bundle /usr/bin/bundle.ruby3.4 5 && \
    update-alternatives --install /usr/bin/bundler bundler /usr/bin/bundler.ruby3.4 5

WORKDIR /srv/www/rmt/

COPY Gemfile* /srv/www/rmt/

RUN bundle.ruby3.4 config build.nokogiri --use-system-libraries && \
    bundle install

COPY . /srv/www/rmt/

RUN sed -i 's/#!\/usr\/bin\/env ruby/#!\/usr\/bin\/ruby.ruby3.4/g' /srv/www/rmt/bin/rmt-cli && \
    ln -s /srv/www/rmt/bin/rmt-cli /usr/bin && \
    mkdir -p /var/lib/rmt/ && \
    mkdir -p /srv/www/rmt/public/repo && \
    groupadd -r nginx && \
    useradd -g nginx -s /bin/false -r -c "user for RMT" _rmt && \
    chown _rmt /srv/www/rmt/public/repo && \
    chown _rmt /srv/www/rmt/public/suma

RUN uuidgen > /var/lib/rmt/system_uuid

EXPOSE 4224

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "4224"]
