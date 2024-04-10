-- +goose Up
-- create a blob_hashes_temp with constraint blob_hash
CREATE TABLE IF NOT EXISTS blob_hashes_temp (
    id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    blob_hash VARCHAR(100) NOT NULL UNIQUE,
    kzg_commitment LONGTEXT NOT NULL,
    blob_data LONGTEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- migrate data to blob_hashes_temp
INSERT IGNORE INTO blob_hashes_temp (id, blob_hash, kzg_commitment, blob_data, created_at, updated_at)
SELECT id, blob_hash, kzg_commitment, blob_data, created_at, updated_at
FROM blob_hashes;

-- Update blob_hash references and indexes
UPDATE blocks_meta bm
JOIN blob_hashes_temp bh ON bm.blob_hash = bh.blob_hash
SET bm.blob_hash = bh.blob_hash;

ALTER TABLE blocks_meta DROP FOREIGN KEY blocks_meta_ibfk_1;

ALTER TABLE `blob_hashes_temp` ADD INDEX `blob_hash_index` (`blob_hash`);

-- make blob_hashes_temp the new blob_hashes
DROP TABLE IF EXISTS blob_hashes;
ALTER TABLE blob_hashes_temp RENAME TO blob_hashes;

-- +goose Down
-- create a blob_hashes_temp as original
CREATE TABLE IF NOT EXISTS blob_hashes_temp (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    block_id BIGINT NOT NULL,
    emitted_block_id BIGINT NOT NULL,
    blob_hash VARCHAR(100) NOT NULL,
    kzg_commitment LONGTEXT NOT NULL,
    blob_data LONGTEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- migrate data to blob_hashes_temp
INSERT INTO blob_hashes_temp (block_id, emitted_block_id, blob_hash, kzg_commitment, blob_data, created_at, updated_at)
SELECT
    bm.block_id,
    bm.emitted_block_id,
    bh.blob_hash,
    bh.kzg_commitment,
    bh.blob_data,
    bh.created_at,
    bh.updated_at
FROM
    blocks_meta bm
JOIN
    blob_hashes bh ON bm.blob_hash = bh.blob_hash;

-- Update blob_hash references and indexes
UPDATE blocks_meta bm
JOIN blob_hashes_temp bh ON bm.blob_hash = bh.blob_hash
SET bm.blob_hash = bh.blob_hash;

-- create blob_hash_index
ALTER TABLE `blob_hashes_temp` ADD INDEX `blob_hash_index` (`blob_hash`);

-- make blob_hashes_temp the new blob_hashes
DROP TABLE IF EXISTS blob_hashes;
ALTER TABLE blob_hashes_temp RENAME TO blob_hashes;
