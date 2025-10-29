NAME          = rmt-server
VERSION       = $(shell ruby -e 'require "./lib/rmt.rb"; print RMT::VERSION')

.PHONY: clean man dist build-tarball database-up server shell console public_repo public_perm

all:
	@:

clean:
	rm -f rmt-cli.8*
	rm -rf package/obs/*.tar.bz2
	rm -rf $(NAME)-$(VERSION)/

man:
	ronn --roff --pipe --manual RMT MANUAL.md > rmt-cli.8 && gzip -f rmt-cli.8
	mv rmt-cli.8.gz package/obs

dist:
	docker compose run -it -v $(PWD):/srv/www/rmt --rm rmt make build-tarball

build-tarball: clean man
	@mkdir -p $(NAME)-$(VERSION)/

	@cp -r app $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/bin
	@cp -r bin/rails bin/rmt-cli $(NAME)-$(VERSION)/bin
	@cp -r bin/rmt-data-import $(NAME)-$(VERSION)/bin
	@cp -r bin/rmt-test-regsharing $(NAME)-$(VERSION)/bin
	@cp -r bin/rmt-manual-instance-verify $(NAME)-$(VERSION)/bin
	@cp -r config $(NAME)-$(VERSION)/
	@cp -r config.ru $(NAME)-$(VERSION)/
	@cp -r db $(NAME)-$(VERSION)/
	@cp -r Gemfile $(NAME)-$(VERSION)/
	@cp -r Gemfile.lock $(NAME)-$(VERSION)/
	@cp -r lib $(NAME)-$(VERSION)/
	@cp -r engines $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/package
	@cp -r package/files $(NAME)-$(VERSION)/package

	@mkdir $(NAME)-$(VERSION)/log
	@cp -r log/.keep $(NAME)-$(VERSION)/log
	@mkdir $(NAME)-$(VERSION)/tmp
	@cp -r tmp/.keep $(NAME)-$(VERSION)/tmp

	@cp -r Rakefile $(NAME)-$(VERSION)/
	@cp -r README.md $(NAME)-$(VERSION)/
	@cp -r .bundle $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/vendor
	@mkdir -p $(NAME)-$(VERSION)/public/repo/
	@mkdir -p $(NAME)-$(VERSION)/public/suma/
	@cp -r public/tools $(NAME)-$(VERSION)/public/

	# i18n
	@cp -r locale $(NAME)-$(VERSION)/
	@rm -rf $(NAME)-$(VERSION)/locale/.keep
	@rm -rf $(NAME)-$(VERSION)/locale/*/rmt.edit.po
	@rm -rf $(NAME)-$(VERSION)/locale/*/rmt.po.time_stamp

	@rm -rf $(NAME)-$(VERSION)/config/rmt.yml
	@rm -rf $(NAME)-$(VERSION)/config/rmt.local.yml
	@rm -rf $(NAME)-$(VERSION)/config/system_uuid

	# don't package test tasks (fails to load because of rspec dependency)
	@rm -rf $(NAME)-$(VERSION)/lib/tasks/test.rake

	# don't package engine bin directory, specs (no need) and .gitignore (OBS complains)
	@rm -rf $(NAME)-$(VERSION)/engines/*/bin
	@rm -rf $(NAME)-$(VERSION)/engines/*/spec
	@rm -rf $(NAME)-$(VERSION)/engines/*/.gitignore

	# don't package example instance verification provider
	@rm -rf $(NAME)-$(VERSION)/engines/instance_verification/lib/instance_verification/providers/example.rb

	@mv $(NAME)-$(VERSION)/.bundle/config_packaging $(NAME)-$(VERSION)/.bundle/config
	cd $(NAME)-$(VERSION) && bundle package --all
	rm -rf $(NAME)-$(VERSION)/vendor/bundle/

	@mkdir $(NAME)-$(VERSION)/support
	@cp support/rmt $(NAME)-$(VERSION)/support/rmt

	# bundler hacks for ruby2.5
	sed -i '/source .*rubygems\.org/d' $(NAME)-$(VERSION)/Gemfile
	sed -i '/remote: .*rubygems\.org/d' $(NAME)-$(VERSION)/Gemfile.lock

	find $(NAME)-$(VERSION) -name \*~ -exec rm {} \;
	tar cfvj package/obs/$(NAME)-$(VERSION).tar.bz2 $(NAME)-$(VERSION)/
	rm -rf $(NAME)-$(VERSION)/

database-up: remove_test_config
	 docker compose up db -d

build: Dockerfile Gemfile public_repo
	 docker compose build rmt

server: build database-up
	 docker compose up

shell: build database-up
	 docker compose run --rm -ti rmt /bin/bash

console: build database-up
	 docker compose run --rm -ti rmt bundle exec rails c

public_repo:
	@echo ensure public/repo exists
	@mkdir -p public/repo
	@chmod -f 0777 public/repo || true

.PHONY: lint rubocop
lint rubocop:
	 docker compose run --rm -ti testrmt bundle exec rubocop -D

RMT_TEST_CFG = config/rmt.local.yml
RMT_TEST_DB_HOST = testdb
RMT_TEST_DB_PORT = 3306
RMT_TEST_DB_NAME = rmt_test

.PHONY: create_test_config mysql2_db_config sqlite3_db_config test_config_exists remove_test_config
create_test_config:
	 ruby -e "require 'yaml'; puts({'database_test'=>{'host' => '$(RMT_TEST_DB_HOST)', 'port' => $(RMT_TEST_DB_PORT), 'username'=>'rmt','password'=>'rmt','database'=>'$(RMT_TEST_DB_NAME)','adapter'=>'mysql2','encoding'=>'utf8','timeout'=>5000,'pool'=>5}}.to_yaml)" > $(RMT_TEST_CFG)

mysql2_db_config: create_test_config
	 sed -i -e 's/adapter: .*/adapter: mysql2/' $(RMT_TEST_CFG)

sqlite3_db_config: create_test_config
	 sed -i -e 's/adapter: .*/adapter: sqlite3/' $(RMT_TEST_CFG)

test_config_exists:
	 if ! [ -e $(RMT_TEST_CFG) ]; then \
	   echo "Create the testing config using 'make create_test_config'"; \
		 exit 1; \
	 fi

remove_test_config:
	 rm -f $(RMT_TEST_CFG)

.PHONY: rails_db_setup mysql2_db_setup sqlite3_db_setup
rails_db_setup:
	 docker compose run --rm -ti testrmt bundle exec rails db:drop db:create db:migrate RAILS_ENV=test

mysql2_db_setup: mysql2_db_config rails_db_setup

#sqlite3_db_setup: sqlite3_db_config rails_db_setup
sqlite3_db_setup: sqlite3_db_config

.PHONY: rake_test_core rake_test_engines
rake_test_core rake_test_engines: test_config_exists
	 docker compose run --rm -ti testrmt bundle exec rake test:$(subst rake_test_,,$@)

.PHONY: mysql2_tests sqlite3_tests pubcloud_tests
mysql2_tests: mysql2_db_setup rake_test_core remove_test_config

sqlite3_tests: sqlite3_db_setup rake_test_core remove_test_config

pubcloud_tests: mysql2_db_setup rake_test_core remove_test_config
