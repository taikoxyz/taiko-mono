-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `events_block_id_event_index` (`block_id`, `event`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE events 
  DROP INDEX events_block_id_event_index
-- +goose StatementEnd
