-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS stats (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    average_proof_time VARCHAR(255)  DEFAULT "0",
    average_proof_reward VARCHAR(255)  DEFAULT "0",
    stat_type varchar(22) NOT NULL,
    num_proofs int  default 0,
    num_verified_blocks int default 0,
    num_blocks_assigned int default 0,
    fee_token_address VARCHAR(42) DEFAULT "",
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE stats;
-- +goose StatementEnd
