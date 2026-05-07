//! HTTP and websocket route handlers.

use axum::{
    extract::{Request, State, ws::WebSocketUpgrade},
    response::{IntoResponse, Response},
};

use super::{
    PRECONF_BLOCKS_BODY_LIMIT_BYTES,
    http_error::ApiHttpError,
    http_utils::{error_response, json_response, no_content_response, read_request_body},
    state::AppState,
    websocket::serve_websocket_notifications,
};
use crate::api::types::{ApiStatus, BuildPreconfBlockApiRequest};

/// REST response payload for successful `/preconfBlocks` requests.
#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct BuildPreconfBlockRestResponse {
    /// Built block header returned by the API.
    block_header: alloy_rpc_types::Header,
}

/// Health endpoint handler.
pub(super) async fn handle_root() -> Response {
    no_content_response(http::StatusCode::OK)
}

/// Status endpoint handler returning importer/runtime health.
pub(super) async fn handle_status(State(state): State<AppState>) -> Result<Response, ApiHttpError> {
    let status = state.api.get_status().await?;
    let response = ApiStatus {
        highest_unsafe_l2_payload_block_id: status.highest_unsafe_l2_payload_block_id,
        end_of_sequencing_block_hash: status
            .end_of_sequencing_block_hash
            .unwrap_or_else(|| alloy_primitives::B256::ZERO.to_string()),
        can_shutdown: status.can_shutdown,
    };
    Ok(json_response(http::StatusCode::OK, &response))
}

/// `preconfBlocks` REST endpoint handler.
pub(super) async fn handle_preconf_blocks(
    State(state): State<AppState>,
    request: Request,
) -> Result<Response, ApiHttpError> {
    let status = state.api.get_status().await?;

    if !status.sync_ready {
        return Err(ApiHttpError::BadRequest(
            "event sync is not ready to serve preconfBlocks".to_string(),
        ));
    }

    let body = read_request_body(request.into_body(), PRECONF_BLOCKS_BODY_LIMIT_BYTES).await?;

    let rest_request: BuildPreconfBlockApiRequest = serde_json::from_slice(&body)?;

    let request = rest_request.into_rpc_request().map_err(ApiHttpError::BadRequest)?;

    let response = state.api.build_preconf_block(request).await?;
    Ok(json_response(
        http::StatusCode::OK,
        &BuildPreconfBlockRestResponse { block_header: response.block_header },
    ))
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
