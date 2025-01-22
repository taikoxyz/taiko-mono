-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events`
ADD COLUMN `fee` BIGINT UNSIGNED NULL,
ADD COLUMN `dest_chain_base_fee` BIGINT UNSIGNED NULL,
ADD COLUMN `gas_tip_cap` BIGINT UNSIGNED NULL,
ADD COLUMN `gas_limit` BIGINT UNSIGNED NULL,
ADD COLUMN `is_profitable` BOOLEAN NULL,
ADD COLUMN `estimated_onchain_fee` BIGINT UNSIGNED NULL,
ADD COLUMN `is_profitable_evaluated_at` TIMESTAMP NULL;

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE `events`
DROP COLUMN `fee`,
DROP COLUMN `dest_chain_base_fee`,
DROP COLUMN `gas_tip_cap`,
DROP COLUMN `gas_limit`,
DROP COLUMN `is_profitable`,
DROP COLUMN `estimated_onchain_fee`,
DROP COLUMN `is_profitable_evaluated_at`;
-- +goose StatementEnd
