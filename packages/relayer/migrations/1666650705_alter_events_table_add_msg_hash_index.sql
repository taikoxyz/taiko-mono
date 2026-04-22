-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `msg_hash_index` (`msg_hash`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX msg_hash_index on events;
-- +goose StatementEnd