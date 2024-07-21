-- +goose Up
-- +goose StatementBegin
ALTER TABLE `nft_metadata` ADD INDEX `nft_metadata_contract_address_token_id_chain_id_index` (`contract_address`, `token_id`, `chain_id`),
ADD INDEX `nft_metadata_contract_address_index` (`contract_address`)
;

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
ALTER TABLE nft_metadata DROP INDEX nft_metadata_contract_address_token_id_chain_id_index,
  DROP INDEX nft_metadata_contract_address;
-- +goose StatementEnd
