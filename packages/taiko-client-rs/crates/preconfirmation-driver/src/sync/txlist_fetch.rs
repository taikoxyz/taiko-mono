//! Txlist fetch helpers used during catch-up.

use alloy_primitives::B256;
use preconfirmation_net::{NetworkCommand, NetworkError, NetworkErrorKind};
use preconfirmation_types::{Bytes32, RawTxListGossip};
use tokio::sync::{mpsc::Sender, oneshot};
use tracing::warn;

use crate::error::{PreconfirmationClientError, Result};

/// Request a raw txlist from the network using a command tx.
async fn request_raw_txlist_with_tx(
    command_tx: Sender<NetworkCommand>,
    hash: Bytes32,
) -> Result<preconfirmation_types::GetRawTxListResponse> {
    let (tx, rx) = oneshot::channel();
    command_tx
        .send(NetworkCommand::RequestRawTxList {
            respond_to: Some(tx),
            raw_tx_list_hash: hash,
            peer: None,
        })
        .await
        .map_err(|err| PreconfirmationClientError::Catchup(format!("send command: {err}")))?;

    rx.await
        .unwrap_or_else(|_| {
            Err(NetworkError::new(
                NetworkErrorKind::ReqRespTimeout,
                "service stopped before raw-txlist response",
            ))
        })
        .map_err(|err| PreconfirmationClientError::Catchup(err.to_string()))
}

/// Fetch and validate a txlist for a commitment hash.
pub(super) async fn fetch_txlist(
    command_tx: Sender<NetworkCommand>,
    hash: Bytes32,
) -> Result<Option<RawTxListGossip>> {
    let hash_hex = B256::from_slice(hash.as_ref());
    let response = request_raw_txlist_with_tx(command_tx, hash.clone()).await.map_err(|err| {
        warn!(hash = %hash_hex, error = %err, "failed to fetch txlist during catch-up");
        err
    })?;
    preconfirmation_types::validate_raw_txlist_response(&response).map_err(|err| {
        warn!(hash = %hash_hex, error = %err, "txlist validation failed during catch-up");
        PreconfirmationClientError::Validation(format!("txlist {hash_hex}: {err}"))
    })?;
    if response.txlist.is_empty() {
        return Ok(None);
    }
    if response.raw_tx_list_hash.as_ref() != hash.as_ref() {
        let actual = B256::from_slice(response.raw_tx_list_hash.as_ref());
        return Err(PreconfirmationClientError::Validation(format!(
            "txlist hash mismatch: requested {hash_hex} got {actual}"
        )));
    }
    Ok(Some(RawTxListGossip { raw_tx_list_hash: hash, txlist: response.txlist }))
}

#[cfg(test)]
pub(crate) const TXLIST_FETCH_MODULE_MARKER: () = ();
