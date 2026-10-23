NAME          = rmt-server
VERSION       = $(shell ruby -e 'require "./lib/rmt.rb"; print RMT::VERSION')

# Load environment variables from .env file (if present)
-include .env

# =============================================================================
# Phony Targets
# =============================================================================

.PHONY: all help clean ansible-test ansible-lint
.PHONY: build build-tarball dist man
.PHONY: ansible-deploy ansible-check
.PHONY: database-up server shell console public_repo
.PHONY: ci-env-check ci-build ci-up ci-wait ci-start-mariadb
.PHONY: ci-build-rpms ci-install-rpms ci-tests ci-down ci-clean
.PHONY: ci-all ci-status ci-logs ci-shell ci-build-flavours

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
	@echo 'CI / Systemd Feature Tests:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-z-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | grep -E "^  ci-[a-z-]* "
	@echo ''

# =============================================================================
# Testing & Validation
# =============================================================================

ansible-test: build ## Run Ansible tests in container
	@echo "==> Running Ansible playbook tests in openSUSE Leap 16.0 container..."
	docker compose run --rm rmt bash -c "cd /srv/www/rmt/ansible && ansible-playbook tests/test_playbook.yml"
	@echo "==> All tests passed!"

ansible-lint: ## Lint Ansible playbooks and roles (requires local ansible installation)
	@echo "==> Checking Ansible playbook syntax..."
	cd ansible && ansible-playbook site.yml --syntax-check
	@echo "==> Linting Ansible playbooks and roles..."
	cd ansible && ansible-lint site.yml
	cd ansible && ansible-lint roles/rmt/
	@echo "==> All checks passed!"

# =============================================================================
# Deployment
# =============================================================================

ansible-deploy: ## Deploy RMT on localhost (requires sudo)
	@echo "==> Deploying RMT via Ansible (requires sudo access)..."
	cd ansible && ansible-playbook site.yml --ask-become-pass

ansible-check: ## Dry run Ansible deployment in Docker container
	@echo "==> Running Ansible playbook check in Docker..."
	docker compose run --rm rmt bash -c "cd /srv/www/rmt/ansible && ansible-playbook site.yml --syntax-check"
	@echo "==> Syntax check passed!"

ansible-check-local: ## Dry run Ansible deployment locally (requires sudo)
	@echo "==> Running Ansible playbook in check mode (requires sudo access)..."
	cd ansible && ansible-playbook site.yml --check --ask-become-pass

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

	# don't package agent/AI related files
	@rm -rf $(NAME)-$(VERSION)/.agents
	@rm -rf $(NAME)-$(VERSION)/.gemini
	@rm -rf $(NAME)-$(VERSION)/.claude
	@rm -rf $(NAME)-$(VERSION)/GEMINI.md
	# Clean up ansible Python artifacts (keep tests for %check validation)
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
# CI / Systemd Feature Tests
# =============================================================================
# Targets to replicate the systemd-based feature testing locally by building
# and launching a systemd-enabled container (default SLE 16.0) locally
# that is then used to build the RMT rpms, install them, configure
# and run the RMT and dependent MariaDB services, and finally run
# the feature tests, before cleaning everything up.
# Set CI_DISTRO=<flavour> to build a different flavour.
# Available flavours are:
# * sle15_sp7
# * sle16_0 (default)
# * tumbleweed

CI_DISTRO     ?= sle16_0
CI_IMAGE      ?= rmt-ci-systemd-$(CI_DISTRO)
CI_CONTAINER  ?= rmt-systemd-$(CI_DISTRO)
CI_SOURCE     ?= /usr/src/rmt-server

ci-build-flavours: ## List available build flavours for CI_DISTRO
	@echo Available build flavours for CI_DISTRO are:
	@ls -1 ci/Dockerfile.* | cut -d. -f2 | sed -e 's,^,- ,'

ci-build: ## Build the systemd-enabled CI Docker image
	@echo "==> Building CI image $(CI_IMAGE)..."
	docker build -t $(CI_IMAGE) -f ci/Dockerfile.$(CI_DISTRO) .

ci-up: ci-build ## Start the systemd-enabled CI container
	@if docker ps -a --format '{{.Names}}' | grep -q "^$(CI_CONTAINER)$$"; then \
		echo "==> Container $(CI_CONTAINER) already exists. Run 'make ci-down' first."; \
		exit 1; \
	fi
	@echo "==> Starting systemd container $(CI_CONTAINER)..."
	docker run -d \
		--name $(CI_CONTAINER) \
		--privileged \
		--cgroupns=host \
		-v /sys/fs/cgroup:/sys/fs/cgroup:rw \
		-v $(CURDIR):$(CI_SOURCE) \
		-e SYSTEMD_REGENERATE_USER_UNITS=true \
		$(CI_IMAGE) \
		/usr/sbin/init

