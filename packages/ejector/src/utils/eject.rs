use std::{collections::HashSet, time::Duration};

use alloy::{
    primitives::{Address, U256},
    providers::{Provider, ProviderBuilder},
    transports::http::reqwest::Url,
};
use tracing::{info, warn};

use super::{lookahead::Lookahead, receipt::poll_receipt_until};
use crate::{bindings, metrics};

async fn eject_operator_internal(
    l1_http_url: Url,
    signer: alloy::signers::local::PrivateKeySigner,
    whitelist_addr: Address,
    operator: Address,
    min_operators: u64,
    reason: &str,
) -> eyre::Result<()> {
    if operator.is_zero() {
        warn!(reason = reason, "Operator address is zero; skipping eject");
        return Ok(());
    }

    let l1 = ProviderBuilder::new().wallet(signer.clone()).connect_http(l1_http_url.clone());
    let preconf_whitelist = bindings::IPreconfWhitelist::new(whitelist_addr, l1.clone());

    let info = preconf_whitelist.operators(operator).call().await?;
    if info.activeSince == 0 || info.inactiveSince != 0 {
        info!(
            reason = reason,
            operator = ?operator,
            active_since = info.activeSince,
            inactive_since = info.inactiveSince,
            "Operator already inactive; skipping eject"
        );
        return Ok(());
    }

    let active_operators = active_operator_count(&preconf_whitelist, None).await?;
    if min_operators > 0 && active_operators <= min_operators {
        warn!(
            reason = reason,
            operator = ?operator,
            active_operators = active_operators,
            min_operators = min_operators,
            "Not ejecting operator due to min_operators guard"
        );
        return Ok(());
    }

    //since this pulls from active_operator_count which pulls from operatorMapping, operator_hex == proposer_hex
    let operator_hex = format!("{operator:#x}");
    metrics::ensure_eject_metric_labels(&operator_hex);

    info!(reason = reason, operator = %operator_hex, "Sending removeOperator transaction");

    let pending = preconf_whitelist.removeOperator(operator, true).send().await?;
    let tx_hash = pending.tx_hash();
    info!(
        reason = reason,
        operator = %operator_hex,
        tx = ?tx_hash,
        "removeOperator transaction sent"
    );

    let poll_every = Duration::from_secs(12);
    let timeout = Duration::from_secs(120);

    match poll_receipt_until(l1.clone(), *tx_hash, poll_every, timeout).await? {
        Some(rcpt) => {
            info!(
                reason = reason,
                operator = %operator_hex,
                block = ?rcpt.block_number,
                tx = ?rcpt.transaction_hash,
                "removeOperator mined"
            );
            metrics::inc_eject_success(&operator_hex);
        }
        None => {
            warn!(
                reason = reason,
                operator = %operator_hex,
                tx = ?tx_hash,
                "Timed out waiting for removeOperator receipt"
            );
            metrics::inc_eject_error(&operator_hex);
        }
    }

    Ok(())
}

pub async fn eject_operator(
    l1_http_url: Url,
    signer: alloy::signers::local::PrivateKeySigner,
    whitelist_addr: Address,
    lookahead: Lookahead,
    min_operators: u64,
) -> eyre::Result<()> {
    let l1 = ProviderBuilder::new().wallet(signer.clone()).connect_http(l1_http_url.clone());
    let preconf_whitelist = bindings::IPreconfWhitelist::new(whitelist_addr, l1);

    let operator = match lookahead {
        Lookahead::Current => preconf_whitelist.getOperatorForCurrentEpoch().call().await?,
        Lookahead::Next => preconf_whitelist.getOperatorForNextEpoch().call().await?,
    };

    let reason = match lookahead {
        Lookahead::Current => "lookahead_current",
        Lookahead::Next => "lookahead_next",
    };

    eject_operator_internal(l1_http_url, signer, whitelist_addr, operator, min_operators, reason)
        .await
}

pub async fn eject_operator_by_address(
    l1_http_url: Url,
    signer: alloy::signers::local::PrivateKeySigner,
    whitelist_addr: Address,
    operator: Address,
    min_operators: u64,
) -> eyre::Result<()> {
    eject_operator_internal(l1_http_url, signer, whitelist_addr, operator, min_operators, "reorg")
        .await
}

// active operators have activeSince != 0 and inactiveSince == 0
async fn active_operator_count<P>(
    preconf_whitelist: &bindings::IPreconfWhitelist::IPreconfWhitelistInstance<P>,
    seen: Option<&mut HashSet<(Address, Address)>>,
) -> eyre::Result<u64>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let mut seen = seen;
    let operator_count = preconf_whitelist.operatorCount().call().await?;

    let mut count = 0u64;
    for i in 0..operator_count {
        let addr = preconf_whitelist.operatorMapping(U256::from(i)).call().await?;
        let info = preconf_whitelist.operators(addr).call().await?;

        let is_active = info.inactiveSince == 0 && info.activeSince != 0;

        if is_active {
            if let Some(set) = seen.as_deref_mut() {
                let inserted = set.insert((addr, info.sequencerAddress));
                if inserted {
                    let proposer_addr = addr.to_string();
                    metrics::ensure_eject_metric_labels(&proposer_addr);
                }
            }
            count += 1;
        }

        // log out each operator's info
        info!(
            "Operator {}: addr: {:#x}, activeSince: {}, inactiveSince: {}, index: {}, sequencerAddress: {:#x}",
            i, addr, info.activeSince, info.inactiveSince, info.index, info.sequencerAddress
        );
    }

    info!("Active operatorcount: {}", count);

    Ok(count)
}

pub async fn initialize_eject_metrics<P>(
    preconf_whitelist: &bindings::IPreconfWhitelist::IPreconfWhitelistInstance<P>,
) -> eyre::Result<HashSet<(Address, Address)>>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let mut initialized = HashSet::new();
    let _ = active_operator_count(preconf_whitelist, Some(&mut initialized)).await?;
    Ok(initialized)
}
