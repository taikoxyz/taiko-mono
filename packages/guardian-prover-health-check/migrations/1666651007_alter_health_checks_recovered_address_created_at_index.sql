-- +goose Up
-- +goose StatementBegin
ALTER TABLE `health_checks` ADD INDEX `health_checks_recovered_address_created_at_index` (`recovered_address`, `created_at`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX health_checks_recovered_address_created_at_index on health_checks;
-- +goose StatementEnd
