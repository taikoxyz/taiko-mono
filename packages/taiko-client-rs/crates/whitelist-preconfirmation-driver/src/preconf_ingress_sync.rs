//! Event sync bootstrap helper for whitelist preconfirmation ingestion.
//!
//! Thin wrapper over the shared [`driver::preconf_ingress_sync`] implementation, binding it to the
//! whitelist driver's [`WhitelistPreconfirmationDriverError`] type.

use driver::preconf_ingress_sync::{self, EventSyncJoinResult, PreconfIngressError};

use crate::{Result as WhitelistResult, error::WhitelistPreconfirmationDriverError};

/// Runs the event syncer specialized for the whitelist driver error type.
pub(crate) type PreconfIngressSync<P> =
    preconf_ingress_sync::PreconfIngressSync<P, WhitelistPreconfirmationDriverError>;

impl PreconfIngressError for WhitelistPreconfirmationDriverError {
    fn event_syncer_exited() -> Self {
        Self::EventSyncerExited
    }

    fn event_syncer_failed(message: String) -> Self {
        Self::EventSyncerFailed(message)
    }
}

/// Convert event syncer task termination into driver errors.
pub(crate) fn map_event_syncer_exit(result: EventSyncJoinResult) -> WhitelistResult<()> {
    preconf_ingress_sync::map_event_syncer_exit(result)
}
