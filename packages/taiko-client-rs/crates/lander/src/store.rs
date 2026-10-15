//! Atomic, exclusively owned transaction journal; chain state remains the source of progress.

use crate::{
    codec::{self, PublishedBlock},
    error::{LanderError, Result},
    proof::ProofRequest,
    tx::{LandingReceipt, SignedTransaction},
};
use alloy_primitives::{Address, B256, Bytes, U256};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
};

/// Journal schema version; incompatible formats stop rather than discard outstanding nonces.
///
/// Schema 8 binds calldata FI envelope v5 and payload v4; older journals are rejected intact.
/// Schema 7 journals the paired commit as a protobuf too: schema 6 kept it in the domain JSON
/// form, which reads a Unix-epoch vote time as absent and cannot restore such a certificate.
/// Schema 6 additionally preserves authoritative original Comet protobuf block bytes. Schema 5
/// jobs used lossy Tendermint domain block serialization and bound the eighteen-word V6 statement
/// over a six-field `LandInput` (forced inclusion head after the batch and fee recipient included),
/// compressed V3 blob payloads and snapshots carrying the forced inclusion queue; schema 4 bound V5
/// statements over uncompressed V2 payloads and schema 3 complete V1 blocks.
const JOURNAL_VERSION: u8 = 8;
/// Hard allocation bound before reading or decoding an untrusted journal.
pub(crate) const MAX_JOURNAL_BYTES: u64 = 256 * 1024 * 1024;

/// Public identities a journal may be resumed under; no keys or endpoint credentials occur here.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct JournalIdentity {
    /// L1 chain on which the transaction is valid.
    pub l1_chain_id: U256,
    /// L2 decided chain identity.
    pub l2_chain_id: u64,
    /// Executing Inbox proxy.
    pub inbox: Address,
    /// Statement-bound staking registry.
    pub registry: Address,
    /// Exclusive signing-account identity.
    pub sender: Address,
}

/// Immutable inputs and returned proof, retained until transaction settlement.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProvedJob {
    /// Complete prepared job, including its blobs and statement identity.
    pub request: ProofRequest,
    /// Bytes supplied by the configured proof provider.
    pub proof: Bytes,
}

/// Durable phase. Pending is saved before the first broadcast attempt, including ambiguous sends.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(tag = "phase", rename_all = "snake_case")]
pub enum JournalState {
    /// No outstanding job or nonce; build from the current on-chain checkpoint.
    #[default]
    Idle,
    /// Proof is ready, but no transaction has been signed.
    Prepared {
        /// Proven job whose public inputs cannot change while signing.
        job: Box<ProvedJob>,
    },
    /// Signed bytes are durable and have never been scheduled for broadcast.
    Signed {
        /// Proven immutable job.
        job: Box<ProvedJob>,
        /// Complete signed envelope and sidecar.
        transaction: SignedTransaction,
    },
    /// Broadcast was scheduled; reconcile before any subsequent network mutation.
    Pending {
        /// Proven immutable job.
        job: Box<ProvedJob>,
        /// One outstanding nonce's original signed bytes.
        transaction: SignedTransaction,
    },
    /// A receipt exists but must remain canonical for the required confirmation depth.
    Confirming {
        /// Proven immutable job.
        job: Box<ProvedJob>,
        /// Original signed bytes retained for a possible receipt reorg.
        transaction: SignedTransaction,
        /// Canonical receipt observed so far.
        receipt: LandingReceipt,
    },
}

/// First local observation of backlog at one coherent checkpoint, durable across restarts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct BatchWait {
    /// Height of the checkpoint above which decided backlog was first observed.
    pub checkpoint_height: u64,
    /// Checkpoint block identity; a same-height competing block starts a new wait.
    pub checkpoint_hash: B256,
    /// Inbox recovery generation; recovery cannot inherit an earlier checkpoint's timer.
    pub generation: u64,
    /// Unix milliseconds of first local backlog observation, used to restore elapsed wait.
    pub first_seen_unix_ms: u64,
}

/// Minimal schema opening checked before incompatible outstanding jobs are decoded.
#[derive(Deserialize)]
struct JournalSchema {
    /// Wire/protocol discriminator; old signed transactions are never migrated.
    version: u8,
}

