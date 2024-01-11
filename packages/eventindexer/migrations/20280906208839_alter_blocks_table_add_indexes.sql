-- +goose Up
-- +goose StatementBegin
ALTER TABLE `blocks` ADD INDEX `transacted_at_index` (`transacted_at`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX transacted_at_index on blocks;
-- +goose StatementEnd
