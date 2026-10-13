ALTER TABLE `products`
  ADD COLUMN `rubika_posted_at` DATETIME(3) NULL;

ALTER TABLE `product_variants`
  ADD COLUMN `color_sort_order` INTEGER NOT NULL DEFAULT 0;

CREATE INDEX `ix_products_rubika_posted_created`
  ON `products` (`rubika_posted_at`, `created_at`);
