//! Shared JSON-RPC method definitions for driver preconfirmation interface.

/// Driver JSON-RPC method names used by both server and client.
#[derive(Debug, Clone, Copy)]
pub enum DriverRpcMethod {
    /// Submit a preconfirmation payload for injection.
    SubmitPreconfirmationPayload,
    /// Query the last canonical proposal id processed by the driver.
    LastCanonicalProposalId,
}

impl DriverRpcMethod {
    /// Return the JSON-RPC method name.
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::SubmitPreconfirmationPayload => "preconf_submitPreconfirmationPayload",
            Self::LastCanonicalProposalId => "preconf_lastCanonicalProposalId",
        }
    }
}
