FROM opensuse/amd64:42.3

RUN zypper --non-interactive install --no-recommend timezone \
gcc gcc-c++ libffi-devel make git-core zlib-devel libxml2-devel libxslt-devel cron libmariadb-devel \
mariadb-client vim \
ruby2.4 ruby2.4-devel ruby2.4-rubygem-bundler

RUN zypper --non-interactive install -t pattern devel_basis
RUN bundle config build.nokogiri --use-system-libraries

ENV RAILS_ENV production

COPY . /srv/www/rmt/
WORKDIR /srv/www/rmt/

RUN bundle

RUN printf "database: &database\n\
  host: <%%= ENV['MYSQL_HOST'] %%>\n\
  username: <%%= ENV['MYSQL_USER'] %%>\n\
  password: <%%= ENV['MYSQL_PASSWORD'] %%>\n\
  database: <%%= ENV['MYSQL_DATABASE'] %%>\n\
database_development:\n\
  <<: *database\n\
  database: <%%= ENV['MYSQL_DATABASE'] %%>\n" >> config/rmt.local.yml

EXPOSE 4224

CMD bundle exec rails s -b 0.0.0.0 -p 4224
