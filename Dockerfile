FROM registry.scc.suse.de/connect_sp2

RUN zypper ar --ref http://download.suse.de/ibs/Devel:/SCC:/SMT-NG/openSUSE_Leap_42.3/Devel:SCC:SMT-NG.repo
RUN zypper --gpg-auto-import-keys ref
RUN zypper --non-interactive install --no-recommend timezone \
ruby2.4-rubygem-bundler ruby2.4-rubygem-mini_portile2 ruby2.4-rubygem-nio4r ruby2.4-rubygem-nokogiri \
ruby2.4-rubygem-puma ruby2.4-rubygem-sqlite3 ruby2.4-rubygem-websocket-driver ruby2.4-devel ruby2.4-rubygem-pg

WORKDIR /srv/www/potato/

RUN ruby -e 'require "securerandom"; puts SecureRandom.hex(64)' > .secret

CMD bash -c 'bundler.ruby2.4 --system --without with_c_extensions && rm -rf .bundle/config && rails db:migrate && rails s -P /tmp/rmt.pid'
