-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS blob_hashes (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    block_id BIGINT NOT NULL,
    blob_hash VARCHAR(42) NOT NULL,
    kzg_commitment TEXT NOT NULL,
    block_timestamp BIGINT NOT NULL,
    blob_data TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE blob_hashes;
-- +goose StatementEnd
