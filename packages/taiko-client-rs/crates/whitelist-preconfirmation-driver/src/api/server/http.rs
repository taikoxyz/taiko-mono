//! HTTP response helpers, body ingestion, and the typed error boundary for REST handlers.

use std::fmt::Display;

use axum::{
    Json,
    body::Body,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use http_body_util::{BodyExt, LengthLimitError, Limited};
use thiserror::Error;
use tracing::{error, warn};

use crate::error::WhitelistPreconfirmationDriverError;

/// Build an empty response with the requested status code.
pub(super) fn no_content_response(status: StatusCode) -> Response {
    Response::builder().status(status).body(Body::empty()).expect("valid response")
}

/// Build an error response with JSON body containing an `error` field.
pub(super) fn error_response(status: StatusCode, message: String) -> Response {
    #[derive(serde::Serialize)]
    struct ErrorBody {
        /// Error message returned to the caller.
        error: String,
    }
    json_response(status, &ErrorBody { error: message })
}

/// Build a JSON response from a serializable payload.
pub(super) fn json_response<T: serde::Serialize>(status: StatusCode, value: &T) -> Response {
    (status, Json(value)).into_response()
}

/// Map internal driver errors to REST status codes.
fn map_rest_error_status(err: &WhitelistPreconfirmationDriverError) -> StatusCode {
    match err {
        WhitelistPreconfirmationDriverError::InvalidPayload(_) |
        WhitelistPreconfirmationDriverError::Driver(
            driver::DriverError::PreconfIngressNotReady,
        ) |
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::EngineSyncing(_)) => {
            StatusCode::BAD_REQUEST
        }
        // The Go preconfirmation server maps block-insertion failures to 500. Keep parent
        // mismatches and other production-path failures in this catch-all for REST parity.
        _ => StatusCode::INTERNAL_SERVER_ERROR,
    }
}

/// Error states for request body ingestion from Axum.
#[derive(Debug)]
pub(super) enum RequestBodyReadError {
    /// Failed to read a body frame.
    Read(String),
    /// Body exceeded configured size limit.
    TooLarge {
        /// Maximum accepted body size in bytes.
        max_bytes: usize,
    },
}

impl Display for RequestBodyReadError {
    /// Render a human-readable error used in HTTP responses and logs.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Read(reason) => write!(f, "{reason}"),
            Self::TooLarge { max_bytes } => {
                write!(f, "payload exceeds configured body limit of {max_bytes} bytes")
            }
        }
    }
}

/// Read the full request body into memory while enforcing a maximum payload size.
pub(super) async fn read_request_body<B>(
    body: B,
    max_bytes: usize,
) -> std::result::Result<Vec<u8>, RequestBodyReadError>
where
    B: http_body::Body + Send + 'static,
    B::Data: Send,
    B::Error: Into<axum::BoxError>,
{
    match Limited::new(body, max_bytes).collect().await {
        Ok(collected) => Ok(collected.to_bytes().to_vec()),
        Err(err) if err.is::<LengthLimitError>() => {
            Err(RequestBodyReadError::TooLarge { max_bytes })
        }
        Err(err) => Err(RequestBodyReadError::Read(err.to_string())),
    }
}

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
