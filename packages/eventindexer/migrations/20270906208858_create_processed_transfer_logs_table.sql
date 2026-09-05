-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS processed_transfer_logs (
    id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    chain_id int NOT NULL,
    tx_hash VARCHAR(66) NOT NULL,
    log_index int NOT NULL,
    batch_index int NOT NULL DEFAULT 0,
    kind VARCHAR(8) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY processed_transfer_logs_unique (chain_id, tx_hash, log_index, batch_index, kind)
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE processed_transfer_logs;
-- +goose StatementEnd
