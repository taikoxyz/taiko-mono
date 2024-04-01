-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `event_transacted_at_tier_index` (`transacted_at`, `event`, `tier`), 
ADD INDEX `event_transacted_at_index` (`transacted_at`, `event`),
ADD INDEX `event_block_id_index` (`event`, `block_id`), 
ADD INDEX `event_tier_index` (`event`, `tier`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE events 
  DROP INDEX event_transacted_at_tier_index,
  DROP INDEX event_transacted_at_index,
  DROP INDEX event_block_id_index,
  DROP INDEX event_tier_index;
-- +goose StatementEnd