/// Versioned disk envelope so identities are checked even when the state is idle.
#[derive(Clone, Debug, Serialize, Deserialize)]
struct Journal {
    /// Schema discriminator.
    version: u8,
    /// Public chain, contract, and sender identities.
    identity: JournalIdentity,
    /// Resumable phase.
    state: JournalState,
    /// Optional Idle-only backlog timer; absence allows a timer-free V5 journal.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    waiting: Option<BatchWait>,
}

/// Holds the exclusive directory lock throughout every signing and broadcast operation.
pub struct Store {
    /// Separate lander data directory; never an ABCI state file.
    directory: PathBuf,
    /// The open locked file owns the OS lock until this store is dropped.
    _lock: File,
    /// Expected identities used on every load and save.
    identity: JournalIdentity,
}

impl Store {
    /// Lock an existing or empty lander directory; validate the journal before returning.
    pub fn open(path: impl AsRef<Path>, identity: JournalIdentity) -> Result<Self> {
        let directory = path.as_ref().to_path_buf();
        std::fs::create_dir_all(&directory).map_err(io_error)?;
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(directory.join("lander.lock"))
            .map_err(io_error)?;
        lock.try_lock().map_err(|e| {
            LanderError::Journal(format!("data directory already locked or cannot be locked: {e}"))
        })?;
        let store = Self { directory, _lock: lock, identity };
        store.load()?;
        Ok(store)
    }

    /// Current public identity, suitable for comparison with freshly read chain facts.
    pub fn identity(&self) -> &JournalIdentity {
        &self.identity
    }

    /// Read only the committed file. An interrupted temporary write does not supersede it.
    pub fn load(&self) -> Result<JournalState> {
        self.load_with_wait().map(|(state, _)| state)
    }

