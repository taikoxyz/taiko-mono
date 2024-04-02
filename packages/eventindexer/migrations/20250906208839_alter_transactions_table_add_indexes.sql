-- +goose Up
-- +goose StatementBegin
ALTER TABLE `transactions` ADD INDEX transacted_at_index(`transacted_at`), 
ADD INDEX transacted_at_contract_address_index(`transacted_at`, `contract_address`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE `transactions` 
DROP INDEX transacted_at_index,
DROP INDEX transacted_at_contract_address_index;
-- +goose StatementEnd
