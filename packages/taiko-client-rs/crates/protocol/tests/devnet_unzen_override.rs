//! Verifies that the devnet Unzen timestamp override flows through the
//! protocol crate's fork-condition lookup. Lives in its own integration
//! binary because the underlying override is a process-global `OnceLock`.

use alloy_hardforks::ForkCondition;
use protocol::shasta::{
    constants::{
        DERIVATION_SOURCE_MAX_BLOCKS, TAIKO_DEVNET_CHAIN_ID, TAIKO_HOODI_CHAIN_ID,
        TAIKO_MAINNET_CHAIN_ID, TAIKO_MASAYA_CHAIN_ID, UNZEN_DERIVATION_SOURCE_MAX_BLOCKS,
        derivation_source_max_blocks_for_chain_timestamp, unzen_fork_condition_for_chain,
    },
    set_devnet_unzen_override, unzen_active_for_chain_timestamp, unzen_fork_timestamp_for_chain,
};

#[test]
fn devnet_override_flows_through_fork_lookups() {
    set_devnet_unzen_override(42);

    assert_eq!(
        unzen_fork_condition_for_chain(TAIKO_DEVNET_CHAIN_ID),
        Some(ForkCondition::Timestamp(42)),
        "devnet should reflect the override"
    );
    assert_eq!(
        unzen_fork_timestamp_for_chain(TAIKO_DEVNET_CHAIN_ID).expect("devnet timestamp"),
        42
    );
    assert!(
        !unzen_active_for_chain_timestamp(TAIKO_DEVNET_CHAIN_ID, 41).expect("devnet active"),
        "devnet should be inactive before override timestamp"
    );
    assert!(
        unzen_active_for_chain_timestamp(TAIKO_DEVNET_CHAIN_ID, 42).expect("devnet active"),
        "devnet should be active at override timestamp"
    );
    assert_eq!(
        derivation_source_max_blocks_for_chain_timestamp(TAIKO_DEVNET_CHAIN_ID, 41),
        DERIVATION_SOURCE_MAX_BLOCKS
    );
    assert_eq!(
        derivation_source_max_blocks_for_chain_timestamp(TAIKO_DEVNET_CHAIN_ID, 42),
        UNZEN_DERIVATION_SOURCE_MAX_BLOCKS
    );
    assert_eq!(
        derivation_source_max_blocks_for_chain_timestamp(TAIKO_DEVNET_CHAIN_ID, 43),
        UNZEN_DERIVATION_SOURCE_MAX_BLOCKS
    );

    assert_eq!(
        unzen_fork_condition_for_chain(TAIKO_MAINNET_CHAIN_ID),
        Some(ForkCondition::Never),
        "mainnet must not be affected"
    );
    assert_eq!(
        unzen_fork_condition_for_chain(TAIKO_MASAYA_CHAIN_ID),
        Some(ForkCondition::Timestamp(1_778_158_800)),
        "masaya must reflect its configured Unzen activation, not the devnet override"
    );
    assert_eq!(
        unzen_fork_condition_for_chain(TAIKO_HOODI_CHAIN_ID),
        Some(ForkCondition::Never),
        "hoodi must not be affected"
    );
}
