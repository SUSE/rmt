NAME          = rmt-server
VERSION       = 1.0.1

all:
	@:

clean:
	rm -f rmt-cli.8*
	rm -rf package/*.tar.bz2
	rm -rf $(NAME)-$(VERSION)/

man:
	bundle exec ronn --roff --pipe --manual RMT MANUAL.md > rmt-cli.8 && gzip -f rmt-cli.8
	mv rmt-cli.8.gz package/

dist: clean man
	@mkdir -p $(NAME)-$(VERSION)/

	@cp -r app $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/bin
	@cp -r bin/rails bin/rmt-cli $(NAME)-$(VERSION)/bin
	@cp -r bin/rmt-data-import $(NAME)-$(VERSION)/bin
	@cp -r config $(NAME)-$(VERSION)/
	@cp -r config.ru $(NAME)-$(VERSION)/
	@cp -r db $(NAME)-$(VERSION)/
	@cp -r Gemfile $(NAME)-$(VERSION)/
	@cp -r Gemfile.lock $(NAME)-$(VERSION)/
	@cp -r lib $(NAME)-$(VERSION)/

	@mkdir $(NAME)-$(VERSION)/log
	@cp -r log/.keep $(NAME)-$(VERSION)/log
	@mkdir $(NAME)-$(VERSION)/ssl
	@cp -r ssl/.keep $(NAME)-$(VERSION)/ssl
	@mkdir $(NAME)-$(VERSION)/tmp
	@cp -r tmp/.keep $(NAME)-$(VERSION)/tmp

	@cp -r Rakefile $(NAME)-$(VERSION)/
	@cp -r README.md $(NAME)-$(VERSION)/
	@cp -r .bundle $(NAME)-$(VERSION)/
	@cp -r locale $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/vendor
	@mkdir -p $(NAME)-$(VERSION)/public/repo/
	@cp -r public/tools $(NAME)-$(VERSION)/public/

	@rm -rf $(NAME)-$(VERSION)/config/rmt.yml
	@rm -rf $(NAME)-$(VERSION)/config/rmt.local.yml
	@rm -rf $(NAME)-$(VERSION)/config/secrets.yml.*
	@rm -rf $(NAME)-$(VERSION)/config/system_uuid

	@mv $(NAME)-$(VERSION)/.bundle/config_packaging $(NAME)-$(VERSION)/.bundle/config
	cd $(NAME)-$(VERSION) && bundle package --all
	rm -rf $(NAME)-$(VERSION)/vendor/bundle/

	@mkdir $(NAME)-$(VERSION)/support
	@cp support/rmt $(NAME)-$(VERSION)/support/rmt

	# bundler hacks for ruby2.5
	sed -i '/source .*rubygems\.org/d' $(NAME)-$(VERSION)/Gemfile
	sed -i '/remote: .*rubygems\.org/d' $(NAME)-$(VERSION)/Gemfile.lock

	tar cfvj package/$(NAME)-$(VERSION).tar.bz2 $(NAME)-$(VERSION)/
	rm -rf $(NAME)-$(VERSION)/
