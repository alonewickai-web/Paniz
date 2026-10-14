CREATE TABLE `admin_notification_devices` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id` BIGINT UNSIGNED NOT NULL,
  `session_id` BIGINT UNSIGNED NOT NULL,
  `device_id` VARCHAR(64) NOT NULL,
  `device_name` VARCHAR(120) NOT NULL DEFAULT 'مدیر اندروید',
  `platform` VARCHAR(16) NOT NULL DEFAULT 'android',
  `last_seen_at` DATETIME(3) NULL,
  `last_notification_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `revoked_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_admin_notification_devices_admin_device` (`admin_id`, `device_id`),
  INDEX `ix_admin_notification_devices_active` (`admin_id`, `revoked_at`, `last_seen_at`),
  INDEX `ix_admin_notification_devices_session` (`session_id`, `revoked_at`),
  CONSTRAINT `admin_notification_devices_admin_id_fkey`
    FOREIGN KEY (`admin_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `admin_notification_devices_session_id_fkey`
    FOREIGN KEY (`session_id`) REFERENCES `admin_sessions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `admin_notification_preferences` (
  `admin_id` BIGINT UNSIGNED NOT NULL,
  `new_orders_enabled` BOOLEAN NOT NULL DEFAULT TRUE,
  `payments_enabled` BOOLEAN NOT NULL DEFAULT TRUE,
  `low_stock_enabled` BOOLEAN NOT NULL DEFAULT TRUE,
  `security_alerts_enabled` BOOLEAN NOT NULL DEFAULT TRUE,
  `server_alerts_enabled` BOOLEAN NOT NULL DEFAULT TRUE,
  `customer_messages_enabled` BOOLEAN NOT NULL DEFAULT TRUE,
  `admin_messages_enabled` BOOLEAN NOT NULL DEFAULT TRUE,
  `app_updates_enabled` BOOLEAN NOT NULL DEFAULT TRUE,
  `sound_enabled` BOOLEAN NOT NULL DEFAULT FALSE,
  `vibration_enabled` BOOLEAN NOT NULL DEFAULT TRUE,
  `background_monitoring_enabled` BOOLEAN NOT NULL DEFAULT FALSE,
  `updated_at` DATETIME(3) NOT NULL,
  PRIMARY KEY (`admin_id`),
  CONSTRAINT `admin_notification_preferences_admin_id_fkey`
    FOREIGN KEY (`admin_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `admin_notification_deliveries` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `notification_id` BIGINT UNSIGNED NOT NULL,
  `device_id` BIGINT UNSIGNED NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'sent',
  `attempts` INT UNSIGNED NOT NULL DEFAULT 1,
  `last_attempt_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `delivered_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_admin_notification_deliveries_notification_device` (`notification_id`, `device_id`),
  INDEX `ix_admin_notification_deliveries_device_status` (`device_id`, `status`, `created_at`),
  CONSTRAINT `admin_notification_deliveries_notification_id_fkey`
    FOREIGN KEY (`notification_id`) REFERENCES `admin_notifications` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `admin_notification_deliveries_device_id_fkey`
    FOREIGN KEY (`device_id`) REFERENCES `admin_notification_devices` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE `admin_notification_socket_tickets` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id` BIGINT UNSIGNED NOT NULL,
  `device_id` BIGINT UNSIGNED NOT NULL,
  `session_id` BIGINT UNSIGNED NOT NULL,
  `token_hash` CHAR(64) NOT NULL,
  `expires_at` DATETIME(3) NOT NULL,
  `consumed_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_admin_notification_socket_tickets_hash` (`token_hash`),
  INDEX `ix_admin_notification_socket_tickets_expiry` (`expires_at`, `consumed_at`),
  CONSTRAINT `admin_notification_socket_tickets_admin_id_fkey`
    FOREIGN KEY (`admin_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `admin_notification_socket_tickets_device_id_fkey`
    FOREIGN KEY (`device_id`) REFERENCES `admin_notification_devices` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `admin_notification_socket_tickets_session_id_fkey`
    FOREIGN KEY (`session_id`) REFERENCES `admin_sessions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
