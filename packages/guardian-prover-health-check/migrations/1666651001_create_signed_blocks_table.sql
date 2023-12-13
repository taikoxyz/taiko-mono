-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS signed_blocks (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    guardian_prover_id int NOT NULL,
    block_id int NOT NULL,
    signature varchar(5000) NOT NULL,
    block_hash VARCHAR(255) NOT NULL,
    recovered_address varchar(42) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE key `guardian_prover_id_block_id` (`guardian_prover_id`, `block_id`),
    UNIQUE key `guardian_prover_id_block_hash` (`guardian_prover_id`, `block_hash`)
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE signed_blocks;
-- +goose StatementEnd