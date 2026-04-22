-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `idx_ev_name_cid_scid_bid` (`name`, `chain_id`, `synced_chain_id`, `block_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX idx_ev_name_cid_scid_bid on events;
-- +goose StatementEnd