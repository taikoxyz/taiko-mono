-- +goose Up
-- +goose StatementBegin
ALTER TABLE `health_checks` ADD INDEX `health_checks_recovered_address_index` (`recovered_address`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX health_checks_recovered_address_index on health_checks;
-- +goose StatementEnd
