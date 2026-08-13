-- Representative RMT 2.x data used as the migration baseline.
--
-- Only columns that exist across the whole 2.x range are referenced, so this
-- loads against any BASELINE_REF. Version-specific extras (e.g. proxy_byos)
-- are applied conditionally by lib/baseline.sh.
--
-- The data deliberately includes the things migrations tend to break:
-- multi-byte UTF-8, NULLs, a profiles.data payload near the TEXT ceiling,
-- JSON in systems.system_information, and rows on both sides of FKs.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 1;

-- ------------------------------------------------------------- products ---

INSERT INTO products (id, name, identifier, version, arch, product_type, free, product_class, description, shortname, release_stage, cpe)
VALUES
  (1743, 'SUSE Linux Enterprise Server', 'SLES', '15.6', 'x86_64', 'base', 0, '7261',
   'SUSE Linux Enterprise Server 15 SP6', 'SLES15-SP6', 'released', 'cpe:/o:suse:sles:15:sp6'),
  (2554, 'Basesystem Module', 'sle-module-basesystem', '15.6', 'x86_64', 'module', 1, 'MODULE',
   'Basesystem Module', 'Basesystem-Module', 'released', 'cpe:/o:suse:sle-module-basesystem:15:sp6'),
  (2001, 'SUSE Linux Enterprise Server LTSS', 'SLES-LTSS', '12.5', 'x86_64', 'extension', 0, 'SLES-LTSS-X86',
   'Long Term Service Pack Support — extended “quotes” and ümlauts', 'SLES12-SP5-LTSS', 'released',
   'cpe:/o:suse:sles-ltss:12:sp5');

-- ------------------------------------------------------------- services ---

INSERT INTO services (id, product_id, created_at, updated_at) VALUES
  (1743, 1743, '2024-01-15 10:00:00', '2024-01-15 10:00:00'),
  (2554, 2554, '2024-01-15 10:00:00', '2024-01-15 10:00:00'),
  (2001, 2001, '2024-01-15 10:00:00', '2024-01-15 10:00:00');

-- --------------------------------------------------- products_extensions ---

INSERT INTO products_extensions (product_id, extension_id, root_product_id, recommended, migration_extra)
VALUES (1743, 2554, 1743, 1, 0);

-- --------------------------------------------------------- repositories ---

INSERT INTO repositories (id, scc_id, name, description, external_url, local_path, friendly_id,
                          enabled, autorefresh, mirroring_enabled, installer_updates, auth_token, last_mirrored_at)
VALUES
  (3814, 3814, 'SLE-Product-SLES15-SP6-Pool',
   'SLE-Product-SLES15-SP6-Pool for sle-15-x86_64',
   'https://updates.suse.com/SUSE/Products/SLE-Product-SLES/15-SP6/x86_64/product/',
   '/SUSE/Products/SLE-Product-SLES/15-SP6/x86_64/product/', '3814', 1, 1, 1, 0, NULL, '2026-05-01 03:00:00'),
  (3815, 3815, 'SLE-Product-SLES15-SP6-Updates',
   'SLE-Product-SLES15-SP6-Updates for sle-15-x86_64',
   'https://updates.suse.com/SUSE/Updates/SLE-Product-SLES/15-SP6/x86_64/update/',
   '/SUSE/Updates/SLE-Product-SLES/15-SP6/x86_64/update/', '3815', 1, 1, 1, 0, 'someauthtoken', NULL),
  -- custom repository: no scc_id, friendly_id derived from the name
  (NULL, NULL, 'my-custom-repo', NULL,
   'http://example.com/custom/repo/', '/custom/repo/', 'my-custom-repo', 1, 1, 1, 0, NULL, NULL);

INSERT INTO repositories_services (repository_id, service_id) VALUES
  (3814, 1743),
  (3815, 1743);

-- -------------------------------------------------------- subscriptions ---

INSERT INTO subscriptions (id, regcode, name, kind, status, system_limit, systems_count,
                           virtual_count, starts_at, expires_at, created_at, updated_at)