    /// Read the committed phase and optional backlog timer as one validated disk snapshot.
    pub fn load_with_wait(&self) -> Result<(JournalState, Option<BatchWait>)> {
        let path = self.directory.join("lander-state.json");
        let file = match File::open(&path) {
            Ok(file) => file,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                return Ok((JournalState::Idle, None))
            }
            Err(error) => return Err(io_error(error)),
        };
        if file.metadata().map_err(io_error)?.len() > MAX_JOURNAL_BYTES {
            return Err(LanderError::Journal("journal exceeds allocation limit".into()));
        }
        let mut bytes = Vec::new();
        file.take(MAX_JOURNAL_BYTES + 1).read_to_end(&mut bytes).map_err(io_error)?;
        if bytes.len() as u64 > MAX_JOURNAL_BYTES {
            return Err(LanderError::Journal("journal grew beyond allocation limit".into()));
        }
        let schema: JournalSchema = serde_json::from_slice(&bytes)
            .map_err(|e| LanderError::Journal(format!("corrupt journal schema: {e}")))?;
        if schema.version != JOURNAL_VERSION {
            return Err(LanderError::Journal(format!(
                "incompatible journal schema {} (expected {JOURNAL_VERSION}); signed transaction \
                 retained unchanged",
                schema.version
            )));
        }
        let journal: Journal = serde_json::from_slice(&bytes)
            .map_err(|e| LanderError::Journal(format!("corrupt journal: {e}")))?;
        if journal.version != JOURNAL_VERSION || journal.identity != self.identity {
            return Err(LanderError::Journal(
                "journal schema or chain/contract/sender identity differs from configuration"
                    .into(),
            ));
        }
        self.validate_wait(&journal.state, journal.waiting.as_ref())?;
        self.validate(&journal.state)?;
        Ok((journal.state, journal.waiting))
    }

    /// Commit a phase and clear any backlog timer before returning after all durability barriers.
    pub fn save(&self, state: &JournalState) -> Result<()> {
        self.save_with_wait(state, None)
    }

    /// Atomically commit an Idle backlog timer or a timer-free transaction phase, then fsync.
    pub fn save_with_wait(&self, state: &JournalState, waiting: Option<&BatchWait>) -> Result<()> {
        self.validate_wait(state, waiting)?;
        self.validate(state)?;
        let journal = Journal {
            version: JOURNAL_VERSION,
            identity: self.identity.clone(),
            state: state.clone(),
            waiting: waiting.cloned(),
        };
        let bytes = serde_json::to_vec(&journal)
            .map_err(|e| LanderError::Journal(format!("serialize journal: {e}")))?;
        if bytes.len() as u64 > MAX_JOURNAL_BYTES {
            return Err(LanderError::Journal("journal exceeds allocation limit".into()));
        }
        let temporary = self.directory.join("lander-state.json.tmp");
        let mut file = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&temporary)
            .map_err(io_error)?;
        file.write_all(&bytes).map_err(io_error)?;
        file.sync_all().map_err(io_error)?;
        std::fs::rename(temporary, self.directory.join("lander-state.json")).map_err(io_error)?;
        File::open(&self.directory).map_err(io_error)?.sync_all().map_err(io_error)?;
        Ok(())
    }

    /// Refuse a timer attached to any phase that already owns an immutable transaction job.
    fn validate_wait(&self, state: &JournalState, waiting: Option<&BatchWait>) -> Result<()> {
        if waiting.is_some() && !matches!(state, JournalState::Idle) {
            return Err(LanderError::Journal("batch wait marker is only valid in Idle".into()));
        }
        Ok(())
    }

    /// Refuse altered public inputs, sidecars, signatures, identities, or receipt associations.
    fn validate(&self, state: &JournalState) -> Result<()> {
        let (job, transaction, receipt) = match state {
            JournalState::Idle => return Ok(()),
            JournalState::Prepared { job } => (job, None, None),
            JournalState::Signed { job, transaction } |
            JournalState::Pending { job, transaction } => (job, Some(transaction), None),
            JournalState::Confirming { job, transaction, receipt } => {
                (job, Some(transaction), Some(receipt))
            }
        };
        let snapshot = &job.request.batch.snapshot;
        if snapshot.l1_chain_id != self.identity.l1_chain_id ||
            snapshot.l2_chain_id != self.identity.l2_chain_id ||
            snapshot.inbox != self.identity.inbox ||
            snapshot.registry != self.identity.registry
        {
            return Err(LanderError::Journal("job chain/contract identity mismatch".into()));
        }
        let batch = &job.request.batch;
        let reference = batch
            .reference_headers
            .first()
            .ok_or_else(|| LanderError::Journal("job has no L1 reference".into()))?;
        let header = abci::l1::header::RawL1Header::from_raw(reference.clone())
            .map_err(|e| LanderError::Journal(format!("job reference: {e}")))?;
        if header.number() != batch.input.l1ReferenceBlockNumber ||
            crate::statement::hash(
                snapshot,
                &batch.input,
                header.hash(),
                &batch.blobs.versioned_hashes,
            ) != batch.statement_hash
        {
            return Err(LanderError::Journal("job V6 statement identity mismatch".into()));
        }
        let limits = crate::types::Limits {
            max_blocks: 100_000,
            max_blobs: 128,
            max_payload_bytes: MAX_JOURNAL_BYTES as usize,
            max_message_bytes: MAX_JOURNAL_BYTES as usize,
            max_decompressed_bytes: MAX_JOURNAL_BYTES as usize,
        };
        let payload = crate::blob::decode(batch.blobs.sidecar.blobs(), &limits)
            .map_err(|e| LanderError::Journal(format!("job blobs: {e}")))?;
        for pair in &batch.blocks {
            codec::validate_pair(pair)
                .map_err(|e| LanderError::Journal(format!("job block pair: {e}")))?;
        }
        // Compressed bytes are not canonical, so compare the blocks the payload carries.
        let published = codec::decode(&payload, &limits)
            .map_err(|e| LanderError::Journal(format!("job block codec: {e}")))?;
        if payload.len() != batch.blobs.payload_bytes ||
            !published.into_iter().eq(batch.blocks.iter().map(PublishedBlock::from))
        {
            return Err(LanderError::Journal("job blocks differ from bound blob payload".into()));
        }
        batch
            .blobs
            .sidecar
            .validate(
                &batch.blobs.versioned_hashes,
                alloy_eips::eip4844::env_settings::EnvKzgSettings::Default.get(),
            )
            .map_err(|e| LanderError::Journal(format!("job KZG commitments: {e}")))?;
        if let Some(transaction) = transaction {
            if transaction.sender != self.identity.sender {
                return Err(LanderError::Journal("job sender identity mismatch".into()));
            }
            transaction.validate(&job.request, &job.proof)?;
            if receipt.is_some_and(|r| r.transaction_hash != transaction.hash) {
                return Err(LanderError::Journal(
                    "receipt does not identify the outstanding transaction".into(),
                ));
            }
        }
        Ok(())
    }
}

