CREATE TABLE `site_page_views` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `visitor_hash` CHAR(64) NOT NULL,
    `path` VARCHAR(500) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`),
    INDEX `ix_site_page_views_created_at` (`created_at`),
    INDEX `ix_site_page_views_path_created_at` (`path`, `created_at`),
    INDEX `ix_site_page_views_visitor_created_at` (`visitor_hash`, `created_at`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
