-- +goose Up
-- +goose StatementBegin
ALTER TABLE `nft_balances` ADD INDEX `address_contract_address_token_id_and_chain_id_index` (`address`, `contract_address`, `token_id`, `chain_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX address_contract_address_token_id_and_chain_id_index on nft_balances;
-- +goose StatementEnd
