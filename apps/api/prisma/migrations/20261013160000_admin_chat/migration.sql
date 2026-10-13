CREATE TABLE `admin_chat_messages` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `sender_admin_id` BIGINT UNSIGNED NOT NULL,
  `recipient_admin_id` BIGINT UNSIGNED NOT NULL,
  `broadcast_group_id` CHAR(36) NULL,
  `body` VARCHAR(4000) NOT NULL,
  `read_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `ix_admin_chat_pair_created` (`sender_admin_id`, `recipient_admin_id`, `created_at`),
  KEY `ix_admin_chat_unread_created` (`recipient_admin_id`, `read_at`, `created_at`),
  KEY `ix_admin_chat_broadcast` (`broadcast_group_id`),
  CONSTRAINT `fk_admin_chat_sender` FOREIGN KEY (`sender_admin_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_admin_chat_recipient` FOREIGN KEY (`recipient_admin_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
