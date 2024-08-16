-- +goose Up
-- +goose StatementBegin
ALTER TABLE `signed_blocks` ADD INDEX `signed_blocks_recovered_address_index` (`recovered_address`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX signed_blocks_recovered_address_index on signed_blocks;
-- +goose StatementEnd
