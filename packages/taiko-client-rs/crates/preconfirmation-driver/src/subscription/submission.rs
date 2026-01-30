//! Submission helpers for validated preconfirmation inputs.

use alloy_primitives::{B256, U256};
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{PreconfHead, SignedCommitment, uint256_to_u256};
use tracing::{debug, info, warn};

use crate::{
    driver_interface::{DriverClient, PreconfirmationInput},
    error::{PreconfirmationClientError, Result},
    metrics::PreconfirmationClientMetrics,
    validation::is_eop_only,
};

use super::event_handler::EventHandler;

impl<D> EventHandler<D>
where
    D: DriverClient,
{
    /// Attempt to submit contiguous commitments starting at the provided block.
    pub(super) async fn try_submit_contiguous_from(&self, start: U256) -> Result<()> {
        info!(start = %start, "attempting contiguous preconfirmation submit");
        let mut next = start;
        let mut submitted_count = 0usize;
        loop {
            let Some(commitment) = self.store.get_commitment(&next) else {
                debug!(
                    next = %next,
                    submitted_count,
                    "missing commitment; stopping contiguous submit"
                );
                break;
            };

            let submitted = self.submit_if_ready(commitment).await?;
            if !submitted {
                debug!(
                    next = %next,
                    submitted_count,
                    "commitment not ready; stopping contiguous submit"
                );
                break;
            }

            submitted_count += 1;
            next += U256::ONE;
        }

        info!(
            start = %start,
            next = %next,
            submitted_count,
            "contiguous submit finished"
        );
        Ok(())
    }

    /// Submit a commitment if its txlist is available and validation passes.
    pub(super) async fn submit_if_ready(&self, commitment: SignedCommitment) -> Result<bool> {
        let block_number = uint256_to_u256(&commitment.commitment.preconf.block_number);
        let input = if is_eop_only(&commitment) {
            info!(block_number = %block_number, "submitting eop-only commitment");
            PreconfirmationInput::new(commitment, None, None)
        } else {
            let raw_tx_list_hash = commitment.commitment.preconf.raw_tx_list_hash.clone();
            let txlist_hash = B256::from_slice(raw_tx_list_hash.as_ref());
            let Some(txlist) = self.store.get_txlist(&txlist_hash) else {
                debug!(
                    block_number = %block_number,
                    txlist_hash = %txlist_hash,
                    "txlist missing; queuing commitment"
                );
                self.store.add_awaiting_txlist(&raw_tx_list_hash, commitment);
                return Ok(false);
            };

            info!(
                block_number = %block_number,
                txlist_hash = %txlist_hash,
                "txlist available; submitting commitment"
            );
            let transactions = self.codec.decode(txlist.txlist.as_ref()).map_err(|err| {
                warn!(block_number = %block_number, error = %err, "failed to decode txlist");
                PreconfirmationClientError::Codec(err.to_string())
            })?;
            PreconfirmationInput::new(commitment, Some(transactions), Some(txlist.txlist.to_vec()))
        };

        self.driver
            .submit_preconfirmation(input)
            .await
            .inspect(|()| {
                metrics::counter!(PreconfirmationClientMetrics::DRIVER_SUBMIT_SUCCESS_TOTAL)
                    .increment(1);
            })
            .inspect_err(|err| {
                warn!(block_number = %block_number, error = %err, "driver submit failed");
                metrics::counter!(PreconfirmationClientMetrics::DRIVER_SUBMIT_FAILURE_TOTAL)
                    .increment(1);
            })?;

        info!(block_number = %block_number, "driver submit succeeded");
        Ok(true)
    }

    /// Update the local head snapshot based on a new commitment.
    pub(super) async fn update_head(&self, commitment: &SignedCommitment) {
        let head = PreconfHead {
            block_number: commitment.commitment.preconf.block_number.clone(),
            submission_window_end: commitment.commitment.preconf.submission_window_end.clone(),
        };

        let new_block = uint256_to_u256(&head.block_number);
        if self.store.head().is_some_and(|h| new_block <= uint256_to_u256(&h.block_number)) {
            return;
        }

        self.store.set_head(head.clone());

        let block_f64: f64 = new_block.into();
        metrics::gauge!(PreconfirmationClientMetrics::HEAD_BLOCK).set(block_f64);

        if let Err(err) = self.notify_head_update(head).await {
            warn!(error = %err, "failed to notify p2p head update");
        }
    }

    /// Notify the P2P layer about a new head update.
    pub(super) async fn notify_head_update(&self, head: PreconfHead) -> Result<()> {
        self.command_tx
            .send(NetworkCommand::UpdateHead { head })
            .await
            .map_err(|err| PreconfirmationClientError::Network(err.to_string()))
    }
}

#[cfg(test)]
pub(crate) const SUBMISSION_MODULE_MARKER: () = ();
