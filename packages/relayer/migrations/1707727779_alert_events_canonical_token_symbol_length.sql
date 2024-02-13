-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` MODIFY COLUMN `canonical_token_symbol` VARCHAR(255);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE `events` MODIFY COLUMN `canonical_token_symbol` VARCHAR(10);
-- +goose StatementEnd
