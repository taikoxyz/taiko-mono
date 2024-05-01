-- +goose Up
-- +goose StatementBegin
ALTER TABLE `blob_hashes` ADD INDEX `blob_hash_index` (`blob_hash`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX blob_hash_index on blob_hashes;
-- +goose StatementEnd