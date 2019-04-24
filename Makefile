NAME          = rmt-server
VERSION       = $(shell ruby -e 'require "./lib/rmt.rb"; print RMT::VERSION')

all:
	@:

clean:
	rm -f rmt-cli.8*
	rm -rf package/obs/*.tar.bz2
	rm -rf $(NAME)-$(VERSION)/

man:
	bundle exec ronn --roff --pipe --manual RMT MANUAL.md > rmt-cli.8 && gzip -f rmt-cli.8
	mv rmt-cli.8.gz package/obs

dist: clean man
	@mkdir -p $(NAME)-$(VERSION)/

	@cp -r app $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/bin
	@cp -r bin/rails bin/rmt-cli $(NAME)-$(VERSION)/bin
	@cp -r bin/rmt-data-import $(NAME)-$(VERSION)/bin
	@cp -r bin/rmt-test-regsharing $(NAME)-$(VERSION)/bin
	@cp -r config $(NAME)-$(VERSION)/
	@cp -r config.ru $(NAME)-$(VERSION)/
	@cp -r db $(NAME)-$(VERSION)/
	@cp -r Gemfile $(NAME)-$(VERSION)/
	@cp -r Gemfile.lock $(NAME)-$(VERSION)/
	@cp -r lib $(NAME)-$(VERSION)/
	@cp -r engines $(NAME)-$(VERSION)/
	@cp -r package $(NAME)-$(VERSION)/

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
	@rm -rf $(NAME)-$(VERSION)/config/secrets.yml.*
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
