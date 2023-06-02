-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS stats (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    average_proof_time VARCHAR(255) NOT NULL DEFAULT "0",
    average_proof_reward VARCHAR(255) NOT NULL DEFAULT "0",
    num_proofs int NOT NULL default 0,
    num_verified_blocks int NOT NULL default 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE stats;
-- +goose StatementEnd
