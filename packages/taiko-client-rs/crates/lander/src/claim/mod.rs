//! Independent L2 reward claims. A canonical successful claim is final: Etna L2 blocks are
//! BFT-final, and a rerun after any recovery that rewinds L2 reconciles the retained signature.

use crate::{
    LanderError, Result,
    rewards::{self, Receipt},
};
use alloy::sol_types::{SolCall, SolValue};
use alloy_primitives::{Address, B256, Bytes, U256};
use serde::{Deserialize, Serialize};

/// Resume-first reconciliation of a single immutable transaction.
pub mod runner;
/// Hash-pinned receipt proofs under the own finalized L1 anchor.
pub mod source;
/// Claim-only durable journal and directory lock.
pub mod store;
/// Ordinary L2 transaction signing and transport.
pub mod tx;

alloy::sol!(
    #[sol(all_derives)]
    Vault,
    "tests/fixtures/contracts/L2FeeVault.json"
);

/// Authenticated immutable entitlement and its calldata proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ClaimProof {
    /// Exact shared receipt type; ABI serialization preserves every field.
    #[serde(with = "crate::contracts::abi_serde")]
    pub receipt: Receipt,
    /// Timestamp of the canonical L2 header whose roots entry was checked, in seconds.
    pub anchor_timestamp: u64,
    /// Full account inclusion proof under the authenticated L1 state root.
    pub account_proof: Vec<Bytes>,
    /// Storage inclusion proof for the fixed receipt mapping slot.
    pub storage_proof: Vec<Bytes>,
}

impl ClaimProof {
    /// Encode the exact pinned vault ABI without duplicating its tuple definition.
    pub fn calldata(&self) -> Result<Bytes> {
        let receipt = LibEtnaRewards::Receipt::abi_decode(&self.receipt.abi_encode())
            .map_err(|_| LanderError::Safety("receipt ABI mismatch".into()))?;
        Ok(Vault::claimCall {
            _receipt: receipt,
            _anchorTimestamp: U256::from(self.anchor_timestamp),
            _accountProof: self.account_proof.clone(),
            _storageProof: self.storage_proof.clone(),
        }
        .abi_encode()
        .into())
    }
}

/// Public identities bound to a single claim directory; never contains a key or endpoint.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ClaimIdentity {
    /// Successful L1 landing transaction used only for event discovery.
    pub landing_tx: B256,
    /// Receipt batch identifier.
    pub batch_id: B256,
    /// Own L1 chain identity, also checked against the vault immutable.
    pub l1_chain_id: U256,
    /// Own L2 chain identity.
    pub l2_chain_id: u64,
    /// Inbox discovered from the canonical vault's immutable configuration.
    pub inbox: Address,
    /// Canonical chain treasury/vault.
    pub vault: Address,
    /// Explicit L2 gas payer; independent of the receipt's payout recipient.
    pub payer: Address,
}

impl ClaimIdentity {
    /// Reject invalid identities before signing or loading any job.
    pub fn validate(&self) -> Result<()> {
        if self.landing_tx.is_zero() ||
            self.batch_id.is_zero() ||
            self.l1_chain_id.is_zero() ||
            self.l2_chain_id == 0 ||
            self.inbox.is_zero() ||
            self.vault.is_zero() ||
            self.payer.is_zero()
        {
            return Err(LanderError::Configuration("claim identity contains zero fields".into()));
        }
        let params = abci::ChainParams::builtin(self.l2_chain_id)
            .map_err(|_| LanderError::Configuration("unsupported claim L2 chain".into()))?;
        if self.vault != params.fee_vault {
            return Err(LanderError::Safety("claim vault differs from canonical treasury".into()));
        }
        Ok(())
    }

    /// Bind every receipt identity; reward amount may legitimately be zero.
    pub fn validate_receipt(&self, receipt: &Receipt) -> Result<()> {
        self.validate()?;
        if receipt.l1ChainId != self.l1_chain_id ||
            receipt.l2ChainId != self.l2_chain_id ||
            receipt.inbox != self.inbox ||
            receipt.l2RewardRecipient.is_zero() ||
            receipt.lastHeight <= receipt.parentHeight ||
            receipt.parentHash.is_zero() ||
            receipt.lastBlockHash.is_zero() ||
            rewards::batch_id(receipt) != self.batch_id
        {
            return Err(LanderError::Safety("claim receipt identity mismatch".into()));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests;
