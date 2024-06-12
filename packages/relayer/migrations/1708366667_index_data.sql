-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `message_owner_event_type_chain_id_event_index` (`message_owner`, `event_type`, `chain_id`, `event`, `data`);
ADD INDEX `message_owner_event_type_chain_id_data_index` (`message_owner`, `event_type`, `chain_id`, `data`) 
ADD INDEX `message_owner_event_type_data_index` (`message_owner`, `event_type`, `data`),
ADD INDEX `message_owner_data_index` (`message_owner`, `data`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE events 
  DROP INDEX message_owner_event_type_chain_id_event_data_index,
  DROP INDEX message_owner_event_type_chain_id_data_index,
  DROP INDEX message_owner_event_type_data_index,
  DROP INDEX message_owner_data_index;
-- +goose StatementEnd
