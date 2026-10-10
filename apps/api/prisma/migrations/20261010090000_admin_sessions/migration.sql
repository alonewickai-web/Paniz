CREATE TABLE `admin_sessions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `admin_id` BIGINT UNSIGNED NOT NULL,
    `token_hash` CHAR(64) NOT NULL,
    `expires_at` DATETIME(3) NOT NULL,
    `revoked_at` DATETIME(3) NULL,
    `last_used_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `uq_admin_sessions_token_hash` (`token_hash`),
    INDEX `ix_admin_sessions_admin_expiry` (`admin_id`, `expires_at`),
    INDEX `ix_admin_sessions_expiry` (`expires_at`),
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_admin_sessions_admin_id` FOREIGN KEY (`admin_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
