ALTER TABLE `orders`
  ADD COLUMN `reservation_expires_at` DATETIME(3) NULL AFTER `payment_status`;

CREATE INDEX `ix_orders_reservation_expiry`
  ON `orders` (`status`, `reservation_expires_at`);
