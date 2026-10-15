//! The planter: writes Etna Inbox and staking-registry state into anvil following
//! `abci::l1::layout` (the Inbox slots, the registry checkpoints and its live `entries` array).
//!
//! Writes are real transactions, not `anvil_setStorageAt`: anvil stores block `n`'s historical
//! state when it starts mining block `n + 1`, so an out-of-band `anvil_setStorageAt` made in
//! between leaks into block `n`'s state, and `eth_getProof` / `eth_getStorageAt` at `n` then
//! disagree with `n`'s header `stateRoot`. [`Planter::install`] therefore places a tiny
//! storage-setter contract ([`setter_code`]) at both addresses once, before the genesis block,
//! and every later write is a transaction to it from anvil's first dev account.
//!
//! anvil also keeps every zero `SSTORE` as an explicit zero leaf, so zeros are never written:
//! a zero for a slot that reads zero is skipped and clearing a non-zero slot is an error.
//!
//! As the Inbox holds the setter, forced inclusion entries cannot be submitted through
//! `saveForcedInclusion`: [`Planter::plant_forced_transaction`] writes an entry's slots instead,
//! and emits the admission event in the same mined transaction.

use std::{sync::Arc, time::Duration};

use abci::{
    GenesisRecord, RegistryEntry,
    committee::entries_root,
    l1::layout::{inbox, registry},
};
use alloy::sol_types::SolCall;
use alloy_eips::{BlockId, BlockNumberOrTag};
alloy::sol!(InboxSetter, "contracts/InboxSetter.json");
use alloy_primitives::{Address, B256, Bytes, U256, address, keccak256};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result, bail, ensure};
use serde_json::{Value, json};
use tokio::sync::{Mutex, OwnedMutexGuard};

use crate::{
    l1::{anvil_request, block_number, mine_l1_blocks, set_interval_mining},
    wait::wait_until,
};

/// Generated runtime for atomic forced-transaction admission and raw storage fallback.
fn setter_code() -> Bytes {
    let artifact: Value = serde_json::from_str(include_str!("../contracts/InboxSetter.json"))
        .expect("generated artifact");
    artifact["deployedBytecode"]["object"].as_str().expect("runtime").parse().expect("runtime hex")
}

/// anvil's first dev account (unlocked), the sender of every planting transaction.
const SENDER: Address = address!("f39Fd6e51aad88F6F4ce6aB8827279cffFb92266");

/// Deadline for a planting transaction's receipt.
const RECEIPT_TIMEOUT: Duration = Duration::from_secs(30);

/// The fee recorded in every planted forced inclusion entry: 0.001 ETH, in gwei.
const FORCED_INCLUSION_FEE_GWEI: u64 = 1_000_000;

/// The mask of a `uint48` field of the forced inclusion queue's head/tail word.
const U48_MASK: u64 = (1 << 48) - 1;

/// One calldata entry admitted by a real mined setter transaction.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PlantedEntry {
    /// Queue index.
    pub index: u64,
    /// Hash of the exact admission bytes.
    pub tx_hash: B256,
    /// L1 submission timestamp.
    pub timestamp: u64,
    /// L1 block containing the matching event.
    pub l1_block: u64,
}

/// Inbox values to write; `None` / empty fields are left untouched.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct InboxValues {
    /// `status` (slot 258, exposed by the compatibility `migrationState` getter).
    pub status: Option<u8>,
    /// `recoveryGeneration` (slot 268).
    pub recovery_generation: Option<u64>,
    /// `lastCheckpoint` `(height, blockHash)` (slots 270, 271).
    pub last_checkpoint: Option<(u64, B256)>,
    /// The genesis record (slots 272–274) with its `genesisCutoff` (slot 279) and forced
    /// inclusion configuration (slot 282).
    pub genesis: Option<GenesisRecord>,
    /// The bootstrap committee record hash at plain slot 278.
    pub genesis_committee_hash: Option<B256>,
}

