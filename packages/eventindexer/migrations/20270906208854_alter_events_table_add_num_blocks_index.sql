-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `events_block_id_event_num_blocks_index` (`block_id`, `event`, `num_blocks`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE events
  DROP INDEX events_block_id_event_num_blocks_index
-- +goose StatementEnd
