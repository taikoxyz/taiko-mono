-- Optimize query patterns used by the blob indexer

-- Support fast lookups of the canonical chain head and reorg handling
CREATE INDEX idx_blocks_canonical_slot ON blocks (canonical, slot DESC);

-- Replace the existing block_root index with one that also covers the canonical flag
ALTER TABLE blobs DROP INDEX idx_blobs_block_root;
CREATE INDEX idx_blobs_block_root_canonical ON blobs (block_root, canonical, blob_index);

-- Speed up pruning and canonicality updates that filter by canonical + slot range
CREATE INDEX idx_blobs_canonical_slot ON blobs (canonical, slot);
