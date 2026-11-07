//! Verifies that the devnet Etna timestamp override flows through the protocol crate's fork
//! lookups. Lives in its own integration binary because the override is a process-global
//! `OnceLock`.

use alloy_hardforks::ForkCondition;
use protocol::shasta::{
    constants::{TAIKO_DEVNET_CHAIN_ID, TAIKO_HOODI_CHAIN_ID, etna_fork_condition_for_chain},
    etna_active_for_chain_timestamp, etna_fork_timestamp_for_chain, set_devnet_etna_override,
};

#[test]
fn devnet_override_flows_through_etna_lookups() {
    assert_eq!(etna_fork_timestamp_for_chain(TAIKO_DEVNET_CHAIN_ID).unwrap(), None);

    set_devnet_etna_override(42);
    set_devnet_etna_override(7); // ignored: the first write wins

    assert_eq!(
        etna_fork_condition_for_chain(TAIKO_DEVNET_CHAIN_ID).unwrap(),
        ForkCondition::Timestamp(42)
    );
    assert_eq!(etna_fork_timestamp_for_chain(TAIKO_DEVNET_CHAIN_ID).unwrap(), Some(42));
    assert!(!etna_active_for_chain_timestamp(TAIKO_DEVNET_CHAIN_ID, 41).unwrap());
    assert!(etna_active_for_chain_timestamp(TAIKO_DEVNET_CHAIN_ID, 42).unwrap());
    // The override is devnet-only.
    assert_eq!(etna_fork_timestamp_for_chain(TAIKO_HOODI_CHAIN_ID).unwrap(), None);
}
