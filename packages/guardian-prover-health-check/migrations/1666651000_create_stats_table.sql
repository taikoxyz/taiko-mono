-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS stats (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    guardian_prover_id int NOT NULL,
    date VARCHAR(20) NOT NULL,
    requests int NOT NULL,
    successful_requests int NOT NULL,
    uptime FLOAT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
     UNIQUE key `guardian_prover_id_date` (`guardian_prover_id`, `date`)
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE stats;
-- +goose StatementEnd