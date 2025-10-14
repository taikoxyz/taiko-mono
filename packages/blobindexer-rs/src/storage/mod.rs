use alloy_primitives::{B256, FixedBytes};
use chrono::{DateTime, Utc};
use sqlx::{
    Executor, MySql, MySqlPool, Row, Transaction,
    mysql::{MySqlPoolOptions, MySqlRow},
};

use crate::{
    errors::Result,
    models::{BlobRecord, BlockRecord},
};

const LAST_PROCESSED_SLOT_KEY: &str = "last_processed_slot";

#[derive(Clone)]
pub struct Storage {
    pool: MySqlPool,
}

impl Storage {
    pub async fn connect(database_url: &str) -> Result<Self> {
        let pool = MySqlPoolOptions::new()
            .max_connections(20)
            .connect(database_url)
            .await?;

        Ok(Self { pool })
    }

    pub async fn run_migrations(&self) -> Result<()> {
        sqlx::migrate!("./migrations").run(&self.pool).await?;
        Ok(())
    }

    pub fn pool(&self) -> &MySqlPool {
        &self.pool
    }

    pub async fn begin(&self) -> Result<Transaction<'_, MySql>> {
        Ok(self.pool.begin().await?)
    }

    pub async fn get_canonical_head(&self) -> Result<Option<BlockRecord>> {
        let row = sqlx::query(
            "SELECT slot, block_root, parent_root, timestamp, canonical
             FROM blocks
             WHERE canonical = TRUE
             ORDER BY slot DESC
             LIMIT 1",
        )
        .fetch_optional(self.pool())
        .await?;

        row.map(row_to_block).transpose()
    }

    pub async fn get_block_by_slot<'a, E>(
        &self,
        executor: E,
        slot: i64,
    ) -> Result<Option<BlockRecord>>
    where
        E: Executor<'a, Database = MySql>,
    {
        let row = sqlx::query(
            "SELECT slot, block_root, parent_root, timestamp, canonical
             FROM blocks
             WHERE slot = ?",
        )
        .bind(slot)
        .fetch_optional(executor)
        .await?;

        row.map(row_to_block).transpose()
    }

    pub async fn get_block_by_root<'a, E>(
        &self,
        executor: E,
        root: &B256,
    ) -> Result<Option<BlockRecord>>
    where
        E: Executor<'a, Database = MySql>,
    {
        let row = sqlx::query(
            "SELECT slot, block_root, parent_root, timestamp, canonical
             FROM blocks
             WHERE block_root = ?",
        )
        .bind(root.as_slice())
        .fetch_optional(executor)
        .await?;

        row.map(row_to_block).transpose()
    }

    pub async fn insert_or_update_block(
        &self,
        tx: &mut Transaction<'_, MySql>,
        block: &BlockRecord,
    ) -> Result<()> {
        sqlx::query(
            "INSERT INTO blocks (slot, block_root, parent_root, timestamp, canonical)
             VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                block_root = VALUES(block_root),
                parent_root = VALUES(parent_root),
                timestamp = VALUES(timestamp),
                canonical = VALUES(canonical),
                updated_at = CURRENT_TIMESTAMP",
        )
        .bind(block.slot)
        .bind(block.block_root.as_slice())
        .bind(block.parent_root.as_slice())
        .bind(block.timestamp)
        .bind(block.canonical)
        .execute(&mut **tx)
        .await?;

        Ok(())
    }

    pub async fn replace_blobs(
        &self,
        tx: &mut Transaction<'_, MySql>,
        slot: i64,
        blobs: &[BlobRecord],
    ) -> Result<()> {
        sqlx::query("DELETE FROM blobs WHERE slot = ?")
            .bind(slot)
            .execute(&mut **tx)
            .await?;

        for blob in blobs {
            sqlx::query(
                "INSERT INTO blobs (
                    slot,
                    block_root,
                    blob_index,
                    versioned_hash,
                    commitment,
                    proof,
                    blob,
                    canonical
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    block_root = VALUES(block_root),
                    versioned_hash = VALUES(versioned_hash),
                    commitment = VALUES(commitment),
                    proof = VALUES(proof),
                    blob = VALUES(blob),
                    canonical = VALUES(canonical)",
            )
            .bind(blob.slot)
            .bind(blob.block_root.as_slice())
            .bind(blob.index)
            .bind(blob.versioned_hash.as_slice())
            .bind(blob.commitment.as_slice())
            .bind(blob.proof.as_slice())
            .bind(&blob.blob)
            .bind(blob.canonical)
            .execute(&mut **tx)
            .await?;
        }

        Ok(())
    }

    pub async fn set_canonical_for_slots(
        &self,
        tx: &mut Transaction<'_, MySql>,
        slots: &[i64],
        canonical: bool,
    ) -> Result<()> {
        for slot in slots {
            sqlx::query(
                "UPDATE blocks SET canonical = ?, updated_at = CURRENT_TIMESTAMP WHERE slot = ?",
            )
            .bind(canonical)
            .bind(slot)
            .execute(&mut **tx)
            .await?;

            sqlx::query("UPDATE blobs SET canonical = ? WHERE slot = ?")
                .bind(canonical)
                .bind(slot)
                .execute(&mut **tx)
                .await?;
        }

        Ok(())
    }

    pub async fn mark_non_canonical_after_slot(
        &self,
        tx: &mut Transaction<'_, MySql>,
        slot: i64,
    ) -> Result<()> {
        sqlx::query(
            "UPDATE blocks SET canonical = FALSE, updated_at = CURRENT_TIMESTAMP
             WHERE canonical = TRUE AND slot > ?",
        )
        .bind(slot)
        .execute(&mut **tx)
        .await?;

        sqlx::query(
            "UPDATE blobs SET canonical = FALSE
             WHERE canonical = TRUE AND slot > ?",
        )
        .bind(slot)
        .execute(&mut **tx)
        .await?;

        Ok(())
    }

    pub async fn set_last_processed_slot(
        &self,
        tx: &mut Transaction<'_, MySql>,
        slot: i64,
    ) -> Result<()> {
        sqlx::query(
            "INSERT INTO metadata (cfg_key, cfg_value) VALUES (?, ?)
             ON DUPLICATE KEY UPDATE cfg_value = GREATEST(cfg_value, VALUES(cfg_value))",
        )
        .bind(LAST_PROCESSED_SLOT_KEY)
        .bind(slot)
        .execute(&mut **tx)
        .await?;

        Ok(())
    }

    pub async fn get_last_processed_slot(&self) -> Result<Option<i64>> {
        let row = sqlx::query("SELECT cfg_value FROM metadata WHERE cfg_key = ?")
            .bind(LAST_PROCESSED_SLOT_KEY)
            .fetch_optional(self.pool())
            .await?;

        Ok(row.map(|row| row.get::<i64, _>("cfg_value")))
    }

    pub async fn prune_non_canonical_before_slot(&self, slot: i64) -> Result<()> {
        sqlx::query("DELETE FROM blobs WHERE canonical = FALSE AND slot < ?")
            .bind(slot)
            .execute(self.pool())
            .await?;

        sqlx::query("DELETE FROM blocks WHERE canonical = FALSE AND slot < ?")
            .bind(slot)
            .execute(self.pool())
            .await?;

        Ok(())
    }

    pub async fn get_blobs_by_slot(&self, slot: i64) -> Result<Vec<BlobRecord>> {
        let rows = sqlx::query(
            "SELECT slot, block_root, blob_index, versioned_hash, commitment, proof, blob, canonical
             FROM blobs
             WHERE slot = ? AND canonical = TRUE
             ORDER BY blob_index ASC",
        )
        .bind(slot)
        .fetch_all(self.pool())
        .await?;

        rows.into_iter().map(row_to_blob).collect()
    }

    pub async fn get_blobs_by_block_root(&self, block_root: &B256) -> Result<Vec<BlobRecord>> {
        let rows = sqlx::query(
            "SELECT slot, block_root, blob_index, versioned_hash, commitment, proof, blob, canonical
             FROM blobs
             WHERE block_root = ? AND canonical = TRUE
             ORDER BY blob_index ASC",
        )
        .bind(block_root.as_slice())
        .fetch_all(self.pool())
        .await?;

        rows.into_iter().map(row_to_blob).collect()
    }

    pub async fn get_blob_by_versioned_hash(
        &self,
        versioned_hash: &B256,
    ) -> Result<Option<BlobRecord>> {
        let row = sqlx::query(
            "SELECT slot, block_root, blob_index, versioned_hash, commitment, proof, blob, canonical
             FROM blobs
             WHERE versioned_hash = ?",
        )
        .bind(versioned_hash.as_slice())
        .fetch_optional(self.pool())
        .await?;

        row.map(row_to_blob).transpose()
    }

    pub async fn get_latest_slot(&self) -> Result<Option<i64>> {
        let row = sqlx::query("SELECT MAX(slot) AS slot FROM blocks")
            .fetch_one(self.pool())
            .await?;

        Ok(row.try_get::<Option<i64>, _>("slot")?)
    }
}

