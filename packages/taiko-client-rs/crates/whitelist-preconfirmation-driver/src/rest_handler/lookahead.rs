//! Whitelist lookahead evaluation and fee-recipient checks.

use super::*;

impl<P> WhitelistApiHandler<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Check fee recipient against current/next operator sequencing ranges.
    pub(super) async fn ensure_fee_recipient_allowed(&self, fee_recipient: Address) -> Result<()> {
        let current_slot = self.beacon_client.current_slot();
        self.ensure_fee_recipient_allowed_for_slot(fee_recipient, current_slot).await
    }

    /// Check fee recipient against a specific slot's sequencing ranges.
    pub(super) async fn ensure_fee_recipient_allowed_for_slot(
        &self,
        fee_recipient: Address,
        current_slot: u64,
    ) -> Result<()> {
        let lookahead = if let Some(cached) = self
            .lookahead_status
            .read()
            .await
            .as_ref()
            .filter(|cached| Self::lookahead_slot_covers(current_slot, cached))
            .cloned()
        {
            cached
        } else {
            let fresh = self.compute_lookahead_status().await?;
            *self.lookahead_status.write().await = Some(fresh.clone());
            fresh
        };

        if lookahead.curr_ranges.is_empty() && lookahead.next_ranges.is_empty() {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
                "lookahead metadata missing operator ranges".to_string(),
            ));
        }

        if is_fee_recipient_allowed_for_slot(fee_recipient, current_slot, &lookahead) {
            return Ok(());
        }

        let in_current = slot_matches_range(current_slot, &lookahead.curr_ranges);
        let in_next = slot_matches_range(current_slot, &lookahead.next_ranges);
        let reason = match (in_current, in_next) {
            (true, false) => "current",
            (false, true) => "next",
            _ => "current or next",
        };

        Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "fee recipient {fee_recipient} is not allowed as the {reason} operator for slot {current_slot}"
        )))
    }

    /// Check whether the given slot falls within any current or next lookahead range.
    fn lookahead_slot_covers(slot: u64, lookahead: &LookaheadStatus) -> bool {
        slot_matches_range(slot, &lookahead.curr_ranges) ||
            slot_matches_range(slot, &lookahead.next_ranges)
    }

    /// Build best-effort Go-compatible lookahead status using the shared sequencer fetcher.
    ///
    /// Derives the epoch from the contract's `epochStartTimestamp`, ensuring that
    /// slot ranges and operator addresses are consistent even at epoch boundaries.
    async fn compute_lookahead_status(&self) -> Result<LookaheadStatus> {
        let mut fetcher = self.sequencer_fetcher.lock().await;
        let cached =
            fetcher.cached_whitelist_sequencers(Instant::now()).await.inspect_err(|err| {
                warn!(error = %err, "failed to fetch lookahead operator metadata");
            })?;

        if cached.current == Address::ZERO || cached.next == Address::ZERO {
            return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(
                "received zero address while fetching whitelist operators".to_string(),
            ));
        }

        let epoch_start_timestamp =
            fetcher.sequencer_cache.current_epoch_start_timestamp().ok_or_else(|| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(
                    "epoch start timestamp unavailable after whitelist fetch".to_string(),
                )
            })?;

        let current_epoch =
            self.beacon_client.timestamp_to_epoch(epoch_start_timestamp).map_err(|e| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to derive epoch from epoch start timestamp {epoch_start_timestamp}: {e}"
                ))
            })?;
        let slots_per_epoch = self.beacon_client.slots_per_epoch();
        let handover_skip_slots = DEFAULT_HANDOVER_SKIP_SLOTS.min(slots_per_epoch);
        let threshold = slots_per_epoch.saturating_sub(handover_skip_slots);
        let epoch_start = current_epoch.saturating_mul(slots_per_epoch);

        let curr_ranges =
            vec![SlotRange { start: epoch_start, end: epoch_start.saturating_add(threshold) }];
        let next_ranges = vec![SlotRange {
            start: epoch_start.saturating_add(threshold),
            end: epoch_start.saturating_add(slots_per_epoch),
        }];

        Ok(LookaheadStatus {
            curr_operator: cached.current,
            next_operator: cached.next,
            curr_ranges,
            next_ranges,
        })
    }
}

/// Check if a slot is contained by any of the allowed ranges.
pub(super) fn slot_matches_range(slot: u64, ranges: &[SlotRange]) -> bool {
    ranges.iter().any(|range| slot >= range.start && slot < range.end)
}

/// Return true when fee recipient matches any operator for current/next range.
pub(super) fn is_fee_recipient_allowed_for_slot(
    fee_recipient: Address,
    current_slot: u64,
    lookahead: &LookaheadStatus,
) -> bool {
    (fee_recipient == lookahead.curr_operator &&
        slot_matches_range(current_slot, &lookahead.curr_ranges)) ||
        (fee_recipient == lookahead.next_operator &&
            slot_matches_range(current_slot, &lookahead.next_ranges))
}
