CREATE TABLE `admin_notifications` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id` BIGINT UNSIGNED NOT NULL,
  `type` VARCHAR(32) NOT NULL,
  `title` VARCHAR(160) NOT NULL,
  `body` VARCHAR(500) NOT NULL,
  `entity_type` VARCHAR(48) NULL,
  `entity_id` BIGINT UNSIGNED NULL,
  `external_ref` VARCHAR(128) NULL,
  `dedupe_key` VARCHAR(160) NULL,
  `read_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_admin_notifications_dedupe` (`dedupe_key`),
  INDEX `ix_admin_notifications_unread_created` (`admin_id`, `read_at`, `created_at`),
  CONSTRAINT `admin_notifications_admin_id_fkey`
    FOREIGN KEY (`admin_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
