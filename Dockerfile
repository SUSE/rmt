FROM opensuse/leap:15.3

RUN zypper --non-interactive install --no-recommends \
        timezone wget gcc-c++ libffi-devel git-core zlib-devel \
        libxml2-devel libxslt-devel cron libmariadb-devel mariadb-client sqlite3-devel \
        vim ruby2.5 ruby2.5-devel ruby2.5-rubygem-bundler SUSEConnect && \
    zypper --non-interactive install -t pattern devel_basis && \
    update-alternatives --install /usr/bin/bundle bundle /usr/bin/bundle.ruby2.5 5 && \
    update-alternatives --install /usr/bin/bundler bundler /usr/bin/bundler.ruby2.5 5

WORKDIR /srv/www/rmt/

COPY Gemfile* /srv/www/rmt/

RUN bundle.ruby2.5 config build.nokogiri --use-system-libraries && \
    bundle install

COPY . /srv/www/rmt/

RUN sed -i 's/#!\/usr\/bin\/env ruby/#!\/usr\/bin\/ruby.ruby2.5/g' /srv/www/rmt/bin/rmt-cli && \
    ln -s /srv/www/rmt/bin/rmt-cli /usr/bin && \
    mkdir /var/lib/rmt/ && \
    groupadd -r nginx && \
    useradd -g nginx -s /bin/false -r -c "user for RMT" _rmt && \
    chown _rmt /srv/www/rmt/public/repo && \
    chown _rmt /srv/www/rmt/public/suma

EXPOSE 4224

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "4224"]