ci-wait: ## Wait for the systemd container to be ready
	@echo "==> Waiting for systemd to be ready..."
	@for i in $$(seq 1 60); do \
		if docker exec $(CI_CONTAINER) systemctl is-system-running >/dev/null 2>&1; then \
			echo "  systemd is ready"; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "  ERROR: systemd did not start within 60 seconds"; \
	exit 1

ci-start-mariadb: ci-wait ## Install and start MariaDB inside the CI container
	@echo "==> Starting MariaDB..."
	docker exec $(CI_CONTAINER) bash -c '\
		set -e; \
		if ! command -v mariadb-install-db >/dev/null 2>&1; then \
			echo "  Installing MariaDB server..."; \
			zypper --non-interactive install mariadb; \
		fi; \
		if [ ! -d /var/lib/mysql ]; then \
			echo "  Initializing MariaDB data directory..."; \
			mariadb-install-db --user=mysql --datadir=/var/lib/mysql; \
		fi; \
		systemctl start mariadb; \
		for i in $$(seq 1 30); do \
			if mysqladmin ping --silent 2>/dev/null; then \
				echo "  MariaDB is ready"; \
				exit 0; \
			fi; \
			sleep 1; \
		done; \
		echo "  ERROR: MariaDB failed to start"; \
		exit 1 \
	'

ci-setup-database: ci-start-mariadb ## Create the RMT database user in MariaDB
	@echo "==> Creating RMT database user..."
	docker exec $(CI_CONTAINER) bash -c '\
		set -e; \
		mysql -u root -e "CREATE USER IF NOT EXISTS '\''rmt'\''@'\''127.0.0.1'\'' IDENTIFIED BY '\''rmt'\'';"; \
		mysql -u root -e "CREATE USER IF NOT EXISTS '\''rmt'\''@'\''localhost'\'' IDENTIFIED BY '\''rmt'\'';"; \
		mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '\''rmt'\''@'\''127.0.0.1'\'';"; \
		mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '\''rmt'\''@'\''localhost'\'';"; \
		mysql -u root -e "FLUSH PRIVILEGES;"; \
		echo "  Database user created" \
	'

ci-build-rpms: ## Install Ruby deps, build RPMs, and validate packaging
	@echo "==> Installing dependencies and building RPMs..."
	docker exec $(CI_CONTAINER) bash -c '\
		set -e; \
		cd $(CI_SOURCE); \
		bundle install; \
		bash ci/rmt-build-rpm; \
		bash ci/rmt-validate-packaging \
	'

ci-env-check: ## Check required environment variables are setup
	@if [ -z "$(SCC_USERNAME)" ] || [ -z "$(SCC_PASSWORD)" ]; then \
		echo "ERROR: SCC_USERNAME and SCC_PASSWORD not found in .env"; \
		echo "       Copy .env.example to .env if needed and set your credentials."; \
		exit 1; \
	fi

ci-install-rpms: ci-env-check ## Install RPMs, create config, and set up database
	@echo "==> Configuring RMT..."
	docker exec $(CI_CONTAINER) bash -c '\
		set -e; \
		echo "export SCC_USERNAME=$(SCC_USERNAME)" > /tmp/.ci-creds; \
		echo "export SCC_PASSWORD=$(SCC_PASSWORD)" >> /tmp/.ci-creds; \
		chmod 600 /tmp/.ci-creds; \
		cd $(CI_SOURCE); \
		source /tmp/.ci-creds; \
		bash ci/rmt-configure; \
		rm -f /tmp/.ci-creds \
	'

ci-tests: ## Run feature tests
	@echo "==> Running feature tests..."
	docker exec $(CI_CONTAINER) bash -c '\
		set -e; \
		cd $(CI_SOURCE); \
		bash ci/rmt-run-feature-tests \
	'

ci-all: ci-env-check ci-build ci-up ci-start-mariadb ci-setup-database ci-build-rpms ci-install-rpms ci-tests ci-down ## Run the full CI pipeline locally

ci-down: ## Stop and remove the CI container
	@echo "==> Stopping container $(CI_CONTAINER)..."
	docker stop $(CI_CONTAINER) || true
	docker rm $(CI_CONTAINER) || true

ci-clean: ci-down ## Remove CI image and container
	@echo "==> Removing CI image $(CI_IMAGE)..."
	docker rmi $(CI_IMAGE) || true

ci-status: ## Show CI container status
	@docker ps -a --filter "name=$(CI_CONTAINER)" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" || echo "Container not found"

ci-logs: ## Show CI container logs (follow mode)
	docker logs -f $(CI_CONTAINER)

ci-shell: ci-up ## Open an interactive shell in the CI container
	docker exec -it $(CI_CONTAINER) /bin/bash

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
