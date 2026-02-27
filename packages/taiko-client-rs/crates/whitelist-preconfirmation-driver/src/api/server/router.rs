//! Router and CORS-layer construction for the REST/WS server.

use axum::{
    Router,
    http::{
        Method,
        header::{AUTHORIZATION, CONTENT_TYPE},
    },
    middleware,
    routing::{get, post},
};
use tower_http::cors::{Any, CorsLayer};

use super::{
    auth::auth_middleware,
    handlers::{
        handle_not_found, handle_preconf_blocks, handle_root, handle_status,
        handle_websocket_upgrade,
    },
    state::AppState,
};

/// Construct the server router with optional HTTP and WebSocket route groups.
pub(super) fn build_router(
    state: AppState,
    cors_origins: &[String],
    enable_http: bool,
    enable_ws: bool,
) -> Router {
    let cors_layer = build_cors_layer(cors_origins);
    let mut router = Router::new();

    if enable_http {
        router = router
            .route("/", get(handle_root))
            .route("/healthz", get(handle_root))
            .route("/status", get(handle_status))
            .route("/preconfBlocks", post(handle_preconf_blocks));
    }

    if enable_ws {
        router = router.route("/ws", get(handle_websocket_upgrade));
    }

    router = router
        .fallback(handle_not_found)
        .layer(middleware::from_fn_with_state(state.clone(), auth_middleware));
    router.layer(cors_layer).with_state(state)
}

/// Build CORS middleware from configured allowed origins.
fn build_cors_layer(cors_origins: &[String]) -> CorsLayer {
    let has_wildcard_origin = cors_origins.iter().any(|origin| origin == "*");
    let allows_credentials = !has_wildcard_origin;
    let allowed_methods = [Method::GET, Method::POST, Method::OPTIONS];
    let allowed_headers = [AUTHORIZATION, CONTENT_TYPE];

    if has_wildcard_origin {
        return CorsLayer::new()
            .allow_origin(Any)
            .allow_credentials(false)
            .allow_methods(allowed_methods)
            .allow_headers(allowed_headers);
    }

    let parsed_origins = cors_origins
        .iter()
        .filter_map(|origin| origin.parse::<http::HeaderValue>().ok())
        .collect::<Vec<_>>();

    CorsLayer::new()
        .allow_origin(parsed_origins)
        .allow_credentials(allows_credentials)
        .allow_methods(allowed_methods)
        .allow_headers(allowed_headers)
}
