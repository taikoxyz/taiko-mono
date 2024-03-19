-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS events (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(24) NOT NULL,
    event VARCHAR(24) NOT NULL DEFAULT "",
    chain_id int NOT NULL,
    data JSON NOT NULL,
    address VARCHAR(42) NOT NULL DEFAULT "",
    block_id int DEFAULT NULL,
    emitted_block_id BIGINT NOT NULL,
    amount DECIMAL(65, 0) DEFAULT NULL,
    proof_reward VARCHAR(255) DEFAULT NULL,
    proposer_reward VARCHAR(255) DEFAULT NULL,
    assigned_prover VARCHAR(42) NOT NULL DEFAULT "",
    fee_token_address varchar(42) DEFAULT "",
    transacted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE events;
-- +goose StatementEnd
