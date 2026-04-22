-- +goose Up
-- +goose StatementBegin
ALTER TABLE `erc20_metadata` ADD INDEX `erc20_balance_chain_id_contract_address_index` (`chain_id`, `contract_address`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE erc20_metadata 
  DROP INDEX erc20_balance_chain_id_contract_address_index
-- +goose StatementEnd
