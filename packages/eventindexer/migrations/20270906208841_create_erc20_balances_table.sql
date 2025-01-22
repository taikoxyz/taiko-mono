-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS erc20_balances (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    erc20_metadata_id int NOT NULL,
    chain_id int NOT NULL,
    address VARCHAR(42) NOT NULL DEFAULT "",
    amount VARCHAR(200) DEFAULT "0",
    contract_address VARCHAR(42) NOT NULL DEFAULT "",
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (erc20_metadata_id, chain_id) REFERENCES erc20_metadata(id, chain_id)
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE erc20_balances;
-- +goose StatementEnd
