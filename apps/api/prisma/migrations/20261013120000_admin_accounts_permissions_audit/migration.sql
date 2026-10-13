ALTER TABLE `admin_users`
  ADD COLUMN `avatar_path` VARCHAR(512) NULL,
  ADD COLUMN `must_change_password` BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE `admin_user_permissions` (
  `admin_id` BIGINT UNSIGNED NOT NULL,
  `permission_key` VARCHAR(96) NOT NULL,
  `granted_by_admin_id` BIGINT UNSIGNED NULL,
  `expires_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`admin_id`, `permission_key`),
  INDEX `ix_admin_permissions_key_expiry` (`permission_key`, `expires_at`),
  CONSTRAINT `admin_user_permissions_admin_id_fkey`
    FOREIGN KEY (`admin_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `admin_user_permissions_granted_by_admin_id_fkey`
    FOREIGN KEY (`granted_by_admin_id`) REFERENCES `admin_users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

ALTER TABLE `admin_audit_logs`
  ADD COLUMN `result` VARCHAR(16) NOT NULL DEFAULT 'success';

UPDATE `admin_audit_logs`
SET `result` = 'failed'
WHERE `action` IN ('admin.login_failed', 'admin.credentials_reauthentication_failed');
