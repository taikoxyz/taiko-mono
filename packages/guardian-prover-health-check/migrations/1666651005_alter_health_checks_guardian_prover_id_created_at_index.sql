-- +goose Up
-- +goose StatementBegin
ALTER TABLE `health_checks` ADD INDEX `health_checks_guardian_prover_id_created_at_index` (`guardian_prover_id`, `created_at`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX health_checks_guardian_prover_id_created_at_index on health_checks;
-- +goose StatementEnd
