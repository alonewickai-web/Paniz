ALTER TABLE `products`
  ADD COLUMN `purchase_cost_toman` BIGINT UNSIGNED NOT NULL DEFAULT 0;

ALTER TABLE `order_items`
  ADD COLUMN `purchase_cost_toman` BIGINT UNSIGNED NOT NULL DEFAULT 0;

CREATE TABLE `customer_support_tickets` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `subject` VARCHAR(180) NOT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'open',
  `last_message_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_support_tickets_customer_last_message` (`customer_id`, `last_message_at`),
  KEY `ix_support_tickets_status_last_message` (`status`, `last_message_at`),
  CONSTRAINT `fk_support_tickets_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `customer_support_messages` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ticket_id` BIGINT UNSIGNED NOT NULL,
  `sender_type` VARCHAR(16) NOT NULL,
  `customer_id` BIGINT UNSIGNED NULL,
  `admin_id` BIGINT UNSIGNED NULL,
  `body` VARCHAR(4000) NOT NULL,
  `image_path` VARCHAR(512) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `ix_support_messages_ticket_created` (`ticket_id`, `created_at`),
  CONSTRAINT `fk_support_messages_ticket` FOREIGN KEY (`ticket_id`) REFERENCES `customer_support_tickets` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_support_messages_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_support_messages_admin` FOREIGN KEY (`admin_id`) REFERENCES `admin_users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `order_return_requests` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` BIGINT UNSIGNED NOT NULL,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `reason` VARCHAR(2000) NOT NULL,
  `iban` VARCHAR(34) NOT NULL,
  `card_number` CHAR(16) NOT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'requested',
  `admin_note` VARCHAR(2000) NULL,
  `refund_receipt_path` VARCHAR(512) NULL,
  `requested_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `received_at` DATETIME(3) NULL,
  `refunded_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_order_return_requests_order` (`order_id`),
  KEY `ix_order_returns_status_requested` (`status`, `requested_at`),
  KEY `ix_order_returns_customer_requested` (`customer_id`, `requested_at`),
  CONSTRAINT `fk_order_returns_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_order_returns_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `customer_web_push_subscriptions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `endpoint` VARCHAR(2048) NOT NULL,
  `endpoint_hash` CHAR(64) NOT NULL,
  `p256dh` VARCHAR(256) NOT NULL,
  `auth` VARCHAR(128) NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_customer_push_endpoint_hash` (`endpoint_hash`),
  KEY `ix_customer_push_customer_updated` (`customer_id`, `updated_at`),
  CONSTRAINT `fk_customer_push_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `back_in_stock_subscriptions` (
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `variant_id` BIGINT UNSIGNED NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `notified_at` DATETIME(3) NULL,
  PRIMARY KEY (`customer_id`, `variant_id`),
  KEY `ix_back_in_stock_variant_notified` (`variant_id`, `notified_at`),
  CONSTRAINT `fk_back_in_stock_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_back_in_stock_variant` FOREIGN KEY (`variant_id`) REFERENCES `product_variants` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
