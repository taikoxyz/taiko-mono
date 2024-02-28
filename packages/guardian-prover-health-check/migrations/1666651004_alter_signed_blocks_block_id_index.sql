-- +goose Up
-- +goose StatementBegin
ALTER TABLE `signed_blocks` ADD INDEX `signed_blocks_block_id_index` (`block_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX signed_blocks_block_id_index on signed_blocks;
-- +goose StatementEnd
