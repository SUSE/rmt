NAME          = rmt
VERSION       = 0.0.1

all:
	@:

clean:
	rm -f rmt.8*
	rm -rf package/*.tar.bz2
	rm -rf $(NAME)-$(VERSION)/

man:
	ronn --roff --pipe --manual RMT README.md > rmt.8 && gzip -f rmt.8
	mv rmt.8.gz package/

dist: clean man
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
	@mkdir -p $(NAME)-$(VERSION)/public/repo/
	@cp -r public/repo/.keep $(NAME)-$(VERSION)/public/repo/.keep

	@rm -rf $(NAME)-$(VERSION)/config/rmt.yml
	@rm -rf $(NAME)-$(VERSION)/config/rmt.local.yml
	@rm -rf $(NAME)-$(VERSION)/config/secrets.yml.*

	@mv $(NAME)-$(VERSION)/.bundle/config_packaging $(NAME)-$(VERSION)/.bundle/config
	cd $(NAME)-$(VERSION) && bundler package --all
	rm -rf $(NAME)-$(VERSION)/vendor/bundle/

	# bundler hacks for ruby2.5
	sed -i '/source .*rubygems\.org/d' $(NAME)-$(VERSION)/Gemfile
	sed -i '/remote: .*rubygems\.org/d' $(NAME)-$(VERSION)/Gemfile.lock

	tar cfvj package/$(NAME)-$(VERSION).tar.bz2 $(NAME)-$(VERSION)/
	rm -rf $(NAME)-$(VERSION)/