VALUES (901, 'ABC123DEF456', 'SLES Subscription', 'full', 'ACTIVE', 100, 2, NULL,
        '2024-01-01 00:00:00', '2027-01-01 00:00:00', '2024-01-01 00:00:00', '2024-01-01 00:00:00');

INSERT INTO subscription_product_classes (subscription_id, product_class) VALUES (901, '7261');

-- -------------------------------------------------------------- systems ---
-- Row 2 exercises NULLs, row 3 exercises multi-byte hostnames and JSON hwinfo.

INSERT INTO systems (id, login, password, hostname, registered_at, last_seen_at, system_token,
                     system_information, scc_system_id, scc_registered_at, instance_data,
                     pubcloud_reg_code, created_at, updated_at)
VALUES
  (1, 'SCC_abc123', 'secret1', 'client-one.example.com', '2025-03-01 12:00:00', '2026-06-01 08:00:00',
   'token-aaa', '{"cpus":"4","sockets":"1","hypervisor":"KVM","arch":"x86_64","uuid":"1234-5678"}',
   556677, '2025-03-01 12:05:00', NULL, NULL, '2025-03-01 12:00:00', '2026-06-01 08:00:00'),
  (2, 'SCC_def456', 'secret2', NULL, NULL, NULL, NULL,
   '{}', NULL, NULL, NULL, NULL, '2025-04-02 09:30:00', '2025-04-02 09:30:00'),
  (3, 'SCC_ghi789', 'sécret3', 'wörkstation-drei.example.com', '2025-05-03 07:15:00', '2026-06-02 11:00:00',
   'token-ccc', '{"cpus":"8","sockets":"2","hypervisor":null,"arch":"aarch64","cloud_provider":"amazon"}',
   NULL, NULL, '<document>instance data</document>', 'PUBCLOUD-REG-1', '2025-05-03 07:15:00', '2026-06-02 11:00:00');

INSERT INTO activations (id, system_id, service_id, subscription_id, created_at, updated_at) VALUES
  (1, 1, 1743, 901, '2025-03-01 12:00:00', '2025-03-01 12:00:00'),
  (2, 1, 2554, NULL, '2025-03-01 12:00:00', '2025-03-01 12:00:00'),
  (3, 3, 1743, 901, '2025-05-03 07:15:00', '2025-05-03 07:15:00');

-- --------------------------------------------------------- system_uptimes ---

INSERT INTO system_uptimes (system_id, online_at_day, online_at_hours, created_at, updated_at) VALUES
  (1, '2026-06-01', '111111111111111111111111', '2026-06-01 23:59:00', '2026-06-01 23:59:00'),
  (3, '2026-06-02', '000000001111111111110000', '2026-06-02 23:59:00', '2026-06-02 23:59:00');

-- -------------------------------------------------------------- profiles ---
-- 60 KB of payload: comfortably inside the 64 KB TEXT ceiling of the pre-3.x
-- column, so this loads on every baseline. Suite 01 proves the migrated
-- column can hold more than TEXT ever could.

INSERT INTO profiles (id, profile_type, identifier, data, last_synced_at, created_at, updated_at) VALUES
  (1, 'package', 'sles-15-sp6-x86_64',
   CONCAT('{"packages":["', REPEAT('a', 60000), '"]}'),
   '2026-06-01 02:00:00', '2026-06-01 02:00:00', '2026-06-01 02:00:00'),
  (2, 'patch', 'sles-15-sp6-x86_64-üñïçødé',
   '{"patches":["SUSE-SLE-Product-SLES-15-SP6-2026-1234"]}',
   NULL, '2026-06-01 02:00:00', '2026-06-01 02:00:00');

INSERT INTO system_profiles (system_id, profile_id, created_at, updated_at) VALUES
  (1, 1, '2026-06-01 02:00:00', '2026-06-01 02:00:00'),
  (1, 2, '2026-06-01 02:00:00', '2026-06-01 02:00:00'),
  (3, 1, '2026-06-02 02:00:00', '2026-06-02 02:00:00');
