-- +goose Up
-- +goose StatementBegin
ALTER TABLE `transactions` ADD INDEX `transacted_at_index` (`transacted_at`);
ALTER TABLE `transactions` ADD INDEX `transacted_at_contract_address_index` (`transacted_at`, `contract_address`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX transacted_at_index on transactions;
DROP INDEX transacted_at_contract_address_index on transactions;
-- +goose StatementEnd
