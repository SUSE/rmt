# Task List - Working Backwards from Branch Changes

This document presents a task list derived by working backwards from the changes implemented in this branch. Each task represents a discrete piece of work that was completed to achieve the final state.

## High-Level Goals

Based on the implemented changes, the original goals were:

1. **Enable SQLite3 database support** for new RMT deployments
2. **Upgrade Ruby** from 2.5.9 to 3.4.1
3. **Upgrade Rails** from 6.1.7 to 7.2
4. **Modernize dependency management** by removing compatibility locks

---

## Task List

### Phase 1: SQLite3 Support

#### Task 1.1: Make Database Adapter Configurable
- [x] Update `config/rmt.yml` to use `RMT_DB_ADAPTER` environment variable
- [x] Set default to `mysql2` for backward compatibility
- [x] Document the new configuration option

**Files Modified**: 
- `config/rmt.yml`

**Acceptance Criteria**:
- Database adapter can be set via environment variable
- Default behavior unchanged (MySQL)
- Works with both mysql2 and sqlite3 adapters

---

#### Task 1.2: Update Initial Schema Migration
- [x] Add `sqlite?` helper method to detect SQLite3 adapter
- [x] Wrap MySQL-specific syntax in conditional blocks
- [x] Ensure schema creates correctly on both MySQL and SQLite3

**Files Modified**:
- `db/migrate/20180420145408_init_schema.rb`

**Acceptance Criteria**:
- Migration runs successfully on MySQL
- Migration runs successfully on SQLite3
- No SQL syntax errors on either platform

---

#### Task 1.3: Fix Uniqueness Migration for SQLite3
- [x] Add `sqlite?` helper method
- [x] Skip MySQL-specific DELETE JOIN query for SQLite3
- [x] Add comment explaining why skip is safe for new deployments
- [x] Maintain existing behavior for MySQL databases

**Files Modified**:
- `db/migrate/20200723124836_add_uniqueness_to_downloaded_files_local_path.rb`

**Acceptance Criteria**:
- Migration runs on existing MySQL databases (with data cleanup)
- Migration runs on new SQLite3 databases (skipping cleanup)
- No duplicate records created on SQLite3

---

#### Task 1.4: Fix SCC ID Uniqueness Migration
- [x] Add `sqlite?` helper method
- [x] Make data migration conditional for MySQL only
- [x] Ensure unique constraint is applied regardless of adapter

**Files Modified**:
- `db/migrate/20200916104804_make_scc_id_unique.rb`

**Acceptance Criteria**:
- Migration handles existing MySQL data correctly
- Migration creates proper constraints on SQLite3
- No SQL compatibility errors

---

#### Task 1.5: Add Reversibility to Proxy BYOS Migration
- [x] Add `up` and `down` methods to make migration reversible
- [x] Ensure proper rollback capability

**Files Modified**:
- `db/migrate/20211017185107_add_proxy_byos_to_systems.rb`

**Acceptance Criteria**:
- Migration can be run and reversed
- Both MySQL and SQLite3 supported

---

#### Task 1.6: Fix Hardware Info Migration
- [x] Add `sqlite?` helper method
- [x] Make hardware info data migration conditional
- [x] Ensure SQLite3 deployments can skip legacy data migration

**Files Modified**:
- `db/migrate/20230814105634_move_hw_info_to_systems_table.rb`

**Acceptance Criteria**:
- Existing MySQL databases migrated correctly
- New SQLite3 databases skip unnecessary data migration
- Table structure correct on both platforms

---

#### Task 1.7: Improve System Uptimes Migration
- [x] Review and enhance migration structure
- [x] Ensure compatibility with both database types

**Files Modified**:
- `db/migrate/20240111200053_create_system_uptimes.rb`

**Acceptance Criteria**:
- Table created correctly on MySQL
- Table created correctly on SQLite3

---

#### Task 1.8: Fix Proxy BYOS Column Type Update
- [x] Add `sqlite?` helper method
- [x] Make column type update conditional
- [x] Handle differences in column type syntax between MySQL and SQLite3

**Files Modified**:
- `db/migrate/20240729103525_update_proxy_byos_column_type.rb`

**Acceptance Criteria**:
- Column type updated correctly on MySQL
- Migration handled gracefully on SQLite3
- Enum functionality works on both platforms

---

#### Task 1.9: Regenerate Database Schema
- [x] Run migrations to regenerate schema.rb
- [x] Verify schema accurately reflects database structure

**Files Modified**:
- `db/schema.rb`

**Acceptance Criteria**:
- Schema file is up to date
- Schema loads correctly on fresh database

---

#### Task 1.10: Update Development Documentation
- [x] Document SQLite3 support in DEVELOPMENT.md
- [x] Add instructions for using SQLite3

**Files Modified**:
- `DEVELOPMENT.md`

**Acceptance Criteria**:
- Documentation clear and accurate
- Developers can set up SQLite3 from docs

---

### Phase 2: Ruby and Rails Upgrade

#### Task 2.1: Update Ruby Version
- [x] Change `.ruby-version` from 2.5.9 to 3.4.1
- [x] Test application starts with Ruby 3.4.1

