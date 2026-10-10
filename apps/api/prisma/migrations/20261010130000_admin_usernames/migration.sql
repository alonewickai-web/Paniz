ALTER TABLE `admin_users`
    ADD COLUMN `username` VARCHAR(80) NULL;

UPDATE `admin_users`
SET `username` = CONCAT('admin', `id`)
WHERE `username` IS NULL;

ALTER TABLE `admin_users`
    MODIFY COLUMN `username` VARCHAR(80) NOT NULL,
    ADD UNIQUE INDEX `uq_admin_users_username` (`username`);
