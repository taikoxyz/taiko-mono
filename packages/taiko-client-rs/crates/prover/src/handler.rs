//! Proposal routing decisions: proving-window math and assignment rules
//! (Go `prover/event_handler/{proposal.go,proposal_handler.go,util.go}`). These
//! are pure functions; the orchestrator supplies the RPC-derived inputs.

use std::time::Duration;

use alloy_primitives::Address;

/// Extra delay after window expiry before proving unassigned proposals, so one
/// more L1 block lands first (Go `util.go:18`, `proofExpirationDelay`).
pub const PROOF_EXPIRATION_DELAY: Duration = Duration::from_secs(72);

/// Whether the proving window has expired and how long until it does
/// (Go `IsProvingWindowExpired`, `util.go:48-66`). `expired_at = proposal
/// timestamp + proving window`; the remaining duration saturates at zero.
#[must_use]
pub fn proving_window_status(
    proposal_timestamp: u64,
    proving_window_secs: u64,
    now: u64,
) -> (bool, Duration) {
    let expired_at = proposal_timestamp + proving_window_secs;
    let expired = now > expired_at;
    let remaining = Duration::from_secs(expired_at.saturating_sub(now));
    (expired, remaining)
}

/// Whether this prover should prove inside the window: it is the designated
/// prover (the proposer) or the proposer is one of ours
/// (`--prover.localProposerAddresses`) (Go `shouldProve`,
/// `proposal_handler.go:68-71`).
#[must_use]
pub fn should_prove(designated: Address, prover: Address, local_proposers: &[Address]) -> bool {
    designated == prover || local_proposers.contains(&designated)
}

/// What to do with a proposal right now.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProvingDecision {
    /// Enqueue a proof request immediately.
    SubmitNow,
    /// Re-check after the window expires (plus the safety delay).
    WaitForExpiry(Duration),
    /// Not ours and unassigned proving is disabled.
    Skip,
}

/// Decide what to do with a proposal, mirroring the branch logic of Go
/// `checkExpirationAndSubmitProof` (`proposal.go:117-196`) minus the RPC reads.
///
/// - `designated_should_prove`: result of [`should_prove`] for the proposal.
/// - `window_expired` / `time_to_expire`: result of [`proving_window_status`].
/// - `prove_unassigned`: the `--prover.proveUnassignedProposals` flag.
#[must_use]
pub fn route_proposal(
    designated_should_prove: bool,
    window_expired: bool,
    time_to_expire: Duration,
    prove_unassigned: bool,
) -> ProvingDecision {
    // Inside the window and not ours: wait for expiry if we prove unassigned
    // proposals, otherwise skip (Go `proposal.go:144-169`).
    if !window_expired && !designated_should_prove {
        if prove_unassigned {
            return ProvingDecision::WaitForExpiry(time_to_expire + PROOF_EXPIRATION_DELAY);
        }
        return ProvingDecision::Skip;
    }

    // Expired (or ours): skip only when it is not ours and we do not prove
    // unassigned proposals (Go `proposal.go:173-182`).
    if !prove_unassigned && !designated_should_prove {
        return ProvingDecision::Skip;
    }

    ProvingDecision::SubmitNow
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use alloy_primitives::Address;

    use super::{
        PROOF_EXPIRATION_DELAY, ProvingDecision, proving_window_status, route_proposal,
        should_prove,
    };

    #[test]
    fn window_math_matches_go_util() {
        let (expired, remaining) = proving_window_status(1_000, 300, 1_200);
        assert!(!expired);
        assert_eq!(remaining, Duration::from_secs(100));

        // now == expired_at is not yet expired (Go uses strict `>`).
        assert!(!proving_window_status(1_000, 300, 1_300).0);
        assert_eq!(proving_window_status(1_000, 300, 1_300).1, Duration::ZERO);

        let (expired, remaining) = proving_window_status(1_000, 300, 1_301);
        assert!(expired);
        assert_eq!(remaining, Duration::ZERO);
    }

    #[test]
    fn should_prove_accepts_self_and_local_proposers() {
        let me = Address::repeat_byte(0x01);
        let local = Address::repeat_byte(0x02);
        let other = Address::repeat_byte(0x03);
        let locals = [local];

        assert!(should_prove(me, me, &locals));
        assert!(should_prove(local, me, &locals));
        assert!(!should_prove(other, me, &locals));
    }

    #[test]
    fn routing_matrix_matches_go_proposal_handler() {
        let ttl = Duration::from_secs(50);

        // Designated → always SubmitNow.
        assert_eq!(route_proposal(true, false, ttl, false), ProvingDecision::SubmitNow);
        assert_eq!(route_proposal(true, true, ttl, false), ProvingDecision::SubmitNow);

        // Not ours, inside window, prove_unassigned → wait for expiry + delay.
        assert_eq!(
            route_proposal(false, false, ttl, true),
            ProvingDecision::WaitForExpiry(ttl + PROOF_EXPIRATION_DELAY),
        );

        // Not ours, inside window, no unassigned → skip.
        assert_eq!(route_proposal(false, false, ttl, false), ProvingDecision::Skip);

        // Not ours, expired, prove_unassigned → submit now.
        assert_eq!(route_proposal(false, true, Duration::ZERO, true), ProvingDecision::SubmitNow);

        // Not ours, expired, no unassigned → skip.
        assert_eq!(route_proposal(false, true, Duration::ZERO, false), ProvingDecision::Skip);
    }
}
