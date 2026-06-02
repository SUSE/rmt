NAME          = rmt-server
VERSION       = $(shell ruby -e 'require "./lib/rmt.rb"; print RMT::VERSION')

# =============================================================================
# Phony Targets
# =============================================================================

.PHONY: all help clean ansible-test ansible-lint
.PHONY: build build-tarball dist man
.PHONY: ansible-deploy ansible-check
.PHONY: database-up server shell console public_repo

# =============================================================================
# Default Target
# =============================================================================

all:
	@:

# =============================================================================
# Help
# =============================================================================

help: ## Show this help message
	@echo 'RMT Makefile'
	@echo ''
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Common Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-z-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "^  (help|ansible-test|ansible-lint|clean|build|ansible-deploy|ansible-check) "
	@echo ''
	@echo 'Development Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-z-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "^  (server|shell|console|database-up) "
	@echo ''
	@echo 'Build & Package Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-z-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "^  (dist|build-tarball|man|public_repo) "
	@echo ''

# =============================================================================
# Testing & Validation
# =============================================================================

ansible-test: ## Run all tests (Ansible playbook tests)
	@echo "==> Running Ansible playbook tests..."
	cd ansible && ansible-playbook tests/test_playbook.yml
	@echo "==> All tests passed!"

ansible-lint: ## Lint Ansible playbooks and roles
	@echo "==> Checking Ansible playbook syntax..."
	cd ansible && ansible-playbook site.yml --syntax-check
	@echo "==> Linting Ansible playbooks and roles..."
	cd ansible && ansible-lint site.yml
	cd ansible && ansible-lint roles/rmt/
	@echo "==> All checks passed!"

# =============================================================================
# Deployment
# =============================================================================

ansible-deploy: ## Deploy RMT on localhost using Ansible
	cd ansible && ansible-playbook site.yml

ansible-check: ## Dry run Ansible deployment (check mode)
	cd ansible && ansible-playbook site.yml --check

# =============================================================================
# Build & Package
# =============================================================================

build: Dockerfile Gemfile public_repo ## Build RMT Docker image
	docker compose build rmt

build-tarball: clean man ## Build RMT distribution tarball
	@mkdir -p $(NAME)-$(VERSION)/

	@cp -r app $(NAME)-$(VERSION)/
	@mkdir $(NAME)-$(VERSION)/bin
	@cp -r bin/rails bin/rmt-cli bin/sidekiq $(NAME)-$(VERSION)/bin
	@cp -r bin/rmt-data-import $(NAME)-$(VERSION)/bin
	@cp -r bin/rmt-test-regsharing $(NAME)-$(VERSION)/bin
	@cp -r bin/rmt-manual-instance-verify $(NAME)-$(VERSION)/bin
	@cp -r bin/zeitwerk_loader_helper.rb $(NAME)-$(VERSION)/bin
	@cp -r config $(NAME)-$(VERSION)/
	@cp -r config.ru $(NAME)-$(VERSION)/
	@cp -r db $(NAME)-$(VERSION)/
	@cp -r Gemfile $(NAME)-$(VERSION)/
	@cp -r Gemfile.lock $(NAME)-$(VERSION)/
	@cp -r lib $(NAME)-$(VERSION)/
	@cp -r engines $(NAME)-$(VERSION)/
	@cp -r ansible $(NAME)-$(VERSION)/
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
	# don't package example data export handler
	@rm -rf $(NAME)-$(VERSION)/engines/data_export/lib/data_export/handlers/example.rb

	# don't package ansible tests and Python artifacts
	@rm -rf $(NAME)-$(VERSION)/ansible/tests
	@find $(NAME)-$(VERSION)/ansible -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find $(NAME)-$(VERSION)/ansible -name "*.pyc" -delete 2>/dev/null || true
	@find $(NAME)-$(VERSION)/ansible -name "*.retry" -delete 2>/dev/null || true

	@mv $(NAME)-$(VERSION)/.bundle/config_packaging $(NAME)-$(VERSION)/.bundle/config
	cd $(NAME)-$(VERSION) && bundle package --all
	rm -rf $(NAME)-$(VERSION)/vendor/bundle/

	@mkdir $(NAME)-$(VERSION)/support
	@cp support/rmt $(NAME)-$(VERSION)/support/rmt

	find $(NAME)-$(VERSION) -name \*~ -exec rm {} \;
	tar cfvj package/obs/$(NAME)-$(VERSION).tar.bz2 $(NAME)-$(VERSION)/
	rm -rf $(NAME)-$(VERSION)/

dist: ## Build RMT distribution tarball (using Docker)
	docker compose run -it -v $(PWD):/srv/www/rmt --rm rmt make build-tarball

man: ## Build RMT manual pages
	ronn --roff --pipe --manual RMT MANUAL.md > rmt-cli.8 && gzip -f rmt-cli.8
	mv rmt-cli.8.gz package/obs

public_repo: ## Ensure public/repo directory exists
	@echo ensure public/repo exists
	@mkdir -p public/repo
	@chmod -f 0777 public/repo || true

# =============================================================================
# Development
# =============================================================================

database-up: ## Start RMT database container
	docker compose up db -d

server: build database-up ## Start RMT development server
	docker compose up

shell: build database-up ## Open shell in RMT container
	docker compose run --rm -ti rmt /bin/bash

console: build database-up ## Open Rails console in RMT container
	docker compose run --rm -ti rmt bundle exec rails c

# =============================================================================
# Cleanup
# =============================================================================

clean: ## Clean all build artifacts and temporary files
	@echo "==> Cleaning RMT build artifacts..."
	rm -f rmt-cli.8*
	rm -rf package/obs/*.tar.bz2
	rm -rf $(NAME)-$(VERSION)/
	@echo "==> Cleaning Ansible artifacts..."
	cd ansible && find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	cd ansible && find . -name "*.pyc" -delete 2>/dev/null || true
	cd ansible && rm -rf /tmp/ansible_facts
	@echo "==> Cleanup complete!"
