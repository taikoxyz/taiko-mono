-- tables
CREATE TABLE blocks (
    slot BIGINT PRIMARY KEY,
    block_root BINARY(32) NOT NULL UNIQUE,
    parent_root BINARY(32) NOT NULL,
    timestamp TIMESTAMP NULL DEFAULT NULL,
    canonical TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE INDEX idx_blocks_parent_root ON blocks(parent_root);

CREATE TABLE blobs (
    slot BIGINT NOT NULL,
    block_root BINARY(32) NOT NULL,
    blob_index INT NOT NULL,
    versioned_hash BINARY(32) NOT NULL,
    commitment BINARY(48) NOT NULL,
    proof BINARY(48) NOT NULL,
    blob_data LONGBLOB NOT NULL,
    canonical TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (slot, blob_index),
    CONSTRAINT fk_blobs_block FOREIGN KEY (slot) REFERENCES blocks(slot) ON DELETE CASCADE
) ENGINE=InnoDB;

-- unique + non-unique indexes (same idempotent pattern)
CREATE UNIQUE INDEX idx_blobs_versioned_hash ON blobs(versioned_hash);

CREATE INDEX idx_blobs_block_root ON blobs(block_root);

CREATE TABLE metadata (
    cfg_key VARCHAR(255) PRIMARY KEY,
    cfg_value BIGINT NOT NULL
) ENGINE=InnoDB;
