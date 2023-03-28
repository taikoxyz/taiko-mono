-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS events (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    event VARCHAR(255) NOT NULL DEFAULT "",
    chain_id int NOT NULL,
    data JSON NOT NULL,
    address VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE events;
-- +goose StatementEnd
