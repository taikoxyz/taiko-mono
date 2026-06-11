//! Preconfirmation ingress sync helper for the runner.
//!
//! Thin wrapper over the shared [`driver::preconf_ingress_sync`] implementation, binding it to the
//! runner's [`RunnerError`] type.

use driver::preconf_ingress_sync::{self, EventSyncJoinResult, PreconfIngressError};

use super::RunnerError;

/// Runs the preconfirmation ingress event syncer specialized for the runner error type.
pub(crate) type PreconfIngressSync<P> = preconf_ingress_sync::PreconfIngressSync<P, RunnerError>;

impl PreconfIngressError for RunnerError {
    fn event_syncer_exited() -> Self {
        Self::EventSyncerExited
    }

    fn event_syncer_failed(message: String) -> Self {
        Self::EventSyncerFailed(message)
    }
}

/// Convert event syncer task termination into runner-facing readiness errors.
pub(super) fn map_event_syncer_exit_result(result: EventSyncJoinResult) -> Result<(), RunnerError> {
    preconf_ingress_sync::map_event_syncer_exit(result)
}
