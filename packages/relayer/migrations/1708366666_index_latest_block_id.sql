-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `idx_events_chain_ids` (`chain_id`, `dest_chain_id`, `event`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX idx_events_chain_ids on events;
-- +goose StatementEnd