impl InboxValues {
    /// The `(slot, value)` writes of the present fields.
    fn writes(&self) -> Vec<(B256, U256)> {
        let slot = inbox::slot;
        let mut w = Vec::new();
        if let Some(state) = self.status {
            w.push((slot(inbox::STATUS), U256::from(state)));
        }
        if let Some(generation) = self.recovery_generation {
            w.push((slot(inbox::RECOVERY_GENERATION), U256::from(generation)));
        }
        if let Some((height, hash)) = self.last_checkpoint {
            w.push((slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height)));
            w.push((slot(inbox::LAST_CHECKPOINT_HASH), hash.into()));
        }
        if let Some(a) = &self.genesis {
            let packed = U256::from(a.genesis_height) |
                (U256::from(a.l1_0) << 64) |
                (U256::from(a.epoch_len) << 128) |
                (U256::from(a.epoch_len_l1) << 192);
            w.push((slot(inbox::GENESIS_PACKED), packed));
            w.push((slot(inbox::GENESIS_BLOCK_HASH), a.genesis_hash.into()));
            w.push((slot(inbox::GENESIS_STATE_ROOT), a.genesis_state_root.into()));
            w.push((slot(inbox::GENESIS_CUTOFF), U256::from(a.genesis_cutoff)));
            w.push((slot(inbox::COMMITTEE_CONFIG_HASH), a.committee_config_hash.into()));
            w.push((
                slot(inbox::FORCED_INCLUSION_CONFIG),
                U256::from(a.forced_inclusion_delay) | (U256::from(a.max_anchor_age) << 64),
            ));
        }
        if let Some(hash) = self.genesis_committee_hash {
            w.push((slot(inbox::GENESIS_COMMITTEE_HASH), hash.into()));
        }
        w
    }
}

/// A registry entry for `pubkey` with `eff_stake`, active from L1 block 0, never exiting, with
/// one heartbeat naming window 0 (start 0, sequence 1; the devnet heartbeat window puts every
/// L1 block in window 0).
pub fn registry_entry(pubkey: B256, eff_stake: U256) -> RegistryEntry {
    RegistryEntry {
        pubkey,
        eff_stake,
        active_from_l1: 0,
        exit_effective_l1: u64::MAX,
        last_heartbeat_at: 0,
        last_heartbeat_seq: 1,
    }
}

/// Writes Inbox and registry storage into anvil (see the module docs).
#[derive(Clone, Debug)]
pub struct Planter {
    /// The anvil provider.
    l1: RootProvider,
    /// The Inbox address.
    inbox: Address,
    /// The staking registry address.
    registry: Address,
    /// Serializes [`NextBlock`] sections (pause / write / mine / resume).
    mining: Arc<Mutex<()>>,
}

impl Planter {
    /// A planter writing the Inbox at `inbox` and the registry at `registry` through `l1`.
    pub fn new(l1: RootProvider, inbox: Address, registry: Address) -> Self {
        Self { l1, inbox, registry, mining: Arc::new(Mutex::new(())) }
    }

    /// Places [`setter_code`] at the Inbox and registry addresses (`anvil_setCode`, out of band)
    /// and mines one block so the code is in place before any planted state.
    pub async fn install(&self) -> Result<()> {
        for address in [self.inbox, self.registry] {
            anvil_request::<serde_json::Value>(
                &self.l1,
                "anvil_setCode",
                json!([address, setter_code()]),
            )
            .await?;
        }
        mine_l1_blocks(&self.l1, 1).await
    }

    /// Pauses interval mining and returns the section whose writes land in exactly the next
    /// block; [`NextBlock::commit`] mines it and resumes interval mining. If pausing or reading
    /// the block number fails, interval mining is resumed before the error is returned.
    pub async fn next_block(&self) -> Result<NextBlock> {
        let guard = self.mining.clone().lock_owned().await;
        // The number must be read while paused, or a block could be mined in between.
        let paused = async {
            set_interval_mining(&self.l1, 0).await?;
            block_number(&self.l1).await
        }
        .await;
        match paused {
            Ok(latest) => Ok(NextBlock {
                planter: self.clone(),
                number: latest + 1,
                sent: Vec::new(),
                guard: Some(guard),
            }),
            Err(e) => {
                if let Err(resume) = set_interval_mining(&self.l1, 1).await {
                    eprintln!("resuming L1 interval mining: {resume:#}");
                }
                Err(e)
            }
        }
    }

