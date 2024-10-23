-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events`
  MODIFY COLUMN `chain_id` BIGINT UNSIGNED NOT NULL,
  MODIFY COLUMN `dest_chain_id` BIGINT UNSIGNED NOT NULL,
  MODIFY COLUMN `synced_chain_id` BIGINT UNSIGNED NOT NULL;

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE `events`
  MODIFY COLUMN `chain_id` INT NOT NULL,
  MODIFY COLUMN `dest_chain_id` INT NOT NULL,
  MODIFY COLUMN `synced_chain_id` INT NOT NULL;
-- +goose StatementEnd
