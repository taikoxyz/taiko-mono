-- +goose Up
-- +goose StatementBegin
ALTER TABLE events
ADD COLUMN tier int DEFAULT NULL;

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE events DROP COLUMN tier;
-- +goose StatementEnd
