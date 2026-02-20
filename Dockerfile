FROM registry.opensuse.org/opensuse/leap:16.0

RUN zypper --non-interactive install --no-recommends ruby3.4 ruby3.4-devel

RUN zypper --non-interactive install libffi-devel libmysqlclient-devel libxml2-devel \
                        libxslt-devel rpmbuild systemd gzip tar bzip2 nodejs sqlite-devel \
                        make chrpath fdupes gcc libcurl-devel libyaml-devel

WORKDIR /srv/www/rmt/

COPY Gemfile Gemfile.lock /srv/www/rmt/

RUN bundle install

COPY . /srv/www/rmt/

RUN ln -s /srv/www/rmt/bin/rmt-cli /usr/bin && \
    mkdir /var/lib/rmt/ && \
    groupadd -r nginx && \
    useradd -g nginx -s /bin/false -r -c "user for RMT" _rmt && \
    chown _rmt /srv/www/rmt/public/repo && \
    chown _rmt /srv/www/rmt/public/suma

RUN uuidgen > /var/lib/rmt/system_uuid

EXPOSE 4224

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "4224"]