fn row_to_block(row: MySqlRow) -> Result<BlockRecord> {
    let slot: i64 = row.get("slot");
    let block_root: Vec<u8> = row.get("block_root");
    let parent_root: Vec<u8> = row.get("parent_root");
    let timestamp = row
        .try_get::<Option<DateTime<Utc>>, _>("timestamp")
        .unwrap_or(None);
    let canonical: bool = row.get("canonical");

    Ok(BlockRecord {
        slot,
        block_root: B256::from_slice(&block_root),
        parent_root: B256::from_slice(&parent_root),
        timestamp,
        canonical,
    })
}

fn row_to_blob(row: MySqlRow) -> Result<BlobRecord> {
    let slot: i64 = row.get("slot");
    let block_root: Vec<u8> = row.get("block_root");
    let blob_index: i32 = row.get("blob_index");
    let versioned_hash: Vec<u8> = row.get("versioned_hash");
    let commitment: Vec<u8> = row.get("commitment");
    let proof: Vec<u8> = row.get("proof");
    let blob: Vec<u8> = row.get("blob");
    let canonical: bool = row.get("canonical");

    Ok(BlobRecord {
        slot,
        block_root: B256::from_slice(&block_root),
        index: blob_index,
        versioned_hash: B256::from_slice(&versioned_hash),
        commitment: FixedBytes::<48>::from_slice(&commitment),
        proof: FixedBytes::<48>::from_slice(&proof),
        blob,
        canonical,
    })
}
