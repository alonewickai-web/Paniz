CREATE TABLE `admin_push_devices` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id` BIGINT UNSIGNED NOT NULL,
  `token` VARCHAR(4096) NOT NULL,
  `platform` VARCHAR(16) NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_admin_push_devices_token` (`token`),
  INDEX `ix_admin_push_devices_admin_updated` (`admin_id`, `updated_at`),
  CONSTRAINT `admin_push_devices_admin_id_fkey`
    FOREIGN KEY (`admin_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
