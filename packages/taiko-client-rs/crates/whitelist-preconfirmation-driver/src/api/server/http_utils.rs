//! HTTP response helpers, REST status mapping, and body ingestion utilities.

use axum::{
    body::Body,
    http::{StatusCode, header::CONTENT_TYPE},
    response::Response,
};
use http_body_util::{BodyExt, BodyStream};

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
    let bytes = serde_json::to_vec(value)
        .unwrap_or_else(|_| b"{\"error\":\"serialization failed\"}".to_vec());
    Response::builder()
        .status(status)
        .header(CONTENT_TYPE, "application/json")
        .body(Body::from(bytes))
        .expect("valid response")
}

/// Map internal driver errors to REST status codes.
pub(super) fn map_rest_error_status(err: &WhitelistPreconfirmationDriverError) -> StatusCode {
    match err {
        WhitelistPreconfirmationDriverError::InvalidPayload(_) |
        WhitelistPreconfirmationDriverError::Driver(
            driver::DriverError::PreconfIngressNotReady,
        ) |
        WhitelistPreconfirmationDriverError::Driver(driver::DriverError::EngineSyncing(_)) => {
            StatusCode::BAD_REQUEST
        }
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

impl std::fmt::Display for RequestBodyReadError {
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
    B: http_body::Body<Data = bytes::Bytes> + Send + Unpin + 'static,
    B::Data: Send,
    B::Error: Into<axum::BoxError>,
{
    let mut stream = BodyStream::new(body);
    let mut bytes = Vec::new();
    while let Some(frame) = stream.frame().await {
        let data = frame
            .map_err(|err| {
                let err: axum::BoxError = err.into();
                RequestBodyReadError::Read(err.to_string())
            })?
            .into_data()
            .map_err(|_| {
                RequestBodyReadError::Read("unexpected non-data frame in request body".to_string())
            })?;

        if bytes.len().saturating_add(data.len()) > max_bytes {
            return Err(RequestBodyReadError::TooLarge { max_bytes });
        }

        bytes.extend_from_slice(&data);
    }
    Ok(bytes)
}
