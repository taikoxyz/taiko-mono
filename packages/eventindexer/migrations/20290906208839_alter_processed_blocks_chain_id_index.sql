-- +goose Up
-- +goose StatementBegin
ALTER TABLE `processed_blocks` ADD INDEX `processed_blocks_chain_id_index` (`chain_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX processed_blocks_chain_id_index on processed_blocks;
-- +goose StatementEnd
