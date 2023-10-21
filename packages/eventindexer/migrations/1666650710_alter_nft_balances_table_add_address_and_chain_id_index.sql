-- +goose Up
-- +goose StatementBegin
ALTER TABLE `nft_balances` ADD INDEX `address_and_chain_id_index` (`address`, `chain_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX address_and_chain_id_index on nft_balances;
-- +goose StatementEnd
