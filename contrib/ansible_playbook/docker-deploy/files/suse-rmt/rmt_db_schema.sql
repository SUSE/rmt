-- MySQL dump 10.19  Distrib 10.2.40-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: rmt
-- ------------------------------------------------------
-- Server version	10.2.40-MariaDB-1:10.2.40+maria~bionic

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `activations`
--

DROP TABLE IF EXISTS `activations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `activations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `service_id` bigint(20) NOT NULL,
  `system_id` bigint(20) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_activations_on_system_id_and_service_id` (`system_id`,`service_id`),
  KEY `fk_rails_5ad14bc754` (`service_id`),
  KEY `index_activations_on_system_id` (`system_id`),
  CONSTRAINT `fk_rails_5ad14bc754` FOREIGN KEY (`service_id`) REFERENCES `services` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rails_e1f7b1621d` FOREIGN KEY (`system_id`) REFERENCES `systems` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ar_internal_metadata`
--

DROP TABLE IF EXISTS `ar_internal_metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ar_internal_metadata` (
  `key` varchar(255) NOT NULL,
  `value` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deregistered_systems`
--

DROP TABLE IF EXISTS `deregistered_systems`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deregistered_systems` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `scc_system_id` bigint(20) NOT NULL COMMENT 'SCC IDs of deregistered systems; used for forwarding to SCC',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_deregistered_systems_on_scc_system_id` (`scc_system_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `downloaded_files`
--

DROP TABLE IF EXISTS `downloaded_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `downloaded_files` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `checksum_type` varchar(255) DEFAULT NULL,
  `checksum` varchar(255) DEFAULT NULL,
  `local_path` varchar(255) DEFAULT NULL,
  `file_size` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_downloaded_files_on_local_path` (`local_path`),
  KEY `index_downloaded_files_on_checksum_type_and_checksum` (`checksum_type`,`checksum`)
) ENGINE=InnoDB AUTO_INCREMENT=65 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `hw_infos`
--

DROP TABLE IF EXISTS `hw_infos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hw_infos` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `cpus` int(11) DEFAULT NULL,
  `sockets` int(11) DEFAULT NULL,
  `hypervisor` varchar(255) DEFAULT NULL,
  `arch` varchar(255) DEFAULT NULL,
  `system_id` int(11) DEFAULT NULL,
  `uuid` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `instance_data` text DEFAULT NULL COMMENT 'Additional client information, e.g. instance identity document',
  `cloud_provider` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_hw_infos_on_system_id` (`system_id`),
  KEY `index_hw_infos_on_hypervisor` (`hypervisor`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `product_predecessors`
--

DROP TABLE IF EXISTS `product_predecessors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `product_predecessors` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `product_id` bigint(20) NOT NULL,
  `predecessor_id` bigint(20) DEFAULT NULL,
  `kind` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_product_predecessors_on_product_id_and_predecessor_id` (`product_id`,`predecessor_id`),
  KEY `fk_rails_ae2fd616af` (`predecessor_id`),
  KEY `index_product_predecessors_on_product_id` (`product_id`),
  CONSTRAINT `fk_rails_ae2fd616af` FOREIGN KEY (`predecessor_id`) REFERENCES `products` (`id`),
  CONSTRAINT `fk_rails_e8797ef6f4` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7213 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `products`
--

DROP TABLE IF EXISTS `products`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `products` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `shortname` varchar(255) DEFAULT NULL,
  `former_identifier` varchar(255) DEFAULT NULL,
  `product_type` varchar(255) DEFAULT NULL,
  `product_class` varchar(255) DEFAULT NULL,
  `release_type` varchar(255) DEFAULT NULL,
  `release_stage` varchar(255) DEFAULT NULL,
  `identifier` varchar(255) DEFAULT NULL,
  `version` varchar(255) DEFAULT NULL,
  `arch` varchar(255) DEFAULT NULL,
  `eula_url` varchar(255) DEFAULT NULL,
  `free` tinyint(1) DEFAULT NULL,
  `cpe` varchar(255) DEFAULT NULL,
  `friendly_version` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2238 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `products_extensions`
--

DROP TABLE IF EXISTS `products_extensions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `products_extensions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `product_id` bigint(20) NOT NULL,
  `extension_id` bigint(20) NOT NULL,
  `recommended` tinyint(1) DEFAULT NULL,
  `root_product_id` bigint(20) NOT NULL,
  `migration_extra` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_products_extensions_on_product_extension_root` (`product_id`,`extension_id`,`root_product_id`),
  KEY `index_products_extensions_on_extension_id` (`extension_id`),
  KEY `index_products_extensions_on_product_id` (`product_id`),
  KEY `fk_rails_7d0e68d364` (`root_product_id`),
  CONSTRAINT `fk_rails_1c1adb4078` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rails_7d0e68d364` FOREIGN KEY (`root_product_id`) REFERENCES `products` (`id`),
  CONSTRAINT `fk_rails_d228a5d6c6` FOREIGN KEY (`extension_id`) REFERENCES `products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4369 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `repositories`
--

DROP TABLE IF EXISTS `repositories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `repositories` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `scc_id` bigint(20) unsigned DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 0,
  `autorefresh` tinyint(1) NOT NULL DEFAULT 1,
  `external_url` varchar(255) NOT NULL,
  `auth_token` varchar(255) DEFAULT NULL,
  `installer_updates` tinyint(1) NOT NULL DEFAULT 0,
  `mirroring_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `local_path` varchar(255) NOT NULL,
  `last_mirrored_at` datetime DEFAULT NULL,
  `friendly_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_repositories_on_external_url` (`external_url`),
  UNIQUE KEY `index_repositories_on_scc_id` (`scc_id`),
  UNIQUE KEY `index_repositories_on_friendly_id` (`friendly_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2129 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `repositories_services`
--

DROP TABLE IF EXISTS `repositories_services`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `repositories_services` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `repository_id` bigint(20) NOT NULL,
  `service_id` bigint(20) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_repositories_services_on_service_id_and_repository_id` (`service_id`,`repository_id`),
  KEY `index_repositories_services_on_repository_id` (`repository_id`),
  KEY `index_repositories_services_on_service_id` (`service_id`),
  CONSTRAINT `fk_rails_24cbb571b8` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_rails_f1fc5c1e40` FOREIGN KEY (`service_id`) REFERENCES `services` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4346 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `schema_migrations`
--

DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `services`
--

DROP TABLE IF EXISTS `services`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `services` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `product_id` bigint(20) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_services_on_product_id` (`product_id`),
  CONSTRAINT `fk_rails_acabe7613b` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2238 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscription_product_classes`
--

DROP TABLE IF EXISTS `subscription_product_classes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `subscription_product_classes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `subscription_id` bigint(20) NOT NULL,
  `product_class` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_product_class_unique` (`subscription_id`,`product_class`),
  KEY `index_subscription_product_classes_on_subscription_id` (`subscription_id`),
  CONSTRAINT `fk_rails_1aae0e3ad2` FOREIGN KEY (`subscription_id`) REFERENCES `subscriptions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=526 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscriptions`
--

DROP TABLE IF EXISTS `subscriptions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `subscriptions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `regcode` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `kind` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL,
  `starts_at` datetime DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL,
  `system_limit` int(11) NOT NULL,
  `systems_count` int(11) NOT NULL,
  `virtual_count` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_subscriptions_on_regcode` (`regcode`)
) ENGINE=InnoDB AUTO_INCREMENT=4581447 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `systems`
--

DROP TABLE IF EXISTS `systems`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `systems` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `login` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `hostname` varchar(255) DEFAULT NULL,
  `registered_at` datetime DEFAULT NULL,
  `last_seen_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `scc_registered_at` datetime DEFAULT NULL,
  `scc_system_id` bigint(20) DEFAULT NULL COMMENT 'System ID in SCC (if the system registration was forwarded; needed for forwarding de-registrations)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_systems_on_login` (`login`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2021-08-25  1:41:50