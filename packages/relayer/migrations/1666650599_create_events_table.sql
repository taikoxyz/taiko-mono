-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS events (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    status int NOT NULL DEFAULT 0,
    event_type int NOT NULL DEFAULT 0,
    event VARCHAR(255) NOT NULL DEFAULT "",
    chain_id int NOT NULL,
    dest_chain_id int NOT NULL,
    synced_chain_id int DEFAULT NULL,
    emitted_block_id BIGINT NOT NULL,
    block_id BIGINT NOT NULL DEFAULT 0,
    synced_in_block_id BIGINT NOT NULL DEFAULT 0,
    sync_data VARCHAR(255) NOT NULL DEFAULT "",
    kind VARCHAR(255) NOT NULL DEFAULT "",
    data JSON NOT NULL,
    canonical_token_address VARCHAR(255) DEFAULT "",
    canonical_token_symbol VARCHAR(255) DEFAULT "",
    canonical_token_name VARCHAR(255) DEFAULT "",
    canonical_token_decimals int DEFAULT 0,
    amount VARCHAR(255) NOT NULL DEFAULT 0,
    msg_hash VARCHAR(255) NOT NULL DEFAULT "",
    message_owner VARCHAR(255) NOT NULL DEFAULT "",
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE events;
-- +goose StatementEnd
