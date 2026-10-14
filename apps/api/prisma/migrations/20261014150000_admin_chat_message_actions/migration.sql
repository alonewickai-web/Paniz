ALTER TABLE `admin_chat_messages`
  ADD COLUMN `edited_at` DATETIME(3) NULL;

CREATE TABLE `admin_chat_message_hides` (
  `message_id` BIGINT UNSIGNED NOT NULL,
  `admin_id` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`message_id`, `admin_id`),
  INDEX `ix_admin_chat_hides_admin_message` (`admin_id`, `message_id`),
  CONSTRAINT `admin_chat_message_hides_message_id_fkey`
    FOREIGN KEY (`message_id`) REFERENCES `admin_chat_messages` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `admin_chat_message_hides_admin_id_fkey`
    FOREIGN KEY (`admin_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
