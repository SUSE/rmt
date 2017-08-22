FROM opensuse/amd64:42.3

RUN zypper --non-interactive install --no-recommend timezone \
gcc libffi48-devel make git-core zlib-devel libxml2-devel libxslt-devel \
ruby2.4-rubygem-bundler ruby2.4-rubygem-mini_portile2 ruby2.4-rubygem-nio4r \
ruby2.4-rubygem-websocket-driver ruby2.4-devel ruby2.4-rubygem-pg

RUN bundle config build.nokogiri --use-system-libraries

ENV RAILS_ENV production

COPY . /srv/www/rmt/
WORKDIR /srv/www/rmt/

RUN bundler.ruby2.4

EXPOSE 3000

CMD bundle exec rails s -b 0.0.0.0
