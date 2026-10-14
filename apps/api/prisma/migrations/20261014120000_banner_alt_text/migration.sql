ALTER TABLE `banners`
  ADD COLUMN `alt_text` VARCHAR(180) NULL AFTER `title`;

UPDATE `banners`
SET `alt_text` = `title`
WHERE `alt_text` IS NULL;
