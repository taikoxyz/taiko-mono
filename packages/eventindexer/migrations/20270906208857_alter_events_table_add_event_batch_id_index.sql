-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `events_event_batch_id_index` (`event`, `batch_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE events
  DROP INDEX events_event_batch_id_index
-- +goose StatementEnd
