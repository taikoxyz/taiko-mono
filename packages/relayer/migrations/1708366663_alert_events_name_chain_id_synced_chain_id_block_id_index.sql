-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `events_name_chain_id_synced_chain_id_block_id_index` (`name`, `chain_id`, `synced_chain_id`, `block_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX events_name_chain_id_synced_chain_id_block_id_index on events;
-- +goose StatementEnd