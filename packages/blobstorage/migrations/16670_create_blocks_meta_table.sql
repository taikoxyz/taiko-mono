-- +goose Up
-- create blocks_meta table
CREATE TABLE IF NOT EXISTS blocks_meta (
    block_id BIGINT NOT NULL PRIMARY KEY,
    blob_hash VARCHAR(100) NOT NULL,
    emitted_block_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (blob_hash) REFERENCES blob_hashes(blob_hash)
);

-- migrate data into blocks_meta
INSERT INTO blocks_meta (block_id, blob_hash, emitted_block_id, created_at, updated_at)
SELECT block_id, blob_hash, emitted_block_id, created_at, updated_at
FROM blob_hashes;

-- update indexes
DROP INDEX block_id_index on blob_hashes;
ALTER TABLE blocks_meta ADD INDEX `block_id_index` (`block_id`);

-- +goose Down
-- reverse indexes
DROP INDEX block_id_index on blocks_meta;
ALTER TABLE blob_hashes ADD INDEX `block_id_index` (`block_id`);

-- drop blocks_meta table
DROP TABLE IF EXISTS blocks_meta;
