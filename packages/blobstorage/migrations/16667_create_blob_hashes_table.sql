-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS blob_hashes (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    block_id BIGINT NOT NULL,
    emitted_block_id BIGINT NOT NULL,
    blob_hash VARCHAR(100) NOT NULL,
    kzg_commitment LONGTEXT NOT NULL,
    blob_data LONGTEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE blob_hashes;
-- +goose StatementEnd
