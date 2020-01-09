FROM opensuse/amd64:42.3

RUN zypper --non-interactive install --no-recommend timezone wget \
    gcc-c++ libffi-devel git-core zlib-devel libxml2-devel libxslt-devel cron libmariadb-devel \
    mariadb-client vim &&\
    zypper --non-interactive install -t pattern devel_basis

RUN zypper --gpg-auto-import-keys ar -f https://download.opensuse.org/repositories/systemsmanagement:/SCC:/rubies/openSUSE_Leap_42.3/systemsmanagement:SCC:rubies.repo  &&\
    zypper --non-interactive --gpg-auto-import-keys ref &&\
    zypper --non-interactive install ruby2.5 ruby2.5-devel ruby2.5-rubygem-bundler

ENV DOCKERIZE_VERSION v0.6.0
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

RUN bundle.ruby2.5 config build.nokogiri --use-system-libraries

ENV RAILS_ENV production

COPY . /srv/www/rmt/
WORKDIR /srv/www/rmt/

RUN sed -i 's/#!\/usr\/bin\/env ruby/#!\/usr\/bin\/ruby.ruby2.5/g' /srv/www/rmt/bin/rmt-cli
RUN ln -s /srv/www/rmt/bin/rmt-cli /usr/bin
RUN bundle

# Setup permissions to run rmt-cli
RUN groupadd -r nginx
RUN useradd -g nginx -s /bin/false -r -c "user for RMT" _rmt
RUN chown _rmt /srv/www/rmt/public/repo 

RUN printf "database: &database\n\
  host: <%%= ENV['MYSQL_HOST'] %%>\n\
  username: <%%= ENV['MYSQL_USER'] %%>\n\
  password: <%%= ENV['MYSQL_PASSWORD'] %%>\n\
  database: <%%= ENV['MYSQL_DATABASE'] %%>\n\
database_development:\n\
  <<: *database\n\
  database: <%%= ENV['MYSQL_DATABASE'] %%>\n\
cli:\n\
  user: root\n\
  group: root\n\
scc:\n\
  username: <%%= ENV['SCC_USERNAME'] %%>\n\
  password: <%%= ENV['SCC_PASSWORD'] %%>\n\
" >> config/rmt.local.yml

EXPOSE 4224

CMD dockerize -wait tcp://$MYSQL_HOST:3306 -timeout 60s true && bundle.ruby2.5 exec rails s -b 0.0.0.0 -p 4224
