//! Atomic, exclusively owned transaction journal; chain state remains the source of progress.

use crate::{
    codec::{self, PublishedBlock},
    error::{LanderError, Result},
    proof::ProofRequest,
    tx::{LandingReceipt, SignedTransaction},
};
use alloy_primitives::{Address, Bytes, U256};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
};

/// Journal schema version; any other version is refused with its file unchanged (START-10-24).
const JOURNAL_VERSION: u8 = 16;
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

/// Versioned disk envelope so identities are checked even when the state is idle.
#[derive(Clone, Debug, Serialize, Deserialize)]
struct Journal {
    /// Schema discriminator.
    version: u8,
    /// Public chain, contract, and sender identities.
    identity: JournalIdentity,
    /// Resumable phase.
    state: JournalState,
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
        std::fs::create_dir_all(path.as_ref()).map_err(io_error)?;
        let directory = std::fs::canonicalize(path.as_ref()).map_err(io_error)?;
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
        File::open(&directory).map_err(io_error)?.sync_all().map_err(io_error)?;
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
        let path = self.directory.join("lander-state.json");
        let file = match File::open(&path) {
            Ok(file) => file,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                return Ok(JournalState::Idle)
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
        let journal: Journal = serde_json::from_slice(&bytes).map_err(|e| {
            LanderError::Journal(format!("unreadable journal (retained unchanged): {e}"))
        })?;
        if journal.version != JOURNAL_VERSION {
            return Err(LanderError::Journal(format!(
                "incompatible journal schema {} (expected {JOURNAL_VERSION}); signed transaction \
                 retained unchanged",
                journal.version
            )));
        }
        if journal.identity != self.identity {
            return Err(LanderError::Journal(
                "journal chain/contract/sender identity differs from configuration".into(),
            ));
        }
        self.validate(&journal.state)?;
        Ok(journal.state)
    }