    /// Writes the present fields of `v` into the Inbox and waits until the transaction is mined
    /// (interval mining must be running); returns the block it landed in.
    pub async fn plant_inbox(&self, v: &InboxValues) -> Result<Option<u64>> {
        match self.submit(self.inbox, &v.writes()).await? {
            Some(tx) => Ok(Some(self.mined_in(tx).await?)),
            None => Ok(None),
        }
    }

    /// The raw storage word of the Inbox at `slot` in the latest block.
    pub async fn inbox_word(&self, slot: B256) -> Result<U256> {
        self.word(self.inbox, slot).await
    }

    /// Writes an entry and emits its authenticated admission event in one mined transaction.
    pub async fn plant_forced_transaction(&self, tx: Bytes) -> Result<PlantedEntry> {
        Ok(self.plant_forced_transactions(&[tx]).await?.remove(0))
    }

    /// Admits consecutive entries with genuine logs in one mined block.
    pub async fn plant_forced_transactions(
        &self,
        transactions: &[Bytes],
    ) -> Result<Vec<PlantedEntry>> {
        let mut next = self.next_block().await?;
        let head_tail = self.inbox_word(inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL)).await?;
        let first = u64::try_from((head_tail >> 48) & U256::from(U48_MASK))?;
        ensure!(first + transactions.len() as u64 <= U48_MASK, "forced queue is full");
        for (offset, tx) in transactions.iter().enumerate() {
            let input = InboxSetter::plantForcedTransactionCall {
                _index: alloy_primitives::aliases::U48::from(first + offset as u64),
                _tx: tx.clone(),
                _feeInGwei: FORCED_INCLUSION_FEE_GWEI,
            }
            .abi_encode();
            let hash = anvil_request(
                &self.l1,
                "eth_sendTransaction",
                json!([{"from":SENDER,"to":self.inbox,"data":Bytes::from(input),"gas":"0x100000"}]),
            )
            .await?;
            next.sent.push(hash);
        }
        let l1_block = next.commit().await?;
        let block = self
            .l1
            .get_block_by_number(BlockNumberOrTag::Number(l1_block))
            .await?
            .context("mined block missing")?;
        Ok(transactions
            .iter()
            .enumerate()
            .map(|(offset, tx)| PlantedEntry {
                index: first + offset as u64,
                tx_hash: keccak256(tx),
                timestamp: block.header.timestamp,
                l1_block,
            })
            .collect())
    }

    /// The raw storage word of `address` at `slot` in the latest block.
    async fn word(&self, address: Address, slot: B256) -> Result<U256> {
        self.l1
            .get_storage_at(address, U256::from_be_bytes(slot.0))
            .block_id(BlockId::latest())
            .await
            .with_context(|| format!("reading {address} slot {slot}"))
    }

    /// The registry writes appending checkpoint `(l1_block, entries)` after the latest block's
    /// `checkpoints.length` and replacing the entries array; returns them with the checkpoint
    /// index.
    async fn registry_writes(
        &self,
        l1_block: u64,
        entries: &[RegistryEntry],
    ) -> Result<(u64, Vec<(B256, U256)>)> {
        let length = self.word(self.registry, registry::length_slot()).await?;
        let index = u64::try_from(length).context("checkpoints.length exceeds u64")?;
        let count = u32::try_from(entries.len()).context("too many entries")?;
        let [head, root] = registry::checkpoint_slots(index);
        let mut w = vec![
            (head, U256::from(l1_block) | (U256::from(count) << 64)),
            (root, entries_root(entries).into()),
            (registry::length_slot(), U256::from(index + 1)),
            (registry::entries_length_slot(), U256::from(entries.len())),
        ];
        for (j, e) in entries.iter().enumerate() {
            let [pubkey, stake, packed] = registry::entry_slots(j as u64);
            w.push((pubkey, e.pubkey.into()));
            w.push((stake, e.eff_stake));
            w.push((
                packed,
                U256::from(e.active_from_l1) |
                    (U256::from(e.exit_effective_l1) << 64) |
                    (U256::from(e.last_heartbeat_at) << 128) |
                    (U256::from(e.last_heartbeat_seq) << 192),
            ));
        }
        Ok((index, w))
    }

    /// Sends one setter transaction writing `writes` to `to`; `None` when there is nothing to
    /// write.
    ///
    /// anvil keeps every zero `SSTORE` as an explicit zero leaf in the storage trie (Ethereum
    /// never stores zeros), which the node's proof checks rightly reject. So a zero written to a
    /// slot that already reads zero is dropped (a no-op anyway), and clearing a non-zero slot is
    /// refused.
    async fn submit(&self, to: Address, writes: &[(B256, U256)]) -> Result<Option<B256>> {
        let mut kept = Vec::with_capacity(writes.len());
        for &(slot, value) in writes {
            if value.is_zero() {
                let current = self.word(to, slot).await?;
                ensure!(
                    current.is_zero(),
                    "cannot clear {to} slot {slot} ({current}): anvil would keep a zero leaf"
                );
                continue;
            }
            kept.push((slot, value));
        }
        if kept.is_empty() {
            return Ok(None);
        }
        let mut data = Vec::with_capacity(64 * kept.len());
        for (slot, value) in &kept {
            data.extend_from_slice(slot.as_slice());
            data.extend_from_slice(&value.to_be_bytes::<32>());
        }
        let gas = 100_000 + 30_000 * kept.len() as u64;
        let tx = json!([{
            "from": SENDER,
            "to": to,
            "data": Bytes::from(data),
            "gas": format!("{gas:#x}"),
        }]);
        Ok(Some(anvil_request(&self.l1, "eth_sendTransaction", tx).await?))
    }

    /// Waits for `tx`'s receipt, requires success and returns its block number.
    async fn mined_in(&self, tx: B256) -> Result<u64> {
        let receipt = wait_until(
            &format!("receipt of {tx}"),
            RECEIPT_TIMEOUT,
            Duration::from_millis(100),
            || async move { Ok(self.l1.get_transaction_receipt(tx).await?) },
        )
        .await?;
        if !receipt.status() {
            bail!("planting transaction {tx} reverted");
        }
        receipt.block_number.with_context(|| format!("receipt of {tx} has no block number"))
    }
}

