-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS startups (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    guardian_prover_id int NOT NULL,
    guardian_prover_address VARCHAR(42) NOT NULL,
    revision VARCHAR(255) NOT NULL,
    guardian_version VARCHAR(255) NOT NULL,
    l1_node_version VARCHAR(255) NOT NULL,
    l2_node_version VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE startups;
-- +goose StatementEnd