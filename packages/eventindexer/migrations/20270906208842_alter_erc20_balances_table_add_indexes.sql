-- +goose Up
-- +goose StatementBegin
ALTER TABLE `erc20_balances` ADD INDEX `erc20_balance_chain_id_amount_address_index` (`chain_id`, `amount`, `address`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE erc20_balances 
  DROP INDEX erc20_balance_chain_id_amount_address_index
-- +goose StatementEnd
