-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS blocks (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    chain_id int not null,
    block_id int not null unique,
    transacted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE blocks;
-- +goose StatementEnd
