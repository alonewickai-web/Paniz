-- CreateTable
CREATE TABLE `admin_users` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `full_name` VARCHAR(160) NOT NULL,
    `phone` VARCHAR(24) NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `role` VARCHAR(32) NOT NULL DEFAULT 'owner',
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `last_login_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_admin_users_phone`(`phone`),
    INDEX `ix_admin_users_role_active`(`role`, `is_active`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `customers` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `phone` VARCHAR(24) NOT NULL,
    `full_name` VARCHAR(160) NULL,
    `email` VARCHAR(254) NULL,
    `phone_verified_at` DATETIME(3) NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'active',
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_customers_phone`(`phone`),
    INDEX `ix_customers_status_created`(`status`, `created_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `customer_addresses` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `customer_id` BIGINT UNSIGNED NOT NULL,
    `title` VARCHAR(80) NULL,
    `recipient_name` VARCHAR(160) NOT NULL,
    `recipient_phone` VARCHAR(24) NOT NULL,
    `province` VARCHAR(100) NOT NULL,
    `city` VARCHAR(100) NOT NULL,
    `address_line` VARCHAR(500) NOT NULL,
    `postal_code` CHAR(10) NOT NULL,
    `is_default` BOOLEAN NOT NULL DEFAULT false,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    INDEX `ix_customer_addresses_customer_default`(`customer_id`, `is_default`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `categories` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `parent_id` BIGINT UNSIGNED NULL,
    `name` VARCHAR(120) NOT NULL,
    `slug` VARCHAR(160) NOT NULL,
    `description` TEXT NULL,
    `image_path` VARCHAR(500) NULL,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_categories_slug`(`slug`),
    INDEX `ix_categories_parent_active_order`(`parent_id`, `is_active`, `sort_order`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `products` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category_id` BIGINT UNSIGNED NULL,
    `name` VARCHAR(220) NOT NULL,
    `slug` VARCHAR(240) NOT NULL,
    `short_description` VARCHAR(500) NULL,
    `description` MEDIUMTEXT NULL,
    `material` VARCHAR(220) NULL,
    `care_instructions` TEXT NULL,
    `size_guide` JSON NULL,
    `seo_title` VARCHAR(240) NULL,
    `seo_description` VARCHAR(500) NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'draft',
    `published_at` DATETIME(3) NULL,
    `deleted_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_products_slug`(`slug`),
    INDEX `ix_products_category_status_created`(`category_id`, `status`, `created_at`),
    INDEX `ix_products_status_published`(`status`, `published_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `product_images` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `product_id` BIGINT UNSIGNED NOT NULL,
    `image_path` VARCHAR(500) NOT NULL,
    `alt_text` VARCHAR(240) NULL,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `is_primary` BOOLEAN NOT NULL DEFAULT false,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `ix_product_images_product_order`(`product_id`, `sort_order`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `product_variants` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `product_id` BIGINT UNSIGNED NOT NULL,
    `sku` VARCHAR(80) NOT NULL,
    `color_name` VARCHAR(80) NOT NULL DEFAULT 'بدون رنگ',
    `color_hex` CHAR(7) NULL,
    `size_label` VARCHAR(32) NOT NULL DEFAULT 'فری سایز',
    `price_toman` BIGINT UNSIGNED NOT NULL,
    `compare_at_price_toman` BIGINT UNSIGNED NULL,
    `stock_quantity` INTEGER UNSIGNED NOT NULL DEFAULT 0,
    `reserved_quantity` INTEGER UNSIGNED NOT NULL DEFAULT 0,
    `low_stock_threshold` INTEGER UNSIGNED NOT NULL DEFAULT 3,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_product_variants_sku`(`sku`),
    INDEX `ix_product_variants_product_active`(`product_id`, `is_active`),
    INDEX `ix_product_variants_low_stock`(`is_active`, `stock_quantity`, `low_stock_threshold`),
    UNIQUE INDEX `uq_product_variants_product_color_size`(`product_id`, `color_name`, `size_label`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `inventory_movements` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `variant_id` BIGINT UNSIGNED NOT NULL,
    `movement_type` VARCHAR(24) NOT NULL,
    `quantity_delta` INTEGER NOT NULL DEFAULT 0,
    `reserved_delta` INTEGER NOT NULL DEFAULT 0,
    `reference_type` VARCHAR(32) NULL,
    `reference_id` BIGINT UNSIGNED NULL,
    `note` VARCHAR(500) NULL,
    `created_by_admin_id` BIGINT UNSIGNED NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `ix_inventory_movements_variant_created`(`variant_id`, `created_at`),
    INDEX `ix_inventory_movements_reference`(`reference_type`, `reference_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `carts` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `customer_id` BIGINT UNSIGNED NULL,
    `guest_token_hash` CHAR(64) NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'active',
    `expires_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_carts_guest_token_hash`(`guest_token_hash`),
    INDEX `ix_carts_customer_status`(`customer_id`, `status`),
    INDEX `ix_carts_status_expires`(`status`, `expires_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `cart_items` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `cart_id` BIGINT UNSIGNED NOT NULL,
    `variant_id` BIGINT UNSIGNED NOT NULL,
    `quantity` INTEGER UNSIGNED NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    INDEX `ix_cart_items_variant`(`variant_id`),
    UNIQUE INDEX `uq_cart_items_cart_variant`(`cart_id`, `variant_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `coupons` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code` VARCHAR(64) NOT NULL,
    `discount_type` VARCHAR(16) NOT NULL,
    `discount_value` DECIMAL(10, 2) NOT NULL,
    `max_discount_toman` BIGINT UNSIGNED NULL,
    `min_order_toman` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `usage_limit` INTEGER UNSIGNED NULL,
    `per_customer_limit` INTEGER UNSIGNED NULL,
    `first_order_only` BOOLEAN NOT NULL DEFAULT false,
    `starts_at` DATETIME(3) NULL,
    `ends_at` DATETIME(3) NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_coupons_code`(`code`),
    INDEX `ix_coupons_active_window`(`is_active`, `starts_at`, `ends_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `coupon_categories` (
    `coupon_id` BIGINT UNSIGNED NOT NULL,
    `category_id` BIGINT UNSIGNED NOT NULL,

    PRIMARY KEY (`coupon_id`, `category_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `coupon_products` (
    `coupon_id` BIGINT UNSIGNED NOT NULL,
    `product_id` BIGINT UNSIGNED NOT NULL,

    PRIMARY KEY (`coupon_id`, `product_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `shipping_methods` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(120) NOT NULL,
    `description` VARCHAR(500) NULL,
    `base_cost_toman` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `free_over_toman` BIGINT UNSIGNED NULL,
    `estimated_days_min` TINYINT UNSIGNED NULL,
    `estimated_days_max` TINYINT UNSIGNED NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    INDEX `ix_shipping_methods_active_order`(`is_active`, `sort_order`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `orders` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_number` VARCHAR(32) NOT NULL,
    `idempotency_key` VARCHAR(100) NOT NULL,
    `customer_id` BIGINT UNSIGNED NULL,
    `address_id` BIGINT UNSIGNED NULL,
    `shipping_method_id` BIGINT UNSIGNED NULL,
    `status` VARCHAR(32) NOT NULL DEFAULT 'pending_payment',
    `payment_status` VARCHAR(24) NOT NULL DEFAULT 'unpaid',
    `currency_unit` VARCHAR(8) NOT NULL DEFAULT 'TOMAN',
    `subtotal_toman` BIGINT UNSIGNED NOT NULL,
    `discount_toman` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `shipping_toman` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `total_toman` BIGINT UNSIGNED NOT NULL,
    `coupon_code_snapshot` VARCHAR(64) NULL,
    `recipient_name_snapshot` VARCHAR(160) NOT NULL,
    `recipient_phone_snapshot` VARCHAR(24) NOT NULL,
    `shipping_address_snapshot` JSON NOT NULL,
    `customer_note` VARCHAR(1000) NULL,
    `placed_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_orders_order_number`(`order_number`),
    UNIQUE INDEX `uq_orders_idempotency_key`(`idempotency_key`),
    INDEX `ix_orders_customer_created`(`customer_id`, `created_at`),
    INDEX `ix_orders_status_created`(`status`, `created_at`),
    INDEX `ix_orders_payment_status_created`(`payment_status`, `created_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `order_items` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_id` BIGINT UNSIGNED NOT NULL,
    `product_id` BIGINT UNSIGNED NULL,
    `variant_id` BIGINT UNSIGNED NULL,
    `product_name_snapshot` VARCHAR(220) NOT NULL,
    `sku_snapshot` VARCHAR(80) NOT NULL,
    `color_name_snapshot` VARCHAR(80) NOT NULL,
    `size_label_snapshot` VARCHAR(32) NOT NULL,
    `unit_price_toman` BIGINT UNSIGNED NOT NULL,
    `quantity` INTEGER UNSIGNED NOT NULL,
    `line_total_toman` BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `ix_order_items_order`(`order_id`),
    INDEX `ix_order_items_product`(`product_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `order_status_history` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_id` BIGINT UNSIGNED NOT NULL,
    `old_status` VARCHAR(32) NULL,
    `new_status` VARCHAR(32) NOT NULL,
    `note` VARCHAR(500) NULL,
    `visible_to_customer` BOOLEAN NOT NULL DEFAULT true,
    `changed_by_admin_id` BIGINT UNSIGNED NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `ix_order_status_history_order_created`(`order_id`, `created_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `payments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_id` BIGINT UNSIGNED NOT NULL,
    `provider` VARCHAR(64) NOT NULL,
    `idempotency_key` VARCHAR(100) NOT NULL,
    `amount_toman` BIGINT UNSIGNED NOT NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'initiated',
    `provider_transaction_id` VARCHAR(160) NULL,
    `provider_reference` VARCHAR(160) NULL,
    `response_code` VARCHAR(80) NULL,
    `verified_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_payments_idempotency_key`(`idempotency_key`),
    INDEX `ix_payments_order_created`(`order_id`, `created_at`),
    INDEX `ix_payments_provider_transaction`(`provider`, `provider_transaction_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `shipments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_id` BIGINT UNSIGNED NOT NULL,
    `provider` VARCHAR(80) NULL,
    `tracking_code` VARCHAR(120) NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'pending',
    `shipped_at` DATETIME(3) NULL,
    `delivered_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    INDEX `ix_shipments_order`(`order_id`),
    INDEX `ix_shipments_tracking`(`tracking_code`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `coupon_redemptions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `coupon_id` BIGINT UNSIGNED NOT NULL,
    `customer_id` BIGINT UNSIGNED NULL,
    `order_id` BIGINT UNSIGNED NOT NULL,
    `discount_toman` BIGINT UNSIGNED NOT NULL,
    `redeemed_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `ix_coupon_redemptions_customer`(`coupon_id`, `customer_id`),
    UNIQUE INDEX `uq_coupon_redemptions_order`(`coupon_id`, `order_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `wishlists` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `customer_id` BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `uq_wishlists_customer`(`customer_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `wishlist_items` (
    `wishlist_id` BIGINT UNSIGNED NOT NULL,
    `product_id` BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `ix_wishlist_items_product`(`product_id`),
    PRIMARY KEY (`wishlist_id`, `product_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `reviews` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `product_id` BIGINT UNSIGNED NOT NULL,
    `customer_id` BIGINT UNSIGNED NOT NULL,
    `order_item_id` BIGINT UNSIGNED NOT NULL,
    `rating` TINYINT UNSIGNED NOT NULL,
    `title` VARCHAR(160) NULL,
    `body` TEXT NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'pending',
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_reviews_order_item`(`order_item_id`),
    INDEX `ix_reviews_product_status_created`(`product_id`, `status`, `created_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `otp_requests` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `phone` VARCHAR(24) NOT NULL,
    `code_hash` CHAR(64) NOT NULL,
    `status` VARCHAR(24) NOT NULL DEFAULT 'pending',
    `attempt_count` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `expires_at` DATETIME(3) NOT NULL,
    `consumed_at` DATETIME(3) NULL,
    `request_ip` VARBINARY(16) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `ix_otp_requests_phone_status_created`(`phone`, `status`, `created_at`),
    INDEX `ix_otp_requests_expires`(`expires_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `banners` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(180) NOT NULL,
    `description` VARCHAR(500) NULL,
    `image_path` VARCHAR(500) NOT NULL,
    `target_url` VARCHAR(500) NULL,
    `starts_at` DATETIME(3) NULL,
    `ends_at` DATETIME(3) NULL,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    INDEX `ix_banners_active_window_order`(`is_active`, `starts_at`, `ends_at`, `sort_order`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `homepage_sections` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `section_key` VARCHAR(64) NOT NULL,
    `title` VARCHAR(180) NULL,
    `config` JSON NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT true,
    `sort_order` INTEGER NOT NULL DEFAULT 0,
    `updated_by_admin_id` BIGINT UNSIGNED NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    UNIQUE INDEX `uq_homepage_sections_key`(`section_key`),
    INDEX `ix_homepage_sections_active_order`(`is_active`, `sort_order`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `store_settings` (
    `setting_key` VARCHAR(100) NOT NULL,
    `setting_value` JSON NOT NULL,
    `is_public` BOOLEAN NOT NULL DEFAULT false,
    `updated_by_admin_id` BIGINT UNSIGNED NULL,
    `updated_at` DATETIME(3) NOT NULL,

    PRIMARY KEY (`setting_key`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- CreateTable
CREATE TABLE `admin_audit_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `admin_id` BIGINT UNSIGNED NULL,
    `action` VARCHAR(100) NOT NULL,
    `entity_type` VARCHAR(64) NOT NULL,
    `entity_id` BIGINT UNSIGNED NULL,
    `details` JSON NULL,
    `request_ip` VARBINARY(16) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `ix_admin_audit_logs_admin_created`(`admin_id`, `created_at`),
    INDEX `ix_admin_audit_logs_entity`(`entity_type`, `entity_id`, `created_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- AddForeignKey
ALTER TABLE `customer_addresses` ADD CONSTRAINT `customer_addresses_customer_id_fkey` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `categories` ADD CONSTRAINT `categories_parent_id_fkey` FOREIGN KEY (`parent_id`) REFERENCES `categories`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `products` ADD CONSTRAINT `products_category_id_fkey` FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `product_images` ADD CONSTRAINT `product_images_product_id_fkey` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `product_variants` ADD CONSTRAINT `product_variants_product_id_fkey` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `inventory_movements` ADD CONSTRAINT `inventory_movements_variant_id_fkey` FOREIGN KEY (`variant_id`) REFERENCES `product_variants`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `inventory_movements` ADD CONSTRAINT `inventory_movements_created_by_admin_id_fkey` FOREIGN KEY (`created_by_admin_id`) REFERENCES `admin_users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `carts` ADD CONSTRAINT `carts_customer_id_fkey` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `cart_items` ADD CONSTRAINT `cart_items_cart_id_fkey` FOREIGN KEY (`cart_id`) REFERENCES `carts`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `cart_items` ADD CONSTRAINT `cart_items_variant_id_fkey` FOREIGN KEY (`variant_id`) REFERENCES `product_variants`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `coupon_categories` ADD CONSTRAINT `coupon_categories_coupon_id_fkey` FOREIGN KEY (`coupon_id`) REFERENCES `coupons`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `coupon_categories` ADD CONSTRAINT `coupon_categories_category_id_fkey` FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `coupon_products` ADD CONSTRAINT `coupon_products_coupon_id_fkey` FOREIGN KEY (`coupon_id`) REFERENCES `coupons`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `coupon_products` ADD CONSTRAINT `coupon_products_product_id_fkey` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `orders` ADD CONSTRAINT `orders_customer_id_fkey` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `orders` ADD CONSTRAINT `orders_address_id_fkey` FOREIGN KEY (`address_id`) REFERENCES `customer_addresses`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `orders` ADD CONSTRAINT `orders_shipping_method_id_fkey` FOREIGN KEY (`shipping_method_id`) REFERENCES `shipping_methods`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `order_items` ADD CONSTRAINT `order_items_order_id_fkey` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `order_items` ADD CONSTRAINT `order_items_product_id_fkey` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `order_items` ADD CONSTRAINT `order_items_variant_id_fkey` FOREIGN KEY (`variant_id`) REFERENCES `product_variants`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `order_status_history` ADD CONSTRAINT `order_status_history_order_id_fkey` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `order_status_history` ADD CONSTRAINT `order_status_history_changed_by_admin_id_fkey` FOREIGN KEY (`changed_by_admin_id`) REFERENCES `admin_users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payments` ADD CONSTRAINT `payments_order_id_fkey` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `shipments` ADD CONSTRAINT `shipments_order_id_fkey` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `coupon_redemptions` ADD CONSTRAINT `coupon_redemptions_coupon_id_fkey` FOREIGN KEY (`coupon_id`) REFERENCES `coupons`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `coupon_redemptions` ADD CONSTRAINT `coupon_redemptions_customer_id_fkey` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `coupon_redemptions` ADD CONSTRAINT `coupon_redemptions_order_id_fkey` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `wishlists` ADD CONSTRAINT `wishlists_customer_id_fkey` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `wishlist_items` ADD CONSTRAINT `wishlist_items_wishlist_id_fkey` FOREIGN KEY (`wishlist_id`) REFERENCES `wishlists`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `wishlist_items` ADD CONSTRAINT `wishlist_items_product_id_fkey` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `reviews` ADD CONSTRAINT `reviews_product_id_fkey` FOREIGN KEY (`product_id`) REFERENCES `products`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `reviews` ADD CONSTRAINT `reviews_customer_id_fkey` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `reviews` ADD CONSTRAINT `reviews_order_item_id_fkey` FOREIGN KEY (`order_item_id`) REFERENCES `order_items`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `homepage_sections` ADD CONSTRAINT `homepage_sections_updated_by_admin_id_fkey` FOREIGN KEY (`updated_by_admin_id`) REFERENCES `admin_users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `store_settings` ADD CONSTRAINT `store_settings_updated_by_admin_id_fkey` FOREIGN KEY (`updated_by_admin_id`) REFERENCES `admin_users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `admin_audit_logs` ADD CONSTRAINT `admin_audit_logs_admin_id_fkey` FOREIGN KEY (`admin_id`) REFERENCES `admin_users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- Preserve domain invariants that are not expressible in Prisma schema syntax.
ALTER TABLE `product_variants`
  ADD CONSTRAINT `chk_product_variants_reservation`
  CHECK (`reserved_quantity` <= `stock_quantity`);

ALTER TABLE `coupons`
  ADD CONSTRAINT `chk_coupons_discount_type`
  CHECK (`discount_type` IN ('fixed', 'percentage'));

ALTER TABLE `coupons`
  ADD CONSTRAINT `chk_coupons_discount_value`
  CHECK (`discount_value` > 0);

ALTER TABLE `cart_items`
  ADD CONSTRAINT `chk_cart_items_quantity`
  CHECK (`quantity` > 0);

ALTER TABLE `orders`
  ADD CONSTRAINT `chk_orders_total`
  CHECK (`total_toman` + `discount_toman` = `subtotal_toman` + `shipping_toman`);

ALTER TABLE `orders`
  ADD CONSTRAINT `chk_orders_discount`
  CHECK (`discount_toman` <= `subtotal_toman`);

ALTER TABLE `order_items`
  ADD CONSTRAINT `chk_order_items_quantity`
  CHECK (`quantity` > 0);

ALTER TABLE `order_items`
  ADD CONSTRAINT `chk_order_items_total`
  CHECK (`line_total_toman` = `unit_price_toman` * `quantity`);

ALTER TABLE `reviews`
  ADD CONSTRAINT `chk_reviews_rating`
  CHECK (`rating` BETWEEN 1 AND 5);