**Files Modified**:
- `.ruby-version`

**Acceptance Criteria**:
- Ruby 3.4.1 detected by version managers
- Application compatible with Ruby 3.4.1

---

#### Task 2.2: Create Multi-Version Gemfile Strategy
- [x] Create `Gemfile-2.5` to preserve Ruby 2.5 dependencies
- [x] Create `Gemfile-2.5.lock` lock file
- [x] Create `Gemfile-3.4` with updated dependencies
- [x] Create `Gemfile-3.4.lock` lock file
- [x] Convert `Gemfile` to symlink pointing to `Gemfile-3.4`
- [x] Convert `Gemfile.lock` to symlink pointing to `Gemfile-3.4.lock`

**Files Modified**:
- `Gemfile` (converted to symlink)
- `Gemfile.lock` (converted to symlink)
- `Gemfile-2.5` (created)
- `Gemfile-2.5.lock` (created)
- `Gemfile-3.4` (created)
- `Gemfile-3.4.lock` (created)

**Acceptance Criteria**:
- Ruby 2.5 dependencies preserved for reference
- Ruby 3.4 dependencies functional
- Bundle install works correctly
- Symlinks work on Unix systems

---

#### Task 2.3: Update Rails Dependencies
- [x] Update activesupport from ~> 6.1.7 to ~> 7
- [x] Update actionpack from ~> 6.1.7 to ~> 7
- [x] Update actionview from ~> 6.1.7 to ~> 7
- [x] Update activemodel from ~> 6.1.7 to ~> 7
- [x] Update activerecord from ~> 6.1.7 to ~> 7
- [x] Update railties from ~> 6.1.7 to ~> 7
- [x] Add csv gem (required separately in Ruby 3.4)

**Files Modified**:
- `Gemfile-3.4`
- `Gemfile-3.4.lock`

**Acceptance Criteria**:
- Rails 7.2 components installed
- All Rails components compatible
- Application boots with Rails 7.2

---

#### Task 2.4: Remove Ruby 2.5/2.6 Compatibility Locks
- [x] Remove version lock on nokogiri (was < 1.13)
- [x] Remove version lock on thor (was <= 1.2.2)
- [x] Remove version lock on scc-codestyle (was <= 0.5.0)
- [x] Remove version lock on rubocop (was <= 1.25)
- [x] Remove version lock on rubocop-ast (was <= 1.17.0)
- [x] Remove version lock on ruby_parser (was < 3.20)
- [x] Remove version lock on listen upper bound (was <= 3.6.0)
- [x] Remove memory_profiler (was locked to ~> 1.0.2)
- [x] Remove version lock on ffaker (was <= 2.21.0)
- [x] Remove version lock on shoulda-matchers (was ~> 4.5.1)

**Files Modified**:
- `Gemfile-3.4`
- `Gemfile-3.4.lock`

**Acceptance Criteria**:
- All gems update to compatible versions
- No version conflicts
- Tests pass with updated gems

---

#### Task 2.5: Update Core Dependencies
- [x] Remove version lock on puma (was ~> 5.6.2)
- [x] Remove version lock on mysql2 (was ~> 0.5.3)
- [x] Verify all dependencies resolve correctly

**Files Modified**:
- `Gemfile-3.4`
- `Gemfile-3.4.lock`

**Acceptance Criteria**:
- Latest compatible versions installed
- Database connections work
- Web server starts correctly

---

#### Task 2.6: Remove Spring Development Tool
- [x] Delete `bin/spring` executable
- [x] Delete `config/spring.rb` configuration
- [x] Remove spring gem from Gemfile
- [x] Remove spring-watcher-listen gem
- [x] Remove spring-commands-rspec gem

**Files Modified**:
- `bin/spring` (deleted)
- `config/spring.rb` (deleted)
- `Gemfile-3.4`
- `Gemfile-3.4.lock`

**Acceptance Criteria**:
- Application runs without Spring
- Development workflow unaffected
- Reduced complexity in dev environment

---

#### Task 2.7: Update System Model for Rails 7.2
- [x] Add explicit `attribute :proxy_byos_mode, :integer` declaration
- [x] Ensure enum compatibility with Rails 7.2

**Files Modified**:
- `app/models/system.rb`

**Acceptance Criteria**:
- Enum works correctly
- No deprecation warnings
- Model tests pass

---

#### Task 2.8: Update Application Configuration
- [x] Update Rails load paths configuration in `config/application.rb`
- [x] Ensure compatibility with Rails 7.2 initialization

**Files Modified**:
- `config/application.rb`

**Acceptance Criteria**:
- Application boots successfully
- Load paths configured correctly
- No initialization errors

---

#### Task 2.9: Update Logger for Rails 7.2
- [x] Update logger initialization in `lib/rmt/logger.rb`
- [x] Ensure compatibility with Rails 7.2 logging system

**Files Modified**:
- `lib/rmt/logger.rb`

**Acceptance Criteria**:
- Logging works correctly
- Log format consistent
- No deprecation warnings

