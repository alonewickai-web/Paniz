ALTER TABLE `customers`
  ADD COLUMN `marketing_opt_in` BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN `marketing_opt_in_at` DATETIME(3) NULL;

CREATE TABLE `sms_campaigns` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(160) NOT NULL,
  `message` VARCHAR(1000) NOT NULL,
  `target_filters` JSON NOT NULL,
  `recipient_count` INTEGER UNSIGNED NOT NULL DEFAULT 0,
  `sent_count` INTEGER UNSIGNED NOT NULL DEFAULT 0,
  `failed_count` INTEGER UNSIGNED NOT NULL DEFAULT 0,
  `status` VARCHAR(24) NOT NULL DEFAULT 'draft',
  `provider_response` JSON NULL,
  `created_by_admin_id` BIGINT UNSIGNED NOT NULL,
  `started_at` DATETIME(3) NULL,
  `completed_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  INDEX `ix_sms_campaigns_status_created` (`status`, `created_at`),
  INDEX `ix_sms_campaigns_created_by_admin` (`created_by_admin_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `sms_campaigns_created_by_admin_id_fkey` FOREIGN KEY (`created_by_admin_id`) REFERENCES `admin_users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE INDEX `ix_customers_marketing_consent_created` ON `customers`(`marketing_opt_in`, `created_at`);

CREATE TABLE `social_posts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `caption` VARCHAR(2200) NOT NULL,
  `image_url` VARCHAR(1000) NULL,
  `channels` JSON NOT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'queued',
  `publish_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `channel_results` JSON NULL,
  `last_error` VARCHAR(1000) NULL,
  `created_by_admin_id` BIGINT UNSIGNED NOT NULL,
  `published_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  INDEX `ix_social_posts_status_publish` (`status`, `publish_at`),
  INDEX `ix_social_posts_created_by_admin` (`created_by_admin_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `social_posts_created_by_admin_id_fkey` FOREIGN KEY (`created_by_admin_id`) REFERENCES `admin_users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
