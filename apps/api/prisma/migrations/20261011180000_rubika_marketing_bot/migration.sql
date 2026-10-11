ALTER TABLE `customers`
  ADD COLUMN `rubika_chat_id` VARCHAR(128) NULL,
  ADD COLUMN `rubika_marketing_opt_in` BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN `rubika_marketing_opt_in_at` DATETIME(3) NULL,
  ADD UNIQUE INDEX `uq_customers_rubika_chat_id` (`rubika_chat_id`),
  ADD INDEX `ix_customers_rubika_marketing_created` (`rubika_marketing_opt_in`, `created_at`);

ALTER TABLE `sms_campaigns`
  ADD COLUMN `channel` VARCHAR(16) NOT NULL DEFAULT 'sms' AFTER `id`,
  DROP INDEX `ix_sms_campaigns_status_created`,
  ADD INDEX `ix_sms_campaigns_channel_status_created` (`channel`, `status`, `created_at`);

CREATE TABLE `customer_rubika_link_codes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `token_hash` CHAR(64) NOT NULL,
  `expires_at` DATETIME(3) NOT NULL,
  `used_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `uq_customer_rubika_link_codes_token_hash` (`token_hash`),
  INDEX `ix_customer_rubika_link_codes_customer_expiry` (`customer_id`, `expires_at`),
  PRIMARY KEY (`id`),
  CONSTRAINT `customer_rubika_link_codes_customer_id_fkey`
    FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;