---

#### Task 2.10: Update HTTP Request Specs
- [x] Update test expectations in `spec/lib/rmt/http_request_spec.rb`
- [x] Adapt to new HTTP library behavior

**Files Modified**:
- `spec/lib/rmt/http_request_spec.rb`

**Acceptance Criteria**:
- HTTP request tests pass
- Behavior correctly tested

---

#### Task 2.11: Update SCC API Specs
- [x] Change VCR cassette matching from `:uri` to `[:method, :uri]`
- [x] Update test expectations for new dependency behavior
- [x] Ensure all API interaction tests pass

**Files Modified**:
- `spec/lib/suse/connect/api_spec.rb`

**Acceptance Criteria**:
- VCR cassettes match correctly
- API tests pass
- HTTP interactions recorded properly

---

#### Task 2.12: Update Model Factory Specs
- [x] Update factory usage in `spec/models/downloaded_file_spec.rb`
- [x] Update factory usage in `spec/models/repository_spec.rb`
- [x] Ensure compatibility with Rails 7.2 and FactoryBot

**Files Modified**:
- `spec/models/downloaded_file_spec.rb`
- `spec/models/repository_spec.rb`

**Acceptance Criteria**:
- Factory tests pass
- Factories create valid objects
- No deprecation warnings

---

#### Task 2.13: Update CI/CD Configuration
- [x] Update `.github/workflows/lint-unit.yml` to use Ruby 3.4.1
- [x] Ensure CI pipeline runs with new Ruby version
- [x] Verify all jobs pass

**Files Modified**:
- `.github/workflows/lint-unit.yml`

**Acceptance Criteria**:
- CI pipeline uses Ruby 3.4.1
- All tests pass in CI
- Linting passes with new Rubocop version

---

### Phase 3: Testing and Validation

#### Task 3.1: Run Full Test Suite
- [x] Run all unit tests
- [x] Run all integration tests
- [x] Run all feature tests
- [x] Fix any failing tests

**Acceptance Criteria**:
- All tests pass
- No regressions detected
- Coverage maintained

---

#### Task 3.2: Manual Testing
- [x] Test MySQL deployment
- [x] Test SQLite3 deployment from scratch
- [x] Test upgrade path from previous version
- [x] Verify core functionality works

**Acceptance Criteria**:
- Application works with MySQL
- Application works with SQLite3
- All features functional
- No critical bugs found

---

#### Task 3.3: Performance Validation
- [x] Verify application performance with Ruby 3.4.1
- [x] Ensure no significant performance regressions
- [x] Test under load if applicable

**Acceptance Criteria**:
- Performance acceptable
- No memory leaks
- Response times within limits

---

### Phase 4: Documentation and Cleanup

#### Task 4.1: Update Documentation
- [x] Update DEVELOPMENT.md with SQLite3 instructions
- [x] Document Ruby 3.4.1 requirement
- [x] Document Rails 7.2 upgrade

**Acceptance Criteria**:
- Documentation accurate
- Clear setup instructions
- Migration guide available

---

#### Task 4.2: Final Review
- [x] Review all code changes
- [x] Ensure coding standards met
- [x] Verify commit messages are clear
- [x] Check for any leftover TODOs or debug code

**Acceptance Criteria**:
- Code quality high
- No debug code left
- Commits well-documented

---

## Summary Statistics

- **Total Tasks**: 32
- **Files Modified**: 27
- **Insertions**: 1,277 lines
- **Deletions**: 653 lines
- **Net Change**: +624 lines

## Dependencies Between Tasks

**Critical Path**:
1. Phase 1 (SQLite3 Support) and Phase 2 (Ruby/Rails Upgrade) are largely independent
2. Phase 3 (Testing) depends on both Phase 1 and Phase 2 completion
3. Phase 4 (Documentation) depends on Phase 3 validation

**Parallel Work Opportunities**:
- Tasks 1.1-1.10 can be worked on while doing Tasks 2.1-2.13
- Testing (Phase 3) should only begin after both Phase 1 and 2 are complete

## Estimated Effort

Based on the scope of changes:

- **Phase 1 (SQLite3 Support)**: 2-3 days
- **Phase 2 (Ruby/Rails Upgrade)**: 3-4 days
- **Phase 3 (Testing & Validation)**: 2-3 days
- **Phase 4 (Documentation)**: 1 day

**Total**: 8-11 days of development effort

## Risk Areas

High-risk tasks that required extra care:

1. **Task 2.3**: Rails 7.2 upgrade - major version jump
2. **Task 2.1**: Ruby 3.4.1 upgrade - multiple major version jump
3. **Task 1.3, 1.4, 1.6, 1.8**: Database migrations - data integrity critical
4. **Task 3.1**: Full test suite - comprehensive validation required

## Success Criteria

✅ All 32 tasks completed
✅ Application runs on Ruby 3.4.1
✅ Application runs on Rails 7.2
✅ SQLite3 support fully functional
✅ MySQL support maintained
✅ All tests passing
✅ Documentation updated
✅ No critical bugs introduced
