-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS transactions (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    chain_id int not null,
    sender varchar(42) not null,
    recipient varchar(42) default null,
    block_id int not null,
    amount DECIMAL(65, 0) DEFAULT NULL,
    gas_price varchar(20) not null,
    contract_address varchar(42) default "",
    transacted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE transactions;
-- +goose StatementEnd
