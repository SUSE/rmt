FROM registry.scc.suse.de/connect_sp2

RUN zypper ar http://download.suse.de/ibs/Devel:/SCC:/SMT-NG/openSUSE_Leap_42.3/Devel:SCC:SMT-NG.repo
RUN zypper --gpg-auto-import-keys ref
RUN zypper --non-interactive install --no-recommend timezone \
ruby2.4-rubygem-bundler ruby2.4-rubygem-mini_portile2 ruby2.4-rubygem-nio4r ruby2.4-rubygem-nokogiri \
ruby2.4-rubygem-puma ruby2.4-rubygem-sqlite3 ruby2.4-rubygem-websocket-driver ruby2.4-devel

ADD . /srv/www/smt-ng/
RUN cd /srv/www/smt-ng/ && sed -i s/https/http/ Gemfile
RUN cd /srv/www/smt-ng/ && bundler.ruby2.4
RUN cd /srv/www/smt-ng/ && rake secret > .secret

CMD cd /srv/www/smt-ng/ && RAILS_ENV=production SECRET_KEY_BASE=$(cat .secret) rails s
