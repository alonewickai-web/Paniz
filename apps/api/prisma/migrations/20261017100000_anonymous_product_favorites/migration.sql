CREATE TABLE `anonymous_product_favorites` (
    `visitor_hash` CHAR(64) NOT NULL,
    `product_id` BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    INDEX `ix_anon_favorite_product`(`product_id`),
    PRIMARY KEY (`visitor_hash`, `product_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `anonymous_product_favorites`
ADD CONSTRAINT `anonymous_product_favorites_product_id_fkey`
FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
