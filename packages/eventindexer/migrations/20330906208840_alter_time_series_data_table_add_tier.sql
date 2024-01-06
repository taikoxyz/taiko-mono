-- +goose Up
-- +goose StatementBegin
ALTER TABLE time_series_data
ADD COLUMN tier int DEFAULT NULL;

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE tier;
-- +goose StatementEnd
