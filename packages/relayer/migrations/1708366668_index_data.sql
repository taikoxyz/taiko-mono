-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` 
ADD INDEX `message_owner_event_type_chain_id_event_data_index` (`message_owner`, `dest_owner_json`, `event_type`, `chain_id`, `event`),
ADD INDEX `message_owner_event_type_chain_id_data_index` (`message_owner`, `dest_owner_json`, `event_type`, `chain_id`), 
ADD INDEX `message_owner_event_type_data_index` (`message_owner`, `dest_owner_json`, `event_type`),
ADD INDEX `message_owner_data_index` (`message_owner`, `dest_owner_json`),
ADD INDEX `message_owner_chain_id_data_index` (`message_owner`, `dest_owner_json`, `chain_id`),
ADD INDEX `message_owner_event_data_index` (`message_owner`, `dest_owner_json`, `event`),
ADD INDEX `msg_hash_event_data_index` (`msg_hash`, `dest_owner_json`, `event`),
ADD INDEX `data_event_type_chain_id_index` (`event_type`,`dest_owner_json`, `chain_id`), 
ADD INDEX `data_event_type_index` (`dest_owner_json`, `event_type`),
ADD INDEX `data_index` (`dest_owner_json`),
ADD INDEX `data_chain_id_index` (`dest_owner_json`, `chain_id`),
ADD INDEX `data_event_index` (`dest_owner_json`, `event`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE `events` 
  DROP INDEX `message_owner_event_type_chain_id_event_data_index`,
  DROP INDEX `message_owner_event_type_chain_id_data_index`,
  DROP INDEX `message_owner_event_type_data_index`,
  DROP INDEX `message_owner_data_index`,
  DROP INDEX `message_owner_chain_id_data_index`,
  DROP INDEX `message_owner_event_data_index`,
  DROP INDEX `msg_hash_event_data_index`,
  DROP INDEX `data_event_type_chain_id_index`,
  DROP INDEX `data_event_type_index`,
  DROP INDEX `data_index`,
  DROP INDEX `data_chain_id_index`,
  DROP INDEX `data_event_index`;
-- +goose StatementEnd
