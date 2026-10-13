CREATE TABLE `admin_app_releases` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `version_name` VARCHAR(40) NOT NULL,
  `version_code` INT NOT NULL,
  `file_path` VARCHAR(512) NOT NULL,
  `sha256` CHAR(64) NOT NULL,
  `file_size_bytes` BIGINT UNSIGNED NOT NULL,
  `release_notes` TEXT NULL,
  `is_current` BOOLEAN NOT NULL DEFAULT false,
  `created_by_admin_id` BIGINT UNSIGNED NULL,
  `published_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_admin_app_releases_version` (`version_code`),
  INDEX `ix_admin_app_releases_current` (`is_current`, `version_code`),
  CONSTRAINT `admin_app_releases_created_by_admin_id_fkey` FOREIGN KEY (`created_by_admin_id`)
    REFERENCES `admin_users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
