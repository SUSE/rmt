NAME          = smt-ng
VERSION       = 0.0.1
WWW_BASE      = /srv/www

all:
	@:

install:
	mkdir -p $(DESTDIR)$(WWW_BASE)/smt-ng/
	cp -a * $(DESTDIR)$(WWW_BASE)/smt-ng/

clean:
	rm -rf $(NAME)-$(VERSION)/
	rm -rf package/*.tar.bz2
	rm -rf vendor/cache vendor/bundle
	rm -rf .bundle

dist: clean
	@mkdir -p $(NAME)-$(VERSION)/

	bundle.ruby2.4 --without=test:development install
	bundle.ruby2.4 package

	@cp -r app $(NAME)-$(VERSION)/
	@cp -r bin $(NAME)-$(VERSION)/
	@cp -r config $(NAME)-$(VERSION)/
	@cp -r config.ru $(NAME)-$(VERSION)/
	@cp -r db $(NAME)-$(VERSION)/
	@cp -r Gemfile $(NAME)-$(VERSION)/
	@cp -r Gemfile.lock $(NAME)-$(VERSION)/
	@cp -r lib $(NAME)-$(VERSION)/
	@cp -r log/.keep $(NAME)-$(VERSION)/
	@cp -r Makefile $(NAME)-$(VERSION)/
	@cp -r public $(NAME)-$(VERSION)/
	@cp -r Rakefile $(NAME)-$(VERSION)/
	@cp -r README.md $(NAME)-$(VERSION)/
	@cp -r tmp/.keep $(NAME)-$(VERSION)/
	@cp -r vendor $(NAME)-$(VERSION)/
	@cp -r .bundle $(NAME)-$(VERSION)/

	# Don't want to fetch anything from rubygems.org, install from vendor/cache only
	sed -i '/rubygems\.org/d' $(NAME)-$(VERSION)/Gemfile
	sed -i '/rubygems\.org/d' $(NAME)-$(VERSION)/Gemfile.lock
	tar cfvj package/$(NAME)-$(VERSION).tar.bz2 $(NAME)-$(VERSION)/

