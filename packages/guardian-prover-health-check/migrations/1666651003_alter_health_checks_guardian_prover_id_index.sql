-- +goose Up
-- +goose StatementBegin
ALTER TABLE `health_checks` ADD INDEX `health_checks_guardian_prover_id_index` (`guardian_prover_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX health_checks_guardian_prover_id_index on health_checks;
-- +goose StatementEnd
