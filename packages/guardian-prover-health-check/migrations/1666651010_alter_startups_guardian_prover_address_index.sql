-- +goose Up
-- +goose StatementBegin
ALTER TABLE `startups` ADD INDEX `startups_guardian_prover_address_index` (`guardian_prover_address`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX startups_guardian_prover_address_index on startups;
-- +goose StatementEnd
