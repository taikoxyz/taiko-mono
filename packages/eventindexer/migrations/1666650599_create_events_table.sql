-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS events (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(20) NOT NULL,
    event VARCHAR(20) NOT NULL DEFAULT "",
    chain_id int NOT NULL,
    data JSON NOT NULL,
    address VARCHAR(42) NOT NULL DEFAULT "",
    block_id int DEFAULT NULL,
    amount DECIMAL(65, 0) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE events;
-- +goose StatementEnd
