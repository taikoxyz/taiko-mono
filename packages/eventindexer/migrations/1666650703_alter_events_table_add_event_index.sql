-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `event_index` (`event`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX event_index on events;
-- +goose StatementEnd
