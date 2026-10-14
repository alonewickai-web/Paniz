ALTER TABLE `products`
  ADD COLUMN `seo_canonical_url` VARCHAR(500) NULL;

CREATE TABLE `product_slug_redirects` (
  `old_slug` VARCHAR(240) NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`old_slug`),
  KEY `ix_product_slug_redirects_product` (`product_id`),
  CONSTRAINT `fk_product_slug_redirects_product`
    FOREIGN KEY (`product_id`) REFERENCES `products` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
