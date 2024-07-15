-- +goose Up
-- +goose StatementBegin
ALTER TABLE nft_balances
    ADD COLUMN nft_metadata_id INT NULL DEFAULT 0,
    ADD CONSTRAINT fk_nft_balances_nft_metadata
    FOREIGN KEY (nft_metadata_id) REFERENCES nft_metadata(id);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE nft_balances
    DROP FOREIGN KEY fk_nft_balances_nft_metadata,
    DROP COLUMN nft_metadata_id;
-- +goose StatementEnd
