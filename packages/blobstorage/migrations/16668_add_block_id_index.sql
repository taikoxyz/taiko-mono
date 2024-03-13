-- +goose Up
-- +goose StatementBegin
ALTER TABLE `blob_hashes` ADD INDEX `block_id_index` (`block_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX block_id_index on blob_hashes;
-- +goose StatementEnd