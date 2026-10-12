ALTER TABLE `banners`
    ADD COLUMN `eyebrow_text` VARCHAR(120) NULL,
    ADD COLUMN `button_label` VARCHAR(80) NULL,
    ADD COLUMN `button_side_text` VARCHAR(120) NULL,
    ADD COLUMN `sticker_label` VARCHAR(80) NULL,
    ADD COLUMN `sticker_text` VARCHAR(180) NULL,
    ADD COLUMN `background_color` CHAR(7) NULL;
