-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `events_chain_id_synced_chain_id_block_id_index` (`chain_id`, `synced_chain_id`, `block_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX events_chain_id_synced_chain_id_block_id_index on events;
-- +goose StatementEnd