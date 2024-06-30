-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS nft_metadata (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    chain_id int NOT NULL,
    contract_address VARCHAR(42) NOT NULL,
    token_id DECIMAL(65, 0) NOT NULL,
    name VARCHAR(255) DEFAULT NULL,
    description TEXT DEFAULT NULL,
    symbol VARCHAR(10) DEFAULT NULL,
    attributes JSON DEFAULT NULL,
    image_url TEXT DEFAULT NULL,
    image_data TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE (contract_address, token_id)
);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE nft_metadata;
-- +goose StatementEnd
