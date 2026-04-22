-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `message_owner_event_index` (`message_owner`,`event`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX message_owner_event_index on events;
-- +goose StatementEnd