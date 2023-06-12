-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `message_owner_event_type_chain_id_event_index` (`message_owner`, `event_type`, `chain_id`, `event`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX message_owner_event_type_chain_id_event_index on events;
-- +goose StatementEnd