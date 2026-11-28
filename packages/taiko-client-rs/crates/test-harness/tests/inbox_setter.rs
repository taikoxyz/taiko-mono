//! The harness Inbox setter serves a fallback key list as the Inbox does: slot 278 holds its
//! hash, `getFallbackKeys()` returns it in the state of every block where that hash is stored,
//! and its `FallbackKeysUpdated` log carries it, so a node still finds a replaced list by its
//! hash.

use abci::{
    L1Source, RpcL1Source,
    fallback::{FALLBACK_KEYS_UPDATED, FallbackKeys, fetch_fallback_keys, getFallbackKeysCall},
    l1::layout::inbox,
};
use alloy::sol_types::SolCall;
use alloy_primitives::{Address, B256, Bytes, U256};
use anyhow::{Result, ensure};
use test_harness::{Planter, StandaloneAnvil, ValidatorKey, validator_keys};

/// The address the setter is installed at.
const INBOX: Address = Address::repeat_byte(0x1b);

/// The fallback key list of `keys`' consensus keys.
fn list(keys: &[ValidatorKey]) -> Result<FallbackKeys> {
    let mut keys: Vec<_> = keys.iter().map(ValidatorKey::pubkey).collect();
    keys.sort();
    Ok(FallbackKeys::new(keys)?)
}

/// The list `getFallbackKeys()` returns in the state of the L1 block with hash `at`.
async fn served(l1: &RpcL1Source, at: B256) -> Result<FallbackKeys> {
    let data = l1.call_at(INBOX, getFallbackKeysCall {}.abi_encode().into(), at).await?;
    Ok(FallbackKeys::from_abi(&data)?)
}

/// List A, then list B: B's hash is the latest slot 278, A comes from `getFallbackKeys()` at A's
/// planting block and, where the call answers B, from A's log found by its hash.
#[tokio::test]
#[ignore = "requires Docker: harness Inbox setter on anvil"]
async fn planted_fallback_keys_are_served_by_the_setter() -> Result<()> {
    let anvil = StandaloneAnvil::start().await?;
    let planter = Planter::new(anvil.provider.clone(), INBOX);
    planter.install().await?;
    let keys = validator_keys(4);
    let (a, b) = (list(&keys[..2])?, list(&keys[2..])?);
    let a_block = planter.plant_fallback_keys(&a).await?;
    let b_block = planter.plant_fallback_keys(&b).await?;
    ensure!(a_block < b_block, "A landed in block {a_block}, B in block {b_block}");
    assert_eq!(
        planter.inbox_word(inbox::slot(inbox::FALLBACK_KEYS_HASH)).await?,
        U256::from_be_bytes(b.hash().0)
    );

    let l1 = RpcL1Source::new(anvil.provider.clone());
    let (a_at, b_at) = (l1.canonical_hash(a_block).await?, l1.canonical_hash(b_block).await?);
    // The call path: at A's planting block the setter answers A.
    assert_eq!(served(&l1, a_at).await?, a);
    assert_eq!(fetch_fallback_keys(&l1, INBOX, a.hash(), a_at, a_block, 0).await?, a);
    // The log path: at B's planting block the setter answers B, and A's log holds A.
    assert_eq!(served(&l1, b_at).await?, b);
    assert_eq!(
        l1.inbox_logs(INBOX, FALLBACK_KEYS_UPDATED, a.hash(), a_block, a_block).await?,
        [Bytes::from(a.abi_encode())]
    );
    assert_eq!(fetch_fallback_keys(&l1, INBOX, a.hash(), b_at, b_block, 0).await?, a);
    anvil.stop().await
}
