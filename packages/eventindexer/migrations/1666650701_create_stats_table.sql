-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS stats (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    chain_id int NOT NULL,
    average_proof_time int NOT NULL DEFAULT 0,
    num_proofs int NOT NULL default 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE events;
-- +goose StatementEnd
