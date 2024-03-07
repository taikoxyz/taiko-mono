-- +goose Up
-- +goose StatementBegin
ALTER TABLE `processed_blocks` ADD INDEX `idx_processed_blocks_on_chain_dest_chain_event_block` (`chain_id`, `dest_chain_id`, `event_name`, `block_height`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX idx_processed_blocks_on_chain_dest_chain_event_block on processed_blocks;
-- +goose StatementEnd