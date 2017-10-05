NAME          = rmt
VERSION       = 0.0.1
WWW_BASE      = /srv/www

all:
	@:

clean:
	rm -rf package/*.tar.bz2
	rm -rf vendor/cache vendor/bundle

dist: clean
	@mkdir -p $(NAME)-$(VERSION)/

	cp .bundle/config_packaging .bundle/config
	bundler package --all

	@cp -r app $(NAME)-$(VERSION)/
	@cp -r bin $(NAME)-$(VERSION)/
	@cp -r config $(NAME)-$(VERSION)/
	@cp -r config.ru $(NAME)-$(VERSION)/
	@cp -r db $(NAME)-$(VERSION)/
	@cp -r Gemfile $(NAME)-$(VERSION)/
	@cp -r Gemfile.lock $(NAME)-$(VERSION)/
	@cp -r lib $(NAME)-$(VERSION)/
	@cp -r log/.keep $(NAME)-$(VERSION)/
	@cp -r Rakefile $(NAME)-$(VERSION)/
	@cp -r README.md $(NAME)-$(VERSION)/
	@cp -r tmp/.keep $(NAME)-$(VERSION)/
	@cp -r vendor $(NAME)-$(VERSION)/
	@cp -r .bundle $(NAME)-$(VERSION)/
	@cp -r locale $(NAME)-$(VERSION)/

	rm -rf $(NAME)-$(VERSION)/vendor/bundle
	rm -rf $(NAME)-$(VERSION)/config/rmt.local.yml
	rm -rf $(NAME)-$(VERSION)/config/database.yml

	sed -i '/github:/d' $(NAME)-$(VERSION)/Gemfile
	sed -i '/github:/d' $(NAME)-$(VERSION)/Gemfile.lock

	tar cfvj package/$(NAME)-$(VERSION).tar.bz2 $(NAME)-$(VERSION)/
	rm -rf $(NAME)-$(VERSION)/
	rm .bundle/config

