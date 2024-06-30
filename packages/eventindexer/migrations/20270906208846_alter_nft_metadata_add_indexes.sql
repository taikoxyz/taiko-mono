-- +goose Up
-- +goose StatementBegin
ALTER TABLE `nft_metadata` ADD INDEX `nft_metadata_contract_address_token_id_index` (`contract_address`, `token_id`);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE nft_metadata
  DROP INDEX nft_metadata_contract_address_token_id_index
-- +goose StatementEnd
