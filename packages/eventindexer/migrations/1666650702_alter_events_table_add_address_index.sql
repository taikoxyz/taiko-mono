-- +goose Up
-- +goose StatementBegin
ALTER TABLE `events` ADD INDEX `address_index` (`address`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP INDEX address_index on events;
-- +goose StatementEnd
