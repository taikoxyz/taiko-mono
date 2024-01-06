-- +goose Up
-- +goose StatementBegin
ALTER TABLE events
ADD COLUMN tier int DEFAULT NULL;

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE tier;
-- +goose StatementEnd
