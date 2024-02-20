-- +goose Up
-- +goose StatementBegin
ALTER TABLE `processed_blocks` ADD INDEX `processed_blocks_block_height_index` (`block_height`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX processed_blocks_block_height_index on processed_blocks;
-- +goose StatementEnd
