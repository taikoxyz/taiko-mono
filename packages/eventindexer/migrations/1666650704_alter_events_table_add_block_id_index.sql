-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `block_id_index` (`block_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX block_id_index on events;
-- +goose StatementEnd