/// Include the failing durability operation's OS error without serializing secret data.
fn io_error(error: std::io::Error) -> LanderError {
    LanderError::Journal(error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn identity() -> JournalIdentity {
        JournalIdentity {
            l1_chain_id: U256::from(1),
            l2_chain_id: 2,
            inbox: Address::repeat_byte(3),
            registry: Address::repeat_byte(4),
            sender: Address::repeat_byte(5),
        }
    }
    #[tokio::test]
    async fn prepared_signed_pending_and_confirming_roundtrip_with_bound_job() {
        use crate::test_utils::runtime::{request, signed};
        let request = request();
        let proof = Bytes::from_static(&[0]);
        let transaction = signed(&request, &proof, 0).await;
        let snapshot = &request.batch.snapshot;
        let identity = JournalIdentity {
            l1_chain_id: snapshot.l1_chain_id,
            l2_chain_id: snapshot.l2_chain_id,
            inbox: snapshot.inbox,
            registry: snapshot.registry,
            sender: transaction.sender,
        };
        let directory = tempfile::tempdir().unwrap();
        let store = Store::open(directory.path(), identity.clone()).unwrap();
        let job = Box::new(ProvedJob { request, proof });
        let phases = [
            JournalState::Prepared { job: job.clone() },
            JournalState::Signed { job: job.clone(), transaction: transaction.clone() },
            JournalState::Pending { job: job.clone(), transaction: transaction.clone() },
            JournalState::Confirming {
                job: job.clone(),
                transaction: transaction.clone(),
                receipt: LandingReceipt {
                    transaction_hash: transaction.hash,
                    block_number: 30,
                    block_hash: alloy_primitives::B256::repeat_byte(30),
                    success: true,
                },
            },
        ];
        for phase in phases {
            store.save(&phase).unwrap();
            assert_eq!(store.load().unwrap(), phase);
        }
        let mut altered = job;
        altered.request.batch.statement_hash = alloy_primitives::B256::ZERO;
        assert!(store.save(&JournalState::Prepared { job: altered }).is_err());
        drop(store);
        assert!(matches!(
            Store::open(directory.path(), identity).unwrap().load().unwrap(),
            JournalState::Confirming { .. }
        ));
    }
    #[test]
    fn idle_wait_roundtrip_and_phase_save_clears_the_marker() {
        let directory = tempfile::tempdir().unwrap();
        let store = Store::open(directory.path(), identity()).unwrap();
        let waiting = BatchWait {
            checkpoint_height: 12,
            checkpoint_hash: B256::repeat_byte(12),
            generation: 4,
            first_seen_unix_ms: 1234,
        };
        store.save_with_wait(&JournalState::Idle, Some(&waiting)).unwrap();
        drop(store);
        let store = Store::open(directory.path(), identity()).unwrap();
        assert_eq!(store.load_with_wait().unwrap(), (JournalState::Idle, Some(waiting)));
        store.save(&JournalState::Idle).unwrap();
        assert_eq!(store.load_with_wait().unwrap(), (JournalState::Idle, None));
    }

    /// Schema 2 holds V4 statements, schema 3 complete-block V1 blob payloads and schema 4
    /// uncompressed V2 payloads; schema 5 used lossy domain block serialization and schema 6
    /// domain JSON commits.
    #[test]
    fn legacy_journals_are_rejected_without_modifying_their_files() {
        for version in [2, 3, 4, 5, 6, 7] {
            let directory = tempfile::tempdir().unwrap();
            let journal = serde_json::json!({
                "version": version,
                "identity": identity(),
                "state": { "phase": "idle" },
            });
            std::fs::write(directory.path().join("lander-state.json"), journal.to_string())
                .unwrap();
            let error = match Store::open(directory.path(), identity()) {
                Err(e) => e,
                Ok(_) => panic!("schema {version} must be rejected"),
            };
            assert!(error.to_string().contains("incompatible journal schema"), "{error}");
            assert_eq!(
                std::fs::read_to_string(directory.path().join("lander-state.json")).unwrap(),
                journal.to_string()
            );
        }
    }

    #[tokio::test]
    async fn legacy_pending_journal_retains_exact_signed_bytes_and_nonce_on_rejection() {
        let request = crate::test_utils::runtime::request();
        let proof = Bytes::from_static(&[0]);
        let transaction = crate::test_utils::runtime::signed(&request, &proof, 7).await;
        let id = JournalIdentity {
            l1_chain_id: request.batch.snapshot.l1_chain_id,
            l2_chain_id: request.batch.snapshot.l2_chain_id,
            inbox: request.batch.snapshot.inbox,
            registry: request.batch.snapshot.registry,
            sender: transaction.sender,
        };
        let state =
            JournalState::Pending { job: Box::new(ProvedJob { request, proof }), transaction };
        for version in [2, 3, 4, 5, 6, 7] {
            let directory = tempfile::tempdir().unwrap();
            let bytes = serde_json::to_vec(
                &serde_json::json!({ "version": version, "identity": id, "state": state }),
            )
            .unwrap();
            let path = directory.path().join("lander-state.json");
            std::fs::write(&path, &bytes).unwrap();
            let error = match Store::open(directory.path(), id.clone()) {
                Err(e) => e,
                Ok(_) => panic!("schema {version} must be rejected"),
            };
            assert!(error.to_string().contains("incompatible journal schema"), "{error}");
            assert_eq!(std::fs::read(path).unwrap(), bytes);
        }
    }

    /// The blobs must carry exactly the job's published blocks; their compressed bytes need not
    /// be this lander's own encoding.
    #[test]
    fn journal_job_validates_by_decoded_blocks() {
        use crate::test_utils::runtime::{limits, rebind, request};
        use flate2::{Compression, write::ZlibEncoder};
        let mut request = request();
        let payload = crate::codec::encode(&request.batch.blocks, &limits()).unwrap();
        let list = abci::compression::zlib_inflate_exact(&payload[1..], usize::MAX).unwrap();
        let mut encoder = ZlibEncoder::new(vec![payload[0]], Compression::none());
        encoder.write_all(&list).unwrap();
        let stored = encoder.finish().unwrap();
        assert_ne!(stored, payload);
        rebind(&mut request, &stored);
        let snapshot = &request.batch.snapshot;
        let identity = JournalIdentity {
            l1_chain_id: snapshot.l1_chain_id,
            l2_chain_id: snapshot.l2_chain_id,
            inbox: snapshot.inbox,
            registry: snapshot.registry,
            sender: Address::repeat_byte(5),
        };
        let directory = tempfile::tempdir().unwrap();
        let store = Store::open(directory.path(), identity).unwrap();
        let proof = Bytes::from_static(&[0]);
        let job = JournalState::Prepared {
            job: Box::new(ProvedJob { request: request.clone(), proof: proof.clone() }),
        };
        store.save(&job).unwrap();
        assert_eq!(store.load().unwrap(), job);

        // A canonical payload of only the first block binds different blocks.
        let first = crate::codec::encode(&request.batch.blocks[..1], &limits()).unwrap();
        rebind(&mut request, &first);
        let error = store
            .save(&JournalState::Prepared { job: Box::new(ProvedJob { request, proof }) })
            .unwrap_err();
        assert!(error.to_string().contains("job blocks differ"), "{error}");
        assert_eq!(store.load().unwrap(), job);
    }

    /// Journaled blocks grow the journal by at most 4/3 of their published list bytes (their
    /// transactions are base64), the factor `batch::MAX_BATCH_LIST_BYTES` is sized by.
    #[test]
    fn journaled_blocks_cost_at_most_four_thirds_of_their_list_bytes() {
        use crate::test_utils::{
            consensus,
            runtime::{rebind, request},
        };
        let cap = crate::types::Limits {
            max_blocks: 2,
            max_blobs: 2,
            max_payload_bytes: 1_000_000,
            max_message_bytes: 4 << 20,
            max_decompressed_bytes: 8 << 20,
        };
        let list_len = |request: &ProofRequest| {
            let mut list = codec::PayloadList::new(&cap).unwrap();
            for pair in &request.batch.blocks {
                list.push(pair).unwrap();
            }
            list.list_len()
        };
        let journal_len = |request: &ProofRequest| {
            let snapshot = &request.batch.snapshot;
            let identity = JournalIdentity {
                l1_chain_id: snapshot.l1_chain_id,
                l2_chain_id: snapshot.l2_chain_id,
                inbox: snapshot.inbox,
                registry: snapshot.registry,
                sender: Address::repeat_byte(5),
            };
            let directory = tempfile::tempdir().unwrap();
            let store = Store::open(directory.path(), identity).unwrap();
            let job = ProvedJob { request: request.clone(), proof: Bytes::from_static(&[0]) };
            store.save(&JournalState::Prepared { job: Box::new(job) }).unwrap();
            std::fs::metadata(directory.path().join("lander-state.json")).unwrap().len() as usize
        };
        let small = request();
        let (_, committee, keys) = consensus::committee(&[3, 3, 3], 0);
        let mut blocks: Vec<crate::CertifiedBlock> = Vec::new();
        for height in 1..=2 {
            let envelope = abci::EtnaEnvelope {
                block: abci::ExecutionBlock {
                    header: alloy_consensus::Header { number: height, ..Default::default() },
                    transactions: vec![vec![0; 1 << 20].into()],
                },
                anchor: None,
                committee: None,
                forced: None,
            };
            blocks.push(consensus::pair_with_envelope(envelope, &committee, &keys, blocks.last()));
        }
        let mut large = small.clone();
        large.batch.blocks = blocks;
        let payload = codec::encode(&large.batch.blocks, &cap).unwrap();
        rebind(&mut large, &payload);
        let list_growth = list_len(&large) - list_len(&small);
        let journal_growth = journal_len(&large) - journal_len(&small);
        assert!(list_growth > 2 << 20);
        assert!(
            journal_growth <= list_growth / 3 * 4 + 4_096,
            "{journal_growth} for {list_growth}"
        );
    }

    #[test]
    fn wait_marker_on_prepared_journal_is_rejected() {
        let request = crate::test_utils::runtime::request();
        let snapshot = &request.batch.snapshot;
        let identity = JournalIdentity {
            l1_chain_id: snapshot.l1_chain_id,
            l2_chain_id: snapshot.l2_chain_id,
            inbox: snapshot.inbox,
            registry: snapshot.registry,
            sender: Address::repeat_byte(5),
        };
        let directory = tempfile::tempdir().unwrap();
        let journal = serde_json::json!({
            "version": JOURNAL_VERSION,
            "identity": identity,
            "state": JournalState::Prepared {
                job: Box::new(ProvedJob { request, proof: Bytes::from_static(&[0]) }),
            },
            "waiting": {
                "checkpoint_height": 0,
                "checkpoint_hash": alloy_primitives::B256::repeat_byte(1),
                "generation": 0,
                "first_seen_unix_ms": 1234,
            },
        });
        std::fs::write(directory.path().join("lander-state.json"), journal.to_string()).unwrap();
        assert!(Store::open(directory.path(), identity).is_err());
    }
    #[test]
    fn lock_is_exclusive_and_released_on_drop() {
        let directory = tempfile::tempdir().unwrap();
        let first = Store::open(directory.path(), identity()).unwrap();
        assert!(Store::open(directory.path(), identity()).is_err());
        drop(first);
        assert!(Store::open(directory.path(), identity()).is_ok());
    }
    #[test]
    fn interrupted_temporary_write_preserves_committed_journal() {
        let directory = tempfile::tempdir().unwrap();
        let store = Store::open(directory.path(), identity()).unwrap();
        store.save(&JournalState::Idle).unwrap();
        std::fs::write(directory.path().join("lander-state.json.tmp"), b"{interrupted").unwrap();
        assert_eq!(store.load().unwrap(), JournalState::Idle);
        drop(store);
        assert_eq!(
            Store::open(directory.path(), identity()).unwrap().load().unwrap(),
            JournalState::Idle
        );
    }
    #[test]
    fn corrupt_committed_state_and_identity_mismatches_are_fatal() {
        let directory = tempfile::tempdir().unwrap();
        let store = Store::open(directory.path(), identity()).unwrap();
        store.save(&JournalState::Idle).unwrap();
        drop(store);
        let mut other = identity();
        other.sender = Address::repeat_byte(6);
        assert!(Store::open(directory.path(), other).is_err());
        std::fs::write(directory.path().join("lander-state.json"), b"{corrupt").unwrap();
        assert!(Store::open(directory.path(), identity()).is_err());
    }
}
