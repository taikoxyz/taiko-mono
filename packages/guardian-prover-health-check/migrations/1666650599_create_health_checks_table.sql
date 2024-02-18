-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS health_checks (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    guardian_prover_id int NOT NULL,
    alive BOOLEAN NOT NULL DEFAULT false,
    expected_address VARCHAR(42) NOT NULL,
    recovered_address VARCHAR(42) NOT NULL DEFAULT "",
    signed_response VARCHAR(5000) NOT NULL DEFAULT "",
    latest_l1_block BIGINT NOT NULL,
    latest_l2_block BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE health_checks;
-- +goose StatementEnd