    /// Atomically commit a phase, returning only after all durability barriers.
    pub fn save(&self, state: &JournalState) -> Result<()> {
        self.validate(state)?;
        let journal = Journal {
            version: JOURNAL_VERSION,
            identity: self.identity.clone(),
            state: state.clone(),
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
        batch.validate_statement()?;
        let limits = crate::types::Limits {
            max_blocks: 100_000,
            max_blobs: 128,
            max_payload_bytes: MAX_JOURNAL_BYTES as usize,
            max_message_bytes: MAX_JOURNAL_BYTES as usize,
            max_decompressed_bytes: MAX_JOURNAL_BYTES as usize,
        };
        let payload = crate::blob::decode(batch.blobs.sidecar.blobs(), &limits)
            .map_err(|e| LanderError::Journal(format!("job blobs: {e}")))?;
        // Compressed bytes are not canonical, so compare the blocks the payload carries.
        let range = codec::LandedRange {
            parent_height: snapshot.checkpoint_height,
            parent_hash: snapshot.checkpoint_hash,
            last_height: crate::types::protocol_u48(batch.input.lastHeight)?,
            last_block_hash: batch.input.lastBlockHash,
            last_state_root: batch.input.lastStateRoot,
        };
        let published = codec::decode_landed(&payload, &range)
            .map_err(|e| LanderError::Journal(format!("job block codec: {e}")))?;
        let expected = batch
            .blocks
            .iter()
            .map(|pair| {
                PublishedBlock::try_from(pair)
                    .map_err(|e| LanderError::Journal(format!("job block pair: {e}")))
            })
            .collect::<Result<Vec<_>>>()?;
        if payload.len() != batch.blobs.payload_bytes || published != expected {
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
            transaction.validate_binding(&job.request, &job.proof)?;
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
    use alloy_primitives::B256;
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

    /// The store's own exclusive lock is its only marker; nothing else appears before a save.
    #[test]
    fn open_creates_only_the_lander_lock() {
        let directory = tempfile::tempdir().unwrap();
        let _store = Store::open(directory.path(), identity()).unwrap();
        let mut names = std::fs::read_dir(directory.path())
            .unwrap()
            .map(|entry| entry.unwrap().file_name().into_string().unwrap())
            .collect::<Vec<_>>();
        names.sort();
        assert_eq!(names, ["lander.lock"]);
    }

    /// A journal of any other schema, here a real Pending job signed at nonce 7, is refused and
    /// kept byte for byte, nonce included: no migration and no temporary rewrite.
    #[tokio::test]
    async fn other_journal_version_is_refused_intact() {
        use crate::test_utils::runtime::{request, signed};
        let request = request();
        let proof = Bytes::from_static(&[0]);
        let transaction = signed(&request, &proof, 7).await;
        let id = JournalIdentity {
            l1_chain_id: request.batch.snapshot.l1_chain_id,
            l2_chain_id: request.batch.snapshot.l2_chain_id,
            inbox: request.batch.snapshot.inbox,
            registry: request.batch.snapshot.registry,
            sender: transaction.sender,
        };
        let state =
            JournalState::Pending { job: Box::new(ProvedJob { request, proof }), transaction };
        let version = JOURNAL_VERSION + 1;
        let bytes = serde_json::to_vec(
            &serde_json::json!({ "version": version, "identity": id, "state": state }),
        )
        .unwrap();
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("lander-state.json");
        std::fs::write(&path, &bytes).unwrap();

        let error = Store::open(directory.path(), id).err().expect("other schema refused");
        assert!(
            error
                .to_string()
                .contains(&format!("incompatible journal schema {version} (expected 16)")),
            "{error}"
        );
        assert_eq!(std::fs::read(&path).unwrap(), bytes);
        let kept: serde_json::Value =
            serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
        assert_eq!(kept["state"]["phase"], "pending");
        assert_eq!(kept["state"]["transaction"]["nonce"], 7);
        assert!(!directory.path().join("lander-state.json.tmp").exists());
    }

    #[test]
    fn restored_job_authenticates_private_witness_even_when_public_da_is_unchanged() {
        let mut request = crate::test_utils::runtime::request();
        let witness = request.batch.starting_inbox_witness.clone();
        let pair = &mut request.batch.blocks[0];
        let mut envelope = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap();
        let original_execution = envelope.block.clone();
        envelope.anchor.get_or_insert(witness).inbox.balance += U256::from(1);
        assert_eq!(envelope.block, original_execution);
        pair.block.data[0] = envelope.encode().to_vec();
        *pair = crate::types::CertifiedBlock::from_raw(
            crate::test_utils::consensus::raw_block(&pair.block),
            pair.commit.clone(),
        )
        .unwrap();
        let id = JournalIdentity {
            l1_chain_id: request.batch.snapshot.l1_chain_id,
            l2_chain_id: request.batch.snapshot.l2_chain_id,
            inbox: request.batch.snapshot.inbox,
            registry: request.batch.snapshot.registry,
            sender: Address::repeat_byte(5),
        };
        let state = JournalState::Prepared {
            job: Box::new(ProvedJob { request, proof: Bytes::from_static(&[0]) }),
        };
        let bytes = serde_json::to_vec(&serde_json::json!({
            "version": JOURNAL_VERSION, "identity": id, "state": state,
        }))
        .unwrap();
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("lander-state.json");
        std::fs::write(&path, &bytes).unwrap();
        let error = Store::open(directory.path(), id).err().expect("private envelope rejected");
        assert!(error.to_string().contains("data hash"), "{error}");
        assert_eq!(std::fs::read(path).unwrap(), bytes);
    }

    #[test]
    fn restored_job_rejects_cutoff_tampering_even_with_recomputed_digest() {
        let mut request = crate::test_utils::runtime::request();
        request.batch.input.activeCommitteeSnapshot += U256::from(1);
        let reference =
            abci::RawL1Header::from_raw(request.batch.reference_headers[0].clone()).unwrap();
        request.batch.statement_hash = crate::statement::hash(
            &request.batch.snapshot,
            &request.batch.input,
            reference.hash(),
            &request.batch.blobs.versioned_hashes,
            &request.batch.leaves,
        );
        let id = JournalIdentity {
            l1_chain_id: request.batch.snapshot.l1_chain_id,
            l2_chain_id: request.batch.snapshot.l2_chain_id,
            inbox: request.batch.snapshot.inbox,
            registry: request.batch.snapshot.registry,
            sender: Address::repeat_byte(5),
        };
        let state = JournalState::Prepared {
            job: Box::new(ProvedJob { request, proof: Bytes::from_static(&[0]) }),
        };
        let bytes = serde_json::to_vec(
            &serde_json::json!({ "version": JOURNAL_VERSION, "identity": id, "state": state }),
        )
        .unwrap();
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("lander-state.json");
        std::fs::write(&path, &bytes).unwrap();
        let error = Store::open(directory.path(), id).err().expect("altered cutoff rejected");
        assert!(error.to_string().contains("active committee snapshot"), "{error}");
        assert_eq!(std::fs::read(path).unwrap(), bytes);
    }

    /// A restored job's starting validator state is recomputed (the genesis state at this
    /// job's origin checkpoint), so one changed priority refuses the journal, digest rebound or
    /// not, and leaves its file unchanged.
    #[test]
    fn restored_job_rejects_a_tampered_starting_state() {
        let original = crate::test_utils::runtime::request();
        for rebind in [false, true] {
            let mut request = original.clone();
            request.batch.start_val_state.current.entries[0].priority += 1;
            if rebind {
                let reference =
                    abci::RawL1Header::from_raw(request.batch.reference_headers[0].clone())
                        .unwrap();
                request.batch.statement_hash = crate::statement::hash(
                    &request.batch.snapshot,
                    &request.batch.input,
                    reference.hash(),
                    &request.batch.blobs.versioned_hashes,
                    &request.batch.leaves,
                );
            }
            let id = JournalIdentity {
                l1_chain_id: request.batch.snapshot.l1_chain_id,
                l2_chain_id: request.batch.snapshot.l2_chain_id,
                inbox: request.batch.snapshot.inbox,
                registry: request.batch.snapshot.registry,
                sender: Address::repeat_byte(5),
            };
            let state = JournalState::Prepared {
                job: Box::new(ProvedJob { request, proof: Bytes::from_static(&[0]) }),
            };
            let bytes = serde_json::to_vec(
                &serde_json::json!({ "version": JOURNAL_VERSION, "identity": id, "state": state }),
            )
            .unwrap();
            let directory = tempfile::tempdir().unwrap();
            let path = directory.path().join("lander-state.json");
            std::fs::write(&path, &bytes).unwrap();
            let error = Store::open(directory.path(), id).err().expect("tampered state rejected");
            assert!(matches!(error, LanderError::Journal(_)), "{error}");
            assert!(error.to_string().contains("starting validator state"), "{error}");
            assert_eq!(std::fs::read(path).unwrap(), bytes);
        }
    }

    #[tokio::test]
    async fn journal_and_standalone_transaction_reject_bound_invalid_kzg_proofs() {
        use crate::{
            test_utils::runtime::{limits, request, signed},
            types::SidecarMode,
        };
        use alloy_eips::eip7594::BlobTransactionSidecarVariant;
        for mode in [SidecarMode::Eip4844, SidecarMode::Eip7594] {
            let mut request = request();
            let payload = crate::codec::encode(&request.batch.blocks, &limits()).unwrap();
            request.batch.blobs = crate::blob::build(&payload, &limits(), mode).unwrap();
            let proof = Bytes::from_static(&[0]);
            let valid = signed(&request, &proof, 0).await;
            let snapshot = &request.batch.snapshot;
            let identity = JournalIdentity {
                l1_chain_id: snapshot.l1_chain_id,
                l2_chain_id: snapshot.l2_chain_id,
                inbox: snapshot.inbox,
                registry: snapshot.registry,
                sender: valid.sender,
            };
            let directory = tempfile::tempdir().unwrap();
            let store = Store::open(directory.path(), identity).unwrap();
            let state = JournalState::Signed {
                job: Box::new(ProvedJob { request: request.clone(), proof: proof.clone() }),
                transaction: valid,
            };
            store.save(&state).unwrap();
            let path = directory.path().join("lander-state.json");
            let original = std::fs::read(&path).unwrap();
            match &mut request.batch.blobs.sidecar {
                BlobTransactionSidecarVariant::Eip4844(sidecar) => sidecar.proofs[0][0] ^= 1,
                BlobTransactionSidecarVariant::Eip7594(sidecar) => sidecar.cell_proofs[0][0] ^= 1,
            }
            let transaction = signed(&request, &proof, 0).await;
            assert!(
                transaction
                    .validate(&request, &proof)
                    .unwrap_err()
                    .to_string()
                    .contains("signed sidecar")
            );
            let state =
                JournalState::Pending { job: Box::new(ProvedJob { request, proof }), transaction };
            assert!(store.save(&state).unwrap_err().to_string().contains("KZG"));
            assert_eq!(std::fs::read(&path).unwrap(), original);
            // A damaged on-disk sidecar must also be rejected on restoration.
            let journal =
                Journal { version: JOURNAL_VERSION, identity: store.identity.clone(), state };
            std::fs::write(path, serde_json::to_vec(&journal).unwrap()).unwrap();
            assert!(store.load().unwrap_err().to_string().contains("KZG"));
        }
    }

    #[test]
    fn journal_rejects_private_protobuf_disagreement_without_replacing_prior_state() {
        use crate::test_utils::runtime::request;
        let request = request();
        let snapshot = &request.batch.snapshot;
        let directory = tempfile::tempdir().unwrap();
        let store = Store::open(
            directory.path(),
            JournalIdentity {
                l1_chain_id: snapshot.l1_chain_id,
                l2_chain_id: snapshot.l2_chain_id,
                inbox: snapshot.inbox,
                registry: snapshot.registry,
                sender: Address::repeat_byte(5),
            },
        )
        .unwrap();
        let mut state = JournalState::Prepared {
            job: Box::new(ProvedJob { request, proof: Bytes::from_static(&[0]) }),
        };
        store.save(&state).unwrap();
        let path = directory.path().join("lander-state.json");
        let original = std::fs::read(&path).unwrap();
        let JournalState::Prepared { job } = &mut state else { unreachable!() };
        let pair = &mut job.request.batch.blocks[0];
        let mut raw = pair.block_proto().unwrap();
        raw.header.as_mut().unwrap().proposer_address[0] ^= 1;
        pair.raw_block = prost::Message::encode_to_vec(&raw).into();
        let error = store.save(&state).unwrap_err();
        assert!(error.to_string().contains("original block differs"), "{error}");
        assert_eq!(std::fs::read(path).unwrap(), original);
    }

    /// The blobs must carry exactly the job's published blocks; their compressed bytes need not
    /// be this lander's own encoding.
    #[test]
    fn journal_job_validates_by_decoded_blocks() {
        use crate::test_utils::runtime::{limits, rebind, request};
        use flate2::{Compression, write::ZlibEncoder};
        let mut request = request();
        let payload = crate::codec::encode(&request.batch.blocks, &limits()).unwrap();
        let list = crate::compression::zlib_inflate_exact(&payload[1..], usize::MAX).unwrap();
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
        assert!(error.to_string().contains("exact landed checkpoint interval"), "{error}");
        assert_eq!(store.load().unwrap(), job);
    }

    /// Even a recomputed statement cannot authorize a journal amount absent from its headers.
    #[test]
    fn journal_recomputes_terminal_comet_hash_after_statement_rebinding() {
        use crate::test_utils::runtime::{limits, rebind, request};
        let mut request = request();
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
        let valid = JournalState::Prepared {
            job: Box::new(ProvedJob { request: request.clone(), proof: proof.clone() }),
        };
        store.save(&valid).unwrap();
        let original = std::fs::read(directory.path().join("lander-state.json")).unwrap();
        let payload = crate::codec::encode(&request.batch.blocks, &limits()).unwrap();
        request.batch.input.lastCometHash[0] ^= 1;
        rebind(&mut request, &payload);
        let error = store
            .save(&JournalState::Prepared { job: Box::new(ProvedJob { request, proof }) })
            .unwrap_err();
        assert!(error.to_string().contains("Comet"), "{error}");
        assert_eq!(std::fs::read(directory.path().join("lander-state.json")).unwrap(), original);
    }

    #[test]
    fn v1_journal_rejects_rebound_cut_leaves_and_cursor() {
        use crate::test_utils::runtime::{limits, rebind, request};
        for mutation in 0..4 {
            let mut request = request();
            let payload = crate::codec::encode(&request.batch.blocks, &limits()).unwrap();
            match mutation {
                0 => request.batch.leaves[0][0] ^= 1,
                1 => request.batch.leaves.clear(),
                2 => request.batch.leaves.push(B256::ZERO),
                3 => request.batch.input.forcedInclusionHead += U256::from(1),
                _ => unreachable!(),
            }
            rebind(&mut request, &payload);
            assert!(request.batch.validate_statement().is_err(), "rebound mutation {mutation}");
        }
    }

    /// Journaled blocks grow by at most 4/3 of their private protobuf bytes (base64),
    /// independently of how small their public execution DA is. The factor
    /// `batch::MAX_BATCH_LIST_BYTES` is sized by.
    #[test]
    fn journaled_blocks_cost_at_most_four_thirds_of_private_protobuf_bytes() {
        use crate::test_utils::{
            consensus,
            runtime::{rebind, request},
        };
        let cap = crate::types::Limits {
            max_blocks: 12,
            max_blobs: 2,
            max_payload_bytes: 1_000_000,
            max_message_bytes: 4 << 20,
            max_decompressed_bytes: 32 << 20,
        };
        let list_len = |request: &ProofRequest| {
            use prost::Message;
            request
                .batch
                .blocks
                .iter()
                .map(|pair| {
                    pair.raw_block.len() +
                        tendermint_proto::v0_38::types::Commit::from(pair.commit.clone())
                            .encoded_len()
                })
                .sum::<usize>()
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
        let mut parent_hash = small.batch.snapshot.checkpoint_hash;
        for height in 1..=12 {
            let mut envelope =
                abci::EtnaEnvelope::decode(&small.batch.blocks[height as usize - 1].block.data[0])
                    .unwrap();
            envelope.block.header.parent_hash = parent_hash;
            let mut witness = small.batch.starting_inbox_witness.clone();
            witness.inbox.account_proof = vec![vec![0; 1 << 20].into()];
            envelope.anchor = Some(witness);
            parent_hash = envelope.block.header.hash_slow();
            blocks.push(consensus::pair_with_envelope(envelope, &committee, &keys, blocks.last()));
        }
        let mut large = small.clone();
        large.batch.blocks = blocks;
        large.batch.input.lastBlockHash = parent_hash;
        large.batch.input.lastStateRoot =
            abci::EtnaEnvelope::decode(&large.batch.blocks.last().unwrap().block.data[0])
                .unwrap()
                .block
                .header
                .state_root;
        large.batch.input.lastCometHash =
            B256::from_slice(large.batch.blocks.last().unwrap().block.header.hash().as_bytes());
        large.batch.leaves = vec![crate::statement::cut_leaf(
            6,
            abci::EtnaEnvelope::decode(&large.batch.blocks[5].block.data[0])
                .unwrap()
                .block
                .header
                .hash_slow(),
            B256::from_slice(large.batch.blocks[5].block.header.hash().as_bytes()),
            0,
            crate::test_utils::runtime::val_states(&large.batch.start_val_state, 6)[6].hash(),
        )];
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
        // An unreadable journal is refused and kept byte for byte, as an other-schema one is.
        let path = directory.path().join("lander-state.json");
        std::fs::write(&path, b"{corrupt").unwrap();
        let error = Store::open(directory.path(), identity()).err().expect("unreadable refused");
        assert!(error.to_string().contains("unreadable journal (retained unchanged): "), "{error}");
        assert_eq!(std::fs::read(&path).unwrap(), b"{corrupt");
    }
}
