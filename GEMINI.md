# RMT (Repository Mirroring Tool)

The Repository Mirroring Tool (RMT) allows mirroring SUSE RPM repositories and custom repositories in private networks.

## Architecture & Tech Stack
- **Framework:** Ruby on Rails
- **Language:** Ruby (Currently targeting Ruby 2.5.9 for RMT 2.x releases)
- **Database:** MariaDB/MySQL (Production), SQLite (Development alternative)
- **Background Jobs:** Sidekiq with Redis or Valkey
- **Proxy/Web Server:** Nginx (Containerized setup)
- **Packaging:** Open Build Service (OBS) and Internal Build Service (IBS)

## Key Directories
- `app/`: Core Rails application (controllers, models, services)
- `bin/`: CLI tools (e.g., `rmt-cli`, `rmt-data-import`)
- `config/`: Configuration files
- `engines/`: Modular components (e.g., SCC proxy, registration sharing)
- `lib/rmt/`: RMT-specific library logic
- `package/obs/`: RPM spec files and OBS metadata
- `spec/`: RSpec tests
- `features/`: Cucumber-style feature tests

## Agent Resources
- **Skills:** Located in `.agents/skills/`
  - `rmt-release-management`: Workflow and tools for managing the RMT release lifecycle.

## Development Workflows
- **Docker Compose:** Use `make build` and `make server` for a containerized development environment.
- **Manual Setup:** Follow instructions in `DEVELOPMENT.md`.
- **Testing:** Run `bin/rspec` for unit tests and `bin/ci rmt-run-feature-tests` for feature tests.

## Release Process
RMT 2.x releases are submitted to SLE 15 SP4 (LTSS until EOL 2026), SP5 (LTSS until EOL 2027), SP6, and SP7. Use the `rmt-release-management` skill for guidance on version updates, OBS syncing, and maintenance requests.
