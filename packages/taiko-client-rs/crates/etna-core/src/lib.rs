//! Portable Etna consensus primitives: the pure rules that nodes, the lander and the Raiko2
//! guests share.
//!
//! The crate tests check compatibility with the stock CometBFT v0.40.0 wire and validator-state
//! vectors copied from that baseline.
//!
//! [`committee::decide`] decides at each block H the set that signs H + 2: the candidate snapshot
//! that H's block-start call stored in the L2 staking contract ([`staking`]) when it is usable,
//! otherwise the DAO fallback key set ([`fallback`]), each key at power 1.
//! [`committee::validator_updates`] turns two consecutive sets into CometBFT validator updates,
//! and [`comet::validators::Validators::from_members`] checks a set's identities and powers.
//! Consumers read the staking words from H's post-state and the minimum total stake and fallback
//! key list from H's anchor, and authenticate them; this crate proves nothing about its inputs.
//!
//! [`extra_data::ExtraData`] is a block's 29-byte `extraData`; [`miss::miss_bitmap`] gives its
//! `missBitmap` from the parent's signers that the block's LastCommit marks missing and their
//! key-to-seat words in the parent's post-state.
//!
//! The Comet certificate and body helpers verify individual consensus commitments. Consumers
//! compose these checks with generation and range validation, execution and forced inclusion
//! rules, and their own state and witness handling.

#![cfg_attr(not(test), no_std)]
#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
extern crate alloc;
#[cfg(test)]
extern crate std;
/// Native Comet codecs, QC and original body commitments.
pub mod comet;
/// The signing set decision, from the candidate snapshot or the fallback keys, and validator
/// updates.
pub mod committee;
/// Deployment and generation signing domain.
pub mod domain;
/// The 29-byte block `extraData`: base-fee sharing percentage, generation, anchor number and
/// `missBitmap`.
pub mod extra_data;
/// DAO fallback key set: the validated key list, its hash and its canonical ABI encoding.
pub mod fallback;
/// Validated consensus identities and stock key JSON.
pub mod key;
/// Validated views of original raw L1 execution headers.
pub mod l1_header;
/// The validators missing from a block's LastCommit and the `missBitmap` of their seats.
pub mod miss;
/// Canonical deployment data and pure parameter validation.
pub mod params;
/// L2 staking contract storage layout: candidate snapshot slots and the key-to-seat decoder.
pub mod staking;
#[cfg(test)]
mod test_utils;
/// Canonical genesis and generation origin records.
pub mod types;
/// Stock native validator protobuf and commitments.
pub mod validator;
/// Stock per-height validator-state transitions, canonical preimages and the app hash.
pub mod valstate;
