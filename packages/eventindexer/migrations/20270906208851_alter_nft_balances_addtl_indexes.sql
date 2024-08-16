-- +goose Up
-- +goose StatementBegin
ALTER TABLE `nft_balances` ADD INDEX `nft_balances_address_chain_id_amount_index` (`address`, `chain_id`, `amount`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE nft_balances
  DROP INDEX nft_balances_address_chain_id_amount_index
-- +goose StatementEnd
