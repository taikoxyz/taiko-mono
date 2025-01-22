-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD COLUMN `dest_owner_json` VARCHAR(255) AS (JSON_UNQUOTE(JSON_EXTRACT(`data`, '$.Message.DestOwner'))) STORED;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE `events` DROP COLUMN `dest_owner_json`;
-- +goose StatementEnd