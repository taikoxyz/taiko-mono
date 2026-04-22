-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS erc20_metadata (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    chain_id int NOT NULL,
    symbol varchar(42) NOT NULL,
    decimals int NOT NULL,
    contract_address varchar(42) not null,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY (id, chain_id)
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE erc20_metadata;
-- +goose StatementEnd
