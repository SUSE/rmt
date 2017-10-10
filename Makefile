NAME          = rmt
VERSION       = 0.0.1
WWW_BASE      = /srv/www

all:
	@:

clean:
	rm -rf package/*.tar.bz2
	rm -rf $(NAME)-$(VERSION)/

dist: clean
	@mkdir -p $(NAME)-$(VERSION)/

	@cp -r app $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/bin
	@cp -r bin/rails bin/rmt-cli $(NAME)-$(VERSION)/bin
	@cp -r config $(NAME)-$(VERSION)/
	@cp -r config.ru $(NAME)-$(VERSION)/
	@cp -r db $(NAME)-$(VERSION)/
	@cp -r Gemfile $(NAME)-$(VERSION)/
	@cp -r Gemfile.lock $(NAME)-$(VERSION)/
	@cp -r lib $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/log
	@cp -r log/.keep $(NAME)-$(VERSION)/log
	@cp -r Rakefile $(NAME)-$(VERSION)/
	@cp -r README.md $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/tmp
	@cp -r tmp/.keep $(NAME)-$(VERSION)/tmp
	@cp -r .bundle $(NAME)-$(VERSION)/
	@cp -r locale $(NAME)-$(VERSION)/
	@cp -r service $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/vendor

	@rm -rf $(NAME)-$(VERSION)/config/rmt.yml
	@rm -rf $(NAME)-$(VERSION)/config/rmt.local.yml
	@rm -rf $(NAME)-$(VERSION)/config/secrets.yml.*

	@mv $(NAME)-$(VERSION)/.bundle/config_packaging $(NAME)-$(VERSION)/.bundle/config
	cd $(NAME)-$(VERSION) && bundler package --all
	rm -rf $(NAME)-$(VERSION)/vendor/bundle/

	tar cfvj package/$(NAME)-$(VERSION).tar.bz2 $(NAME)-$(VERSION)/
	rm -rf $(NAME)-$(VERSION)/
