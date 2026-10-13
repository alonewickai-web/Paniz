ALTER TABLE `customers`
  ADD COLUMN `birth_date_jalali` CHAR(10) NULL;

ALTER TABLE `customer_addresses`
  ADD COLUMN `floor` VARCHAR(40) NULL,
  ADD COLUMN `backup_phone` VARCHAR(24) NULL,
  ADD COLUMN `latitude` DOUBLE NULL,
  ADD COLUMN `longitude` DOUBLE NULL;
