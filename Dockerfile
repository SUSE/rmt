FROM registry.scc.suse.de/connect_sp2

RUN zypper ar --ref http://download.suse.de/ibs/Devel:/SCC:/SMT-NG/openSUSE_Leap_42.3/Devel:SCC:SMT-NG.repo
RUN zypper --gpg-auto-import-keys ref
RUN zypper --non-interactive install --no-recommend timezone \
ruby2.4-rubygem-bundler ruby2.4-rubygem-mini_portile2 ruby2.4-rubygem-nio4r ruby2.4-rubygem-nokogiri \
ruby2.4-rubygem-puma ruby2.4-rubygem-sqlite3 ruby2.4-rubygem-websocket-driver ruby2.4-devel

ADD . /srv/www/smt-ng/
WORKDIR /srv/www/smt-ng/

ENV RAILS_ENV=test
ENV BROKEN_DOCKER_SSL=true

RUN bundler.ruby2.4
RUN rake secret > .secret

CMD rails s
