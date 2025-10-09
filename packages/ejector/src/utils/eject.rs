use std::time::Duration;

use alloy::{
    primitives::{Address, U256},
    providers::{Provider, ProviderBuilder},
    transports::http::reqwest::Url,
};
use tracing::{info, warn};

use crate::{bindings, metrics};

use super::{
    lookahead::Lookahead,
    receipt::poll_receipt_until,
};

pub async fn eject_operator(
    l1_http_url: Url,
    signer: alloy::signers::local::PrivateKeySigner,
    whitelist_addr: Address,
    lookahead: Lookahead,
    min_operators: u64,
) -> eyre::Result<()> {
    let l1 = ProviderBuilder::new().wallet(signer.clone()).connect_http(l1_http_url.clone());

    let preconf_whitelist = bindings::IPreconfWhitelist::new(whitelist_addr, l1.clone());

    let active_operators = active_operator_count(&preconf_whitelist).await?;

    if min_operators > 0 && active_operators <= min_operators {
        warn!(
            "Not ejecting operator: operator_count {}, min_operators {}",
            active_operators, min_operators
        );

        return Ok(());
    }

    let operator = match lookahead {
        Lookahead::Current => preconf_whitelist.getOperatorForCurrentEpoch().call().await?,
        Lookahead::Next => preconf_whitelist.getOperatorForNextEpoch().call().await?,
    };

    info!("Ejecting operator: {operator:#x} for lookahead: {lookahead:?}");

    if operator.is_zero() {
        warn!("{lookahead:?} operator is zero; skipping eject.");
        return Ok(());
    }

    let pending = preconf_whitelist.removeOperator(operator, true).send().await?;

    let tx_hash = pending.tx_hash();
    info!("Eject operator transaction sent: {:?}", tx_hash);

    let poll_every = Duration::from_secs(12);
    let timeout = Duration::from_secs(120);

    match poll_receipt_until(l1.clone(), *tx_hash, poll_every, timeout).await? {
        Some(rcpt) => {
            info!(
                "removeOperator mined in block {:?}, tx {:?}",
                rcpt.block_number, rcpt.transaction_hash
            );

            metrics::inc_eject_success(&operator.to_string());
        }
        None => {
            warn!("Timed out waiting for receipt for {tx_hash:#x}; continuing to run.");
            metrics::inc_eject_error(&operator.to_string());
        }
    }
    Ok(())
}

// active operators have activeSince != 0 and inactiveSince == 0
async fn active_operator_count<P>(
    preconf_whitelist: &bindings::IPreconfWhitelist::IPreconfWhitelistInstance<P>,
) -> eyre::Result<u64>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let operator_count = preconf_whitelist.operatorCount().call().await?;

    let mut count = 0u64;
    for i in 0..operator_count {
        let addr = preconf_whitelist.operatorMapping(U256::from(i)).call().await?;
        let info = preconf_whitelist.operators(addr).call().await?;
        if info.inactiveSince == 0 && info.activeSince != 0 {
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
