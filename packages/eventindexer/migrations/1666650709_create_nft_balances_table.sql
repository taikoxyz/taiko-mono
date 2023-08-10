-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS nft_balances (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    chain_id int NOT NULL,
    address VARCHAR(42) NOT NULL DEFAULT "",
    amount DECIMAL(65, 0) DEFAULT NULL,
    contract_address VARCHAR(42) NOT NULL DEFAULT "",
    contract_type VARCHAR(7) NOT NULL DEFAULT "ERC721",
    token_id DECIMAL(65, 0) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE nft_balances;
-- +goose StatementEnd
