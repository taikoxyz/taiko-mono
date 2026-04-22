-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD COLUMN token_id int DEFAULT NULL;

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE `events` DROP COLUMN token_id;
-- +goose StatementEnd