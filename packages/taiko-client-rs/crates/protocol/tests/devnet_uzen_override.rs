//! Verifies that the devnet Uzen timestamp override flows through the
//! protocol crate's fork-condition lookup. Lives in its own integration
//! binary because the underlying override is a process-global `OnceLock`.

use alloy_hardforks::ForkCondition;
use protocol::shasta::{
    constants::{
        TAIKO_DEVNET_CHAIN_ID, TAIKO_HOODI_CHAIN_ID, TAIKO_MAINNET_CHAIN_ID, TAIKO_MASAYA_CHAIN_ID,
        uzen_fork_condition_for_chain,
    },
    set_devnet_uzen_override, uzen_active_for_chain_timestamp, uzen_fork_timestamp_for_chain,
};

#[test]
fn devnet_override_flows_through_fork_lookups() {
    set_devnet_uzen_override(42);

    assert_eq!(
        uzen_fork_condition_for_chain(TAIKO_DEVNET_CHAIN_ID),
        Some(ForkCondition::Timestamp(42)),
        "devnet should reflect the override"
    );
    assert_eq!(uzen_fork_timestamp_for_chain(TAIKO_DEVNET_CHAIN_ID).expect("devnet timestamp"), 42);
    assert!(
        !uzen_active_for_chain_timestamp(TAIKO_DEVNET_CHAIN_ID, 41).expect("devnet active"),
        "devnet should be inactive before override timestamp"
    );
    assert!(
        uzen_active_for_chain_timestamp(TAIKO_DEVNET_CHAIN_ID, 42).expect("devnet active"),
        "devnet should be active at override timestamp"
    );

    assert_eq!(
        uzen_fork_condition_for_chain(TAIKO_MAINNET_CHAIN_ID),
        Some(ForkCondition::Never),
        "mainnet must not be affected"
    );
    assert_eq!(
        uzen_fork_condition_for_chain(TAIKO_MASAYA_CHAIN_ID),
        Some(ForkCondition::Never),
        "masaya must not be affected"
    );
    assert_eq!(
        uzen_fork_condition_for_chain(TAIKO_HOODI_CHAIN_ID),
        Some(ForkCondition::Never),
        "hoodi must not be affected"
    );
}
