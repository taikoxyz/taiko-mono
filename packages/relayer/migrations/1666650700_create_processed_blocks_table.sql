-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS processed_blocks (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    block_height int NOT NULL,
    hash VARCHAR(255) NOT NULL UNIQUE,
    chain_id int NOT NULL,
    event_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE processed_blocks;
-- +goose StatementEnd

