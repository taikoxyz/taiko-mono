-- +goose Up
-- +goose StatementBegin
ALTER TABLE `accounts` ADD INDEX `transacted_at_index` (`transacted_at`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX transacted_at_index on accounts;
-- +goose StatementEnd
