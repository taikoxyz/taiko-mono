-- +goose Up
-- +goose StatementBegin
ALTER TABLE events
ADD COLUMN batch_id int DEFAULT NULL;

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE events DROP COLUMN batch_id;
-- +goose StatementEnd
