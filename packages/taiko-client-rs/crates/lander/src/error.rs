//! Shared retry-versus-stop error classification.

/// A lander result, retaining operational context in errors.
pub type Result<T> = std::result::Result<T, LanderError>;

/// Why preparation or submission cannot proceed.
#[derive(Debug, thiserror::Error)]
pub enum LanderError {
    /// Invalid operator configuration, schema, or contract identity.
    #[error("invalid lander configuration: {0}")]
    Configuration(String),
    /// Invalid source data or an authenticated-chain contradiction.
    #[error("lander safety check failed: {0}")]
    Safety(String),
    /// History is absent or pruned at the specified height or epoch.
    #[error("unavailable lander history: {0}")]
    Unavailable(String),
    /// A temporary endpoint or finality condition; safe to retry.
    #[error("temporary lander failure: {0}")]
    Temporary(String),
    /// Data cannot be represented within the explicit configured limits.
    #[error("lander capacity exceeded: {0}")]
    Capacity(String),
    /// Encoded batch or journal bytes are malformed or noncanonical.
    #[error("invalid lander encoding: {0}")]
    Encoding(String),
    /// A newer on-chain checkpoint made unbroadcast work obsolete.
    #[error("landing job became stale: {0}")]
    Stale(String),
    /// A transaction reverted without competing progress.
    #[error("landing transaction reverted: {0}")]
    Reverted(String),
    /// Durable state could not be read, written, or exclusively locked.
    #[error("lander journal failure: {0}")]
    Journal(String),
}

impl LanderError {
    /// Whether the runner may retry this condition with bounded backoff.
    pub const fn is_retryable(&self) -> bool {
        matches!(self, Self::Temporary(_) | Self::Unavailable(_) | Self::Stale(_))
    }
}

/// Render only stable RPC failure categories and numeric codes; transport errors and response
/// bodies can contain the configured endpoint's credentials, path tokens, or echoed request data.
pub(crate) fn sanitized_rpc_error(
    operation: &'static str,
    error: alloy::transports::TransportError,
) -> LanderError {
    use alloy::transports::{RpcError, TransportErrorKind};
    let reason = match error {
        RpcError::ErrorResp(payload) => format!("RPC error code {}", payload.code),
        RpcError::NullResp => "unexpected null response".into(),
        RpcError::UnsupportedFeature(_) => "unsupported RPC feature".into(),
        RpcError::LocalUsageError(_) => "local RPC usage failure".into(),
        RpcError::SerError(_) => "RPC request encoding failure".into(),
        RpcError::DeserError { .. } => "RPC response decoding failure".into(),
        RpcError::Transport(TransportErrorKind::HttpError(error)) => {
            format!("HTTP status {}", error.status)
        }
        RpcError::Transport(_) => "RPC transport failure".into(),
    };
    LanderError::Temporary(format!("{operation}: {reason}"))
}

/// Retains stable Engine failure categories, methods and RPC codes without exposing endpoint
/// credentials or arbitrary upstream messages. Generic failures do not establish state pruning.
pub fn engine_diagnostic(error: &abci::EngineError) -> String {
    use abci::EngineError;
    match error {
        EngineError::ErrorReply { call, code, .. } => {
            let method = [
                "engine_forkchoiceUpdatedV3",
                "engine_getPayloadV5",
                "engine_newPayloadV4",
                "engine_exchangeCapabilities",
                "eth_getBlockByNumber",
                "eth_getBlockByHash",
                "taiko_txPoolContentWithMinTip",
            ]
            .into_iter()
            .find(|method| call.starts_with(method))
            .unwrap_or("Engine RPC");
            format!("{method} error code {code}")
        }
        EngineError::Transport(_) => "Engine transport failure".into(),
        EngineError::BadReply(_) => "malformed or missing Engine reply".into(),
        EngineError::Setup(_) => "Engine/JWT configuration failure".into(),
        EngineError::BuildNotStarted(description) => {
            let status = ["SYNCING", "ACCEPTED", "INVALID"]
                .into_iter()
                .find(|status| description.contains(status));
            match status {
                Some(status) => format!("payload build not started: {status}"),
                None => "payload build not started or payload id missing".into(),
            }
        }
        EngineError::BlockHashMismatch { .. } |
        EngineError::Withdrawals(_) |
        EngineError::BlobGas { .. } |
        EngineError::BaseFeeOverflow(_) |
        EngineError::DifficultyOverflow(_) |
        EngineError::NotEtnaShaped(_) |
        EngineError::HeaderHashMismatch { .. } |
        EngineError::HeaderNumberMismatch { .. } => error.to_string(),
    }
}
