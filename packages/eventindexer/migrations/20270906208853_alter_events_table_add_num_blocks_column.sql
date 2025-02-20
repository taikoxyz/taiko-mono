-- +goose Up
-- +goose StatementBegin
ALTER TABLE events
ADD COLUMN num_blocks int DEFAULT NULL;

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE events DROP COLUMN num_blocks;
-- +goose StatementEnd
