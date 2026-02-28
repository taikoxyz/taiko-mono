//! Typed HTTP error boundary for REST handlers.

use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
};
use thiserror::Error;
use tracing::{error, warn};

use super::http_utils::{RequestBodyReadError, error_response, map_rest_error_status};
use crate::error::WhitelistPreconfirmationDriverError;

/// Error type returned by REST handlers and converted into JSON HTTP responses.
#[derive(Debug, Error)]
pub(super) enum ApiHttpError {
    /// Driver/service-layer failure propagated from the API implementation.
    #[error(transparent)]
    Driver(#[from] WhitelistPreconfirmationDriverError),
    /// Request-body read failure before JSON parsing.
    #[error("failed to read request body: {0}")]
    ReadBody(RequestBodyReadError),
    /// JSON body parse failure.
    #[error("failed to parse request body: {0}")]
    ParseBody(#[from] serde_json::Error),
    /// Explicit client error response with caller-provided message.
    #[error("{0}")]
    BadRequest(String),
}

impl ApiHttpError {
    /// Resolve the HTTP status code for this API error.
    fn status_code(&self) -> StatusCode {
        match self {
            Self::Driver(err) => map_rest_error_status(err),
            Self::ReadBody(RequestBodyReadError::TooLarge { .. }) => StatusCode::PAYLOAD_TOO_LARGE,
            Self::ReadBody(_) | Self::ParseBody(_) => StatusCode::UNPROCESSABLE_ENTITY,
            Self::BadRequest(_) => StatusCode::BAD_REQUEST,
        }
    }

    /// Resolve the external error message returned in the JSON response body.
    fn response_message(&self) -> String {
        match self {
            Self::Driver(err) => err.to_string(),
            Self::ReadBody(RequestBodyReadError::TooLarge { max_bytes }) => {
                format!("request body exceeds maximum of {max_bytes} bytes")
            }
            Self::ReadBody(err) => format!("failed to read request body: {err}"),
            Self::ParseBody(err) => format!("failed to parse request body: {err}"),
            Self::BadRequest(message) => message.clone(),
        }
    }
}

impl From<RequestBodyReadError> for ApiHttpError {
    /// Convert a request-body ingestion failure into an API HTTP boundary error.
    fn from(value: RequestBodyReadError) -> Self {
        Self::ReadBody(value)
    }
}

impl IntoResponse for ApiHttpError {
    /// Convert the typed API error into a JSON HTTP response and emit one boundary log line.
    fn into_response(self) -> Response {
        let status = self.status_code();
        let message = self.response_message();

        if status.is_server_error() {
            error!(%status, error = %self, "whitelist API request failed");
        } else {
            warn!(%status, error = %self, "whitelist API request rejected");
        }

        error_response(status, message)
    }
}
