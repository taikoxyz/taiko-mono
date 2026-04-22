-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS suspended_transactions (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    message_id int NOT NULL,
    src_chain_id int NOT NULL,
    dest_chain_id int NOT NULL,
    suspended boolean NOT NULL,
    msg_hash VARCHAR(255) NOT NULL,
    message_owner VARCHAR(255) NOT NULL DEFAULT "",
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE suspended_transactions;
-- +goose StatementEnd
