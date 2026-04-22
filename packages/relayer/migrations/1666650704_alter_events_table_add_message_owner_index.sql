-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `message_owner_index` (`message_owner`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX message_owner_index on events;
-- +goose StatementEnd