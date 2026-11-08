//! Typed first-cause evidence; never a latch override or signing authority by itself.
use alloy_primitives::Address;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

/// File retained beside the original fatal evidence; never copied to a new generation.
pub const SUPERSESSION_FILE: &str = "generation-superseded.json";

/// Binds a proof-authenticated higher generation to the exact original durable app/fatal bytes.
/// Only the app's first terminal transition may produce this marker. Recovery independently
/// authenticates the new governance domain before acknowledging it, retaining all old files.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SupersessionEvidence {
    /// Only supported typed terminal schema.
    pub schema: u32,
    /// Exact old deployment signing domain.
    pub chain_id: String,
    /// Old committed app generation.
    pub previous_generation: u64,
    /// Higher generation authenticated by own-finalized proof verification.
    pub current_generation: u64,
    /// Old deployment Inbox identity.
    pub inbox: Address,
    /// SHA-256 of the unchanged original AppState bytes.
    pub state_digest: String,
    /// SHA-256 of the exact first fatal evidence bytes.
    pub fatal_digest: String,
}
impl SupersessionEvidence {
    /// Construct only after a first-cause authenticated supersession and durable fatal write.
    pub(crate) fn new(
        state: &crate::store::AppState,
        current: u64,
        bytes: &[u8],
        fatal: &[u8],
    ) -> Self {
        Self {
            schema: 1,
            chain_id: state.chain_id.clone(),
            previous_generation: state.generation,
            current_generation: current,
            inbox: state.inbox,
            state_digest: digest(bytes),
            fatal_digest: digest(fatal),
        }
    }
    /// Check exact original state/fatal bytes and typed domain, without mutating either.
    pub fn validates(&self, state_bytes: &[u8], fatal: &[u8]) -> bool {
        let Ok(state) = crate::store::decode_journal(
            state_bytes,
            std::path::Path::new(crate::store::STATE_FILE),
        ) else {
            return false;
        };
        self.schema == 1 &&
            self.previous_generation < self.current_generation &&
            self.current_generation < 1 << 48 &&
            self.chain_id == state.chain_id &&
            self.previous_generation == state.generation &&
            self.inbox == state.inbox &&
            self.state_digest == digest(state_bytes) &&
            self.fatal_digest == digest(fatal)
    }
}
/// Stable public digest encoding, shared with the private supervisor's sidecar reference.
pub fn digest(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{Store, test_utils::Fixture};
    #[test]
    fn supersession_evidence_preserves_prior_causes_and_rejects_lost_or_tampered_bytes() {
        let state = Fixture::genesis(1).expected_state();
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        store.save(&state).unwrap();
        store.record_fatal("unrelated safety failure").unwrap();
        store.record_supersession(&state, 1, "expected supersession").unwrap();
        assert!(!dir.path().join(SUPERSESSION_FILE).exists());
        assert_eq!(store.fatal_evidence().unwrap().as_deref(), Some("unrelated safety failure"));
        let fresh = tempfile::tempdir().unwrap();
        let store = Store::new(fresh.path().into());
        store.save(&state).unwrap();
        store.record_supersession(&state, 1, "expected supersession").unwrap();
        let bytes = std::fs::read(fresh.path().join(crate::store::STATE_FILE)).unwrap();
        let evidence: SupersessionEvidence =
            serde_json::from_slice(&std::fs::read(fresh.path().join(SUPERSESSION_FILE)).unwrap())
                .unwrap();
        assert!(evidence.validates(&bytes, b"expected supersession"));
        assert!(!evidence.validates(&bytes, b"other fatal"));
        let mut changed = bytes.clone();
        changed.push(b' ');
        assert!(!evidence.validates(&changed, b"expected supersession"));
        std::fs::remove_file(fresh.path().join("fatal-evidence.txt")).unwrap();
        assert!(
            store.record_supersession(&state, 1, "expected supersession").is_err(),
            "lost fatal bytes cannot be regenerated"
        );
        assert!(!fresh.path().join("fatal-evidence.txt").exists());
    }
}