/// A section with interval mining paused: writes made through it land in block
/// [`NextBlock::number`]. Dropping it without [`NextBlock::commit`] resumes interval mining in the
/// background without mining.
#[derive(Debug)]
pub struct NextBlock {
    /// The planter.
    planter: Planter,
    /// The number the next mined block will have.
    number: u64,
    /// The section's transactions.
    sent: Vec<B256>,
    /// Keeps other sections out until this one ends.
    guard: Option<OwnedMutexGuard<()>>,
}

impl NextBlock {
    /// The number of the block the section's writes land in.
    pub fn number(&self) -> u64 {
        self.number
    }

    /// Queues the Inbox writes of `v` into the block.
    pub async fn plant_inbox(&mut self, v: &InboxValues) -> Result<()> {
        let tx = self.planter.submit(self.planter.inbox, &v.writes()).await?;
        self.sent.extend(tx);
        Ok(())
    }

    /// Queues a new registry checkpoint `(number(), entries)` and the replaced entries array
    /// into the block; returns the checkpoint index. At most one per section.
    pub async fn write_registry_checkpoint(&mut self, entries: &[RegistryEntry]) -> Result<u64> {
        let (index, writes) = self.planter.registry_writes(self.number, entries).await?;
        let tx = self.planter.submit(self.planter.registry, &writes).await?;
        self.sent.extend(tx);
        Ok(index)
    }

    /// Mines the block, checks every queued transaction landed in it, and resumes interval
    /// mining (1 s); returns the block number.
    pub async fn commit(mut self) -> Result<u64> {
        let planter = self.planter.clone();
        let mined = async {
            mine_l1_blocks(&planter.l1, 1).await?;
            for tx in &self.sent {
                let block = planter.mined_in(*tx).await?;
                ensure!(block == self.number, "{tx} landed in block {block}, not {}", self.number);
            }
            let latest = block_number(&planter.l1).await?;
            ensure!(latest == self.number, "mined block {latest}, expected {}", self.number);
            Ok(latest)
        }
        .await;
        let resumed = set_interval_mining(&planter.l1, 1).await;
        self.guard.take();
        let number = mined?;
        resumed?;
        Ok(number)
    }
}

