-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `msg_hash_event_index` (`msg_hash`, `event`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX msg_hash_event_index on events;
-- +goose StatementEnd