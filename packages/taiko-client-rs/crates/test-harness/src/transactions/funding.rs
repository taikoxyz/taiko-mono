//! Test account funding utilities for E2E tests.
//!
//! This module provides helpers for ensuring test accounts have sufficient funds:
//! - [`ensure_test_account_funded`]: Funds test account from funder if balance is zero.
//! - [`build_test_transfers`]: Builds standard test transfers with automatic funding.

use alloy_primitives::{Address, U256};
use alloy_provider::Provider;
use alloy_signer_local::PrivateKeySigner;
use anyhow::{Result, ensure};

use super::{TransferPayload, build_signed_transfer};

/// Default funding amount: 1 ETH in wei.
pub const DEFAULT_FUND_AMOUNT: u128 = 1_000_000_000_000_000_000;

/// Ensures the test account has funds, funding it from the funder account if needed.
///
/// Reads `TEST_ACCOUNT_PRIVATE_KEY` for the test account and `PRIVATE_KEY` for the funder.
/// If the test account balance is zero, creates a funding transfer from the funder.
///
/// # Arguments
///
/// * `provider` - Provider to check balances and build transactions.
/// * `block_number` - Target block number for the funding transaction.
/// * `fund_amount` - Amount to fund in wei (use [`DEFAULT_FUND_AMOUNT`] for 1 ETH).
///
/// # Returns
///
/// A vector of transfers - empty if already funded, or contains a funding transfer.
///
/// # Example
///
/// ```ignore
/// let funding_txs = ensure_test_account_funded(
///     &provider,
///     100,
///     U256::from(DEFAULT_FUND_AMOUNT),
/// ).await?;
/// ```
pub async fn ensure_test_account_funded<P>(
    provider: &P,
    block_number: u64,
    fund_amount: U256,
) -> Result<Vec<TransferPayload>>
where
    P: Provider + Send + Sync,
{
    let test_key = std::env::var("TEST_ACCOUNT_PRIVATE_KEY")?;
    let test_signer: PrivateKeySigner = test_key.parse()?;
    let test_address = test_signer.address();
    let test_balance = provider.get_balance(test_address).await?;

    if test_balance.is_zero() {
        let funder_key = std::env::var("PRIVATE_KEY")?;
        let funder_signer: PrivateKeySigner = funder_key.parse()?;
        let funder_balance = provider.get_balance(funder_signer.address()).await?;
        ensure!(funder_balance > fund_amount, "funder balance too low to seed test account");

        let funding_tx =
            build_signed_transfer(provider, block_number, &funder_key, test_address, fund_amount)
                .await?;
        Ok(vec![funding_tx])
    } else {
        Ok(vec![])
    }
}

/// Builds test transfers: optional funding + a small transfer from test account.
///
/// This is the most common pattern in E2E tests:
/// 1. Ensure the test account has funds (funding from `PRIVATE_KEY` if needed)
/// 2. Build a small transfer from the test account to a burn address
///
/// # Arguments
///
/// * `provider` - Provider to check balances and build transactions.
/// * `block_number` - Target block number for the transactions.
///
/// # Returns
///
/// A vector of transfers ready to include in a preconfirmation txlist.
///
/// # Example
///
/// ```ignore
/// let transfers = build_test_transfers(&provider, 100).await?;
/// // transfers contains 1-2 transactions depending on whether funding was needed
/// ```
pub async fn build_test_transfers<P>(
    provider: &P,
    block_number: u64,
) -> Result<Vec<TransferPayload>>
where
    P: Provider + Send + Sync,
{
    let test_key = std::env::var("TEST_ACCOUNT_PRIVATE_KEY")?;
    let mut transfers =
        ensure_test_account_funded(provider, block_number, U256::from(DEFAULT_FUND_AMOUNT)).await?;

    // Add a small transfer from test account to burn address.
    transfers.push(
        build_signed_transfer(
            provider,
            block_number,
            &test_key,
            Address::repeat_byte(0x11),
            U256::from(1u64),
        )
        .await?,
    );

    Ok(transfers)
}