impl Drop for NextBlock {
    /// Resumes interval mining when the section was abandoned.
    fn drop(&mut self) {
        if let Some(guard) = self.guard.take() {
            let l1 = self.planter.l1.clone();
            tokio::spawn(async move {
                if let Err(e) = set_interval_mining(&l1, 1).await {
                    eprintln!("resuming L1 interval mining: {e:#}");
                }
                drop(guard);
            });
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generated_setter_matches_source_provenance() {
        let manifest: Value =
            serde_json::from_str(include_str!("../contracts/manifest.json")).unwrap();
        assert_eq!(
            manifest["source"]["keccak256"],
            keccak256(include_bytes!("../contracts/InboxSetter.sol")).to_string()
        );
        assert_eq!(manifest["settings"]["evmVersion"], "osaka");
        assert_eq!(manifest["settings"]["optimizer"]["runs"], 200);
        use sha2::{Digest, Sha256};
        assert_eq!(
            manifest["artifact"]["sha256"],
            format!("{:x}", Sha256::digest(include_bytes!("../contracts/InboxSetter.json")))
        );
        assert_eq!(manifest["compiler"]["version"], "0.8.30+commit.73712a01");
        assert!(!setter_code().is_empty());
    }

    #[test]
    fn zk_gas_fixture_matches_source_provenance() {
        use sha2::{Digest, Sha256};
        let manifest: Value =
            serde_json::from_str(include_str!("../contracts/ZkGasFixture.manifest.json")).unwrap();
        let source = include_bytes!("../contracts/ZkGasFixture.sol");
        assert_eq!(manifest["source"]["sha256"], format!("{:x}", Sha256::digest(source)));
        assert_eq!(manifest["source"]["keccak256"], keccak256(source).to_string());
        assert_eq!(
            manifest["artifact"]["sha256"],
            format!("{:x}", Sha256::digest(include_bytes!("../contracts/ZkGasFixture.json")))
        );
        assert_eq!(manifest["compiler"]["version"], "0.8.30+commit.73712a01");
        assert_eq!(manifest["settings"]["evmVersion"], "osaka");
        assert_eq!(manifest["settings"]["optimizer"]["runs"], 200);
    }

    #[test]
    fn inbox_values_write_only_present_fields() {
        // The write list keeps zeros; `submit` drops the no-op ones against L1.
        let v = InboxValues { recovery_generation: Some(0), ..Default::default() };
        assert_eq!(v.writes(), vec![(inbox::slot(inbox::RECOVERY_GENERATION), U256::ZERO)]);
        assert!(InboxValues::default().writes().is_empty());
    }

    #[test]
    fn inbox_values_write_the_genesis_with_its_cutoff_and_forced_inclusion_config() {
        let genesis = GenesisRecord {
            committee_config_hash: B256::repeat_byte(9),
            genesis_height: 1,
            l1_0: 2,
            epoch_len: 3,
            epoch_len_l1: 4,
            genesis_hash: B256::repeat_byte(5),
            genesis_state_root: B256::repeat_byte(6),
            genesis_cutoff: 7,
            forced_inclusion_delay: 10,
            max_anchor_age: 11,
        };
        let v = InboxValues {
            genesis: Some(genesis),
            genesis_committee_hash: Some(B256::repeat_byte(8)),
            ..Default::default()
        };
        let packed = U256::from(1u64) |
            U256::from(2u64) << 64 |
            U256::from(3u64) << 128 |
            U256::from(4u64) << 192;
        assert_eq!(
            v.writes(),
            vec![
                (inbox::slot(272), packed),
                (inbox::slot(273), U256::from_be_bytes([5; 32])),
                (inbox::slot(274), U256::from_be_bytes([6; 32])),
                (inbox::slot(279), U256::from(7u64)),
                (inbox::slot(269), U256::from_be_bytes([9; 32])),
                (inbox::slot(282), U256::from(10u64) | U256::from(11u64) << 64),
                (inbox::slot(inbox::GENESIS_COMMITTEE_HASH), U256::from_be_bytes([8; 32])),
            ]
        );
    }
}
