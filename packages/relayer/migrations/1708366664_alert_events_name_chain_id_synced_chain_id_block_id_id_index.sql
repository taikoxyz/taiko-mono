-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `events_name_cid_scid_bid` (`name`, `chain_id`, `synced_chain_id`, `block_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX events_name_cid_scid_bid on events;
-- +goose StatementEnd