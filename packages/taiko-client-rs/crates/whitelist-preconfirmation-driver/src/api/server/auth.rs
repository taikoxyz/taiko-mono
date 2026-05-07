//! JWT authentication middleware for REST and websocket routes.

use axum::{
    extract::{Request, State},
    http::{Method, header::AUTHORIZATION},
    middleware::Next,
    response::Response,
};
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode};

use super::{http_utils::error_response, state::AppState};

/// Optional Bearer JWT validator shared by REST/WS routes.
pub(super) struct JwtAuth {
    /// HMAC secret used to decode and verify JWT signatures.
    decoding_key: DecodingKey,
    /// Validation policy for decoded JWT claims.
    validation: Validation,
}

impl JwtAuth {
    /// Build a validator from a shared secret.
    pub(super) fn new(secret: &[u8]) -> Self {
        let mut validation = Validation::new(Algorithm::HS256);
        // Validate signatures while keeping claims like `exp` optional.
        validation.required_spec_claims.clear();
        validation.validate_exp = false;
        validation.validate_nbf = false;
        Self { decoding_key: DecodingKey::from_secret(secret), validation }
    }

    /// Validate `Authorization: Bearer <jwt>`.
    pub(super) fn validate_headers(
        &self,
        headers: &http::HeaderMap,
    ) -> std::result::Result<(), String> {
        let header = headers
            .get(AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .ok_or_else(|| "missing bearer authorization header".to_string())?;
        let token = header
            .strip_prefix("Bearer ")
            .ok_or_else(|| "authorization header must use bearer token".to_string())?;

        decode::<serde_json::Value>(token, &self.decoding_key, &self.validation)
            .map_err(|err| format!("invalid bearer token: {err}"))?;
        Ok(())
    }
}

/// Return whether this unauthenticated probe route should bypass JWT checks.
fn is_public_probe_route(method: &Method, path: &str) -> bool {
    *method == Method::GET && matches!(path, "/" | "/healthz" | "/status")
}

/// Validate request JWT credentials when a secret is configured.
pub(super) async fn auth_middleware(
    State(state): State<AppState>,
    request: Request,
    next: Next,
) -> Response {
    if request.method() == Method::OPTIONS ||
        is_public_probe_route(request.method(), request.uri().path())
    {
        return next.run(request).await;
    }

    if let Some(jwt_auth) = state.jwt_auth.as_ref() &&
        let Err(err) = jwt_auth.validate_headers(request.headers())
    {
        return error_response(http::StatusCode::UNAUTHORIZED, err);
    }

    next.run(request).await
}

#[cfg(test)]
mod tests {
    use axum::http::Method;

    use super::is_public_probe_route;

    #[test]
    fn public_probe_route_only_allows_get_probe_paths() {
        for path in ["/", "/healthz", "/status"] {
            assert!(is_public_probe_route(&Method::GET, path));
        }

        assert!(!is_public_probe_route(&Method::POST, "/status"));
        assert!(!is_public_probe_route(&Method::GET, "/preconfBlocks"));
        assert!(!is_public_probe_route(&Method::GET, "/ws"));
    }
}
