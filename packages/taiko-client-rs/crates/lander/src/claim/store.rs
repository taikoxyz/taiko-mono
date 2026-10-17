//! Independent claim journal: atomic durable writes, immutable signatures and exclusive ownership.
use super::{ClaimIdentity, ClaimProof, tx::SignedClaim};
use crate::{LanderError, Result, tx::LandingReceipt};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
};

/// Separate schema; never interpreted as an L1 landing journal.
const VERSION: u8 = 1;
/// Bound attacker-controlled journal allocation, including proof calldata.
const MAX_BYTES: u64 = 8 * 1024 * 1024;

/// Durable phase. Every phase after Signed retains the original signed bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum ClaimState {
    /// Authenticated entitlement available, no signed nonce yet.
    Prepared,
    /// Immutable signed bytes are durable, broadcast has not been scheduled.
    Signed,
    /// Broadcast intent is durable, including unknown outcomes and reorgs.
    Pending,
    /// Canonical successful receipt and claimed bit observed. This is the end state: Etna L2
    /// blocks are BFT-final, and a rerun after a recovery reconciles it again. Journals written
    /// before finality proofs were removed may still say `Finalized`.
    #[serde(alias = "Finalized")]
    Included,
}

/// One immutable entitlement and at most one signed nonce.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ClaimJob {
    /// Current durable phase.
    pub state: ClaimState,
    /// Immutable receipt and signed calldata proof.
    pub proof: ClaimProof,
    /// Original signed transaction, retained in every state after Signed.
    pub transaction: Option<SignedClaim>,
    /// Most recently verified canonical inclusion; absent during a reorg.
    pub inclusion: Option<LandingReceipt>,
}

/// Versioned disk record with public identities only.
#[derive(Serialize, Deserialize)]
struct Journal {
    /// Independent claim schema discriminator.
    version: u8,
    /// Exact request/payer/chain identity.
    identity: ClaimIdentity,
    /// Single outstanding claim.
    job: ClaimJob,
}

/// Separate claim lock held across signing and network mutations.
pub struct ClaimStore {
    /// Canonical physical directory, shared with neither landing nor another claim.
    directory: PathBuf,
    /// Cross-kind directory guard prevents concurrent marker-creation races.
    _directory_lock: File,
    /// Claim-specific lock retained for the store lifetime.
    _lock: File,
    /// Immutable public request identity.
    identity: ClaimIdentity,
}
impl ClaimStore {
    /// Open an independent directory and validate existing bytes before any network mutation.
    pub fn open(path: impl AsRef<Path>, identity: ClaimIdentity) -> Result<Self> {
        identity.validate()?;
        let (directory, guard) = crate::store::lock_transaction_directory(path.as_ref(), true)?;
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(directory.join("claim.lock"))
            .map_err(io_error)?;
        lock.try_lock()
            .map_err(|_| LanderError::Journal("claim directory already locked".into()))?;
        File::open(&directory).map_err(io_error)?.sync_all().map_err(io_error)?;
        let store = Self { directory, _directory_lock: guard, _lock: lock, identity };
        store.load()?;
        Ok(store)
    }
    /// Return the fixed identity bound to every loaded or saved record.
    pub fn identity(&self) -> &ClaimIdentity {
        &self.identity
    }
    /// Read only the atomic committed journal, never an interrupted temporary file.
    pub fn load(&self) -> Result<Option<ClaimJob>> {
        let file = match File::open(self.directory.join("claim-state.json")) {
            Ok(file) => file,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
            Err(e) => return Err(io_error(e)),
        };
        if file.metadata().map_err(io_error)?.len() > MAX_BYTES {
            return Err(journal_error());
        }
        let mut bytes = Vec::new();
        file.take(MAX_BYTES + 1).read_to_end(&mut bytes).map_err(io_error)?;
        if bytes.len() as u64 > MAX_BYTES {
            return Err(journal_error());
        }
        let journal: Journal = serde_json::from_slice(&bytes).map_err(|_| journal_error())?;
        if journal.version != VERSION || journal.identity != self.identity {
            return Err(journal_error());
        }
        self.validate(&journal.job)?;
        Ok(Some(journal.job))
    }
    /// Fsync original signed bytes before broadcast; reject any attempt to replace a signed job.
    pub fn save(&self, job: &ClaimJob) -> Result<()> {
        self.validate(job)?;
        if let Some(old) = self.load()? &&
            (old.proof.receipt != job.proof.receipt ||
                (old.transaction.is_some() &&
                    (old.transaction != job.transaction || old.proof != job.proof)))
        {
            return Err(LanderError::Journal("cannot replace immutable claim job".into()));
        }
        let bytes = serde_json::to_vec(&Journal {
            version: VERSION,
            identity: self.identity.clone(),
            job: job.clone(),
        })
        .map_err(|_| journal_error())?;
        if bytes.len() as u64 > MAX_BYTES {
            return Err(journal_error());
        }
        let temporary = self.directory.join("claim-state.json.tmp");
        let mut file = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&temporary)
            .map_err(io_error)?;
        file.write_all(&bytes).map_err(io_error)?;
        file.sync_all().map_err(io_error)?;
        std::fs::rename(&temporary, self.directory.join("claim-state.json")).map_err(io_error)?;
        File::open(&self.directory).map_err(io_error)?.sync_all().map_err(io_error)?;
        Ok(())
    }
    /// Validate phase shape, receipt identity and every byte-bound transaction input.
    fn validate(&self, job: &ClaimJob) -> Result<()> {
        self.identity.validate_receipt(&job.proof.receipt)?;
        if job.proof.anchor_timestamp == 0 ||
            job.proof.account_proof.is_empty() ||
            job.proof.storage_proof.is_empty()
        {
            return Err(journal_error());
        }
        if (job.state == ClaimState::Prepared) != job.transaction.is_none() ||
            (job.state == ClaimState::Included) != job.inclusion.is_some()
        {
            return Err(journal_error());
        }
        if let Some(tx) = &job.transaction {
            tx.validate(&self.identity, &job.proof)?;
            if job.inclusion.is_some_and(|r| {
                r.transaction_hash != tx.hash || !r.success || r.block_hash.is_zero()
            }) {
                return Err(journal_error());
            }
        }
        Ok(())
    }
}
/// Fixed diagnostics avoid echoing arbitrary persisted or upstream contents.
fn journal_error() -> LanderError {
    LanderError::Journal("invalid claim journal schema, identity or state".into())
}
/// Local I/O failures carry no private key contents or RPC endpoint.
fn io_error(error: std::io::Error) -> LanderError {
    LanderError::Journal(format!("claim journal I/O: {error}"))
}
