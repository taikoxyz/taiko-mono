-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD COLUMN contract_address VARCHAR(42) DEFAULT "";

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE `events` DROP COLUMN contract_address;
-- +goose StatementEnd