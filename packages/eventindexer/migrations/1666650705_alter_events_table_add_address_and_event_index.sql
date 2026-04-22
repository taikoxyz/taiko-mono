-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `address_and_event_index` (`address`, `event`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX address_and_event_index on events;
-- +goose StatementEnd
