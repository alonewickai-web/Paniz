-- Persist customer sessions and structured delivery details for authenticated checkout.
CREATE TABLE `customer_sessions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `token_hash` CHAR(64) NOT NULL,
  `expires_at` DATETIME(3) NOT NULL,
  `revoked_at` DATETIME(3) NULL,
  `last_used_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `uq_customer_sessions_token_hash` (`token_hash`),
  INDEX `ix_customer_sessions_customer_expiry` (`customer_id`, `expires_at`),
  INDEX `ix_customer_sessions_expiry` (`expires_at`),
  PRIMARY KEY (`id`),
  CONSTRAINT `customer_sessions_customer_id_fkey`
    FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

ALTER TABLE `customer_addresses`
  ADD COLUMN `street` VARCHAR(200) NULL,
  ADD COLUMN `alley` VARCHAR(200) NULL,
  ADD COLUMN `plaque_number` VARCHAR(40) NULL,
  ADD COLUMN `unit` VARCHAR(40) NULL,
  ADD COLUMN `delivery_details` VARCHAR(300) NULL;

