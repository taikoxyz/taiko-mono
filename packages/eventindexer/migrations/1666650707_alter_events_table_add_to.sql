-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD COLUMN `to` VARCHAR(42) DEFAULT "";

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE `events` DROP COLUMN `to`;
-- +goose StatementEnd