-- +goose Up
-- +goose StatementBegin
ALTER TABLE nft_metadata MODIFY symbol VARCHAR(42) DEFAULT NULL;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE nft_metadata MODIFY symbol VARCHAR(10) DEFAULT NULL;
-- +goose StatementEnd