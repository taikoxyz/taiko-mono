//! HTTP and websocket route handlers.

use axum::{
    extract::{Request, State, ws::WebSocketUpgrade},
    response::{IntoResponse, Response},
};

use super::{
    PRECONF_BLOCKS_BODY_LIMIT_BYTES,
    http_utils::{
        RequestBodyReadError, error_response, json_response, map_rest_error_status,
        no_content_response, read_request_body,
    },
    state::AppState,
    websocket::serve_websocket_notifications,
};
use crate::rest::types::{BuildPreconfBlockRestRequest, RestStatus};

/// REST response payload for successful `/preconfBlocks` requests.
#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct BuildPreconfBlockRestResponse {
    /// Built block header returned by the API.
    block_header: alloy_rpc_types::Header,
}

/// Convert an internal REST API error into a serialized HTTP response.
fn rest_api_error(err: crate::error::WhitelistPreconfirmationDriverError) -> Response {
    error_response(map_rest_error_status(&err), err.to_string())
}

/// Health endpoint handler.
pub(super) async fn handle_root() -> Response {
    no_content_response(http::StatusCode::OK)
}

/// Status endpoint handler returning importer/runtime health.
pub(super) async fn handle_status(State(state): State<AppState>) -> Response {
    match state.api.get_status().await {
        Ok(status) => {
            let response = RestStatus {
                highest_unsafe_l2_payload_block_id: status.highest_unsafe_l2_payload_block_id,
                end_of_sequencing_block_hash: status
                    .end_of_sequencing_block_hash
                    .unwrap_or_else(|| alloy_primitives::B256::ZERO.to_string()),
            };
            json_response(http::StatusCode::OK, &response)
        }
        Err(err) => rest_api_error(err),
    }
}

/// `preconfBlocks` REST endpoint handler.
pub(super) async fn handle_preconf_blocks(
    State(state): State<AppState>,
    request: Request,
) -> Response {
    let status = match state.api.get_status().await {
        Ok(status) => status,
        Err(err) => return rest_api_error(err),
    };

    if !status.sync_ready {
        return error_response(
            http::StatusCode::BAD_REQUEST,
            "event sync is not ready to serve preconfBlocks".to_string(),
        );
    }

    let body = match read_request_body(request.into_body(), PRECONF_BLOCKS_BODY_LIMIT_BYTES).await {
        Ok(body) => body,
        Err(RequestBodyReadError::TooLarge { max_bytes }) => {
            return error_response(
                http::StatusCode::PAYLOAD_TOO_LARGE,
                format!("request body exceeds maximum of {max_bytes} bytes"),
            );
        }
        Err(err) => {
            return error_response(
                http::StatusCode::UNPROCESSABLE_ENTITY,
                format!("failed to read request body: {err}"),
            );
        }
    };

    let rest_request: BuildPreconfBlockRestRequest = match serde_json::from_slice(&body) {
        Ok(value) => value,
        Err(err) => {
            return error_response(
                http::StatusCode::UNPROCESSABLE_ENTITY,
                format!("failed to parse request body: {err}"),
            );
        }
    };

    let request = match rest_request.into_rpc_request() {
        Ok(request) => request,
        Err(err) => return error_response(http::StatusCode::BAD_REQUEST, err),
    };

    match state.api.build_preconf_block(request).await {
        Ok(response) => json_response(
            http::StatusCode::OK,
            &BuildPreconfBlockRestResponse { block_header: response.block_header },
        ),
        Err(err) => rest_api_error(err),
    }
}

/// Upgrade a request to a websocket stream for EOS notifications.
/// Returns `400 Bad Request` when websocket upgrade headers are not present.
pub(super) async fn handle_websocket_upgrade(
    State(state): State<AppState>,
    websocket_upgrade: std::result::Result<
        WebSocketUpgrade,
        axum::extract::ws::rejection::WebSocketUpgradeRejection,
    >,
) -> Response {
    let Ok(websocket_upgrade) = websocket_upgrade else {
        return error_response(
            http::StatusCode::BAD_REQUEST,
            "websocket upgrade headers are required".to_string(),
        );
    };

    let notifications = state.api.subscribe_end_of_sequencing();
    websocket_upgrade
        .on_upgrade(move |socket| async move {
            serve_websocket_notifications(socket, notifications).await;
        })
        .into_response()
}

/// Return 404 for unknown routes.
pub(super) async fn handle_not_found() -> Response {
    error_response(http::StatusCode::NOT_FOUND, "route not found".to_string())
}
