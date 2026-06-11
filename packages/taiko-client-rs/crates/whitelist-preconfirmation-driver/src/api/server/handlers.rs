//! HTTP and websocket route handlers.

use std::time::Instant;

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
use crate::{api::types::BuildPreconfBlockRequest, metrics::WhitelistPreconfirmationDriverMetrics};

/// Health endpoint handler.
pub(super) async fn handle_root() -> Response {
    no_content_response(http::StatusCode::OK)
}

/// Status endpoint handler returning importer/runtime health.
pub(super) async fn handle_status(State(state): State<AppState>) -> Result<Response, ApiHttpError> {
    let started_at = Instant::now();
    let result = async {
        let status = state.api.get_status().await?;
        Ok(json_response(http::StatusCode::OK, &status))
    }
    .await;

    WhitelistPreconfirmationDriverMetrics::record_rpc(
        "status",
        result.is_err(),
        started_at.elapsed().as_secs_f64(),
    );
    result
}

/// `preconfBlocks` REST endpoint handler.
pub(super) async fn handle_preconf_blocks(
    State(state): State<AppState>,
    request: Request,
) -> Result<Response, ApiHttpError> {
    let started_at = Instant::now();
    let result = async {
        if !state.api.is_sync_ready() {
            return Err(ApiHttpError::BadRequest(
                "event sync is not ready to serve preconfBlocks".to_string(),
            ));
        }

        let body = read_request_body(request.into_body(), PRECONF_BLOCKS_BODY_LIMIT_BYTES).await?;
        let build_request: BuildPreconfBlockRequest = serde_json::from_slice(&body)?;

        let response = state.api.build_preconf_block(build_request).await?;
        Ok(json_response(http::StatusCode::OK, &response))
    }
    .await;

    WhitelistPreconfirmationDriverMetrics::record_rpc(
        "preconfBlocks",
        result.is_err(),
        started_at.elapsed().as_secs_f64(),
    );
    result
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
