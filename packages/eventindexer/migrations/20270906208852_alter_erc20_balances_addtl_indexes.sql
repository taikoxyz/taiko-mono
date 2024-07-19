-- +goose Up
-- +goose StatementBegin
ALTER TABLE `erc20_balances` ADD INDEX `erc20_balances_contract_address_address_chain_id_index` (`contract_address`, `address`, `chain_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE erc20_balances DROP INDEX erc20_balances_contract_address_address_chain_id_index,
  DROP INDEX erc20_balances_contract_address-- +goose StatementEnd
