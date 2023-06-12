-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `message_owner_chain_id_index` (`message_owner`,`chain_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX message_owner_chain_id_index on events;
-- +goose StatementEnd