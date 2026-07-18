//! JWT authentication middleware for REST and websocket routes.

use axum::{
    extract::{Request, State},
    http::{Method, header::AUTHORIZATION},
    middleware::Next,
    response::Response,
};
use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode};

use super::{AppState, http::error_response};

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
        // The library layer only verifies the signature; temporal claims are
        // checked by `validate_temporal_claims` with golang-jwt v5 semantics
        // (present-but-malformed rejected, `exp == now` already expired),
        // because jsonwebtoken treats malformed claims as absent and keeps
        // `exp == now` valid. `aud` is not validated: the Go client's echo-jwt
        // defaults only check an audience when one is configured, while
        // jsonwebtoken would reject every token carrying an `aud` claim.
        validation.required_spec_claims.clear();
        validation.validate_exp = false;
        validation.validate_nbf = false;
        validation.validate_aud = false;
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

        let token_data = decode::<serde_json::Value>(token, &self.decoding_key, &self.validation)
            .map_err(|err| format!("invalid bearer token: {err}"))?;
        validate_temporal_claims(&token_data.claims)
    }
}

/// Validate `exp`/`nbf` with the Go client's golang-jwt v5 semantics: claims are
/// optional, but a present claim must be a numeric date, a token is expired once
/// `now >= exp`, and not yet valid while `now < nbf` (no leeway).
fn validate_temporal_claims(claims: &serde_json::Value) -> std::result::Result<(), String> {
    // Backstop only: jsonwebtoken's own claim parsing already rejects
    // non-object payloads today. Kept so a library change cannot silently turn
    // the temporal checks below into no-ops (Go's MapClaims also rejects).
    if !claims.is_object() {
        return Err("token claims must be a JSON object".to_string());
    }

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|err| format!("system clock before unix epoch: {err}"))?
        .as_secs_f64();

    if let Some(exp) = numeric_date_claim(claims, "exp")? &&
        now >= exp
    {
        return Err("token has expired".to_string());
    }
    if let Some(nbf) = numeric_date_claim(claims, "nbf")? &&
        now < nbf
    {
        return Err("token is not valid yet".to_string());
    }
    Ok(())
}

/// Read an optional numeric-date claim, rejecting present-but-non-numeric values.
///
/// A numeric value of zero is treated as an absent claim: golang-jwt v5's
/// `MapClaims.parseNumericDate` returns nil for a zero float64 (a holdover
/// from v4's struct zero-value semantics), so the Go client accepts `exp: 0`.
/// `-0.0 == 0.0` on both sides, so negative zero follows the same rule.
fn numeric_date_claim(
    claims: &serde_json::Value,
    name: &str,
) -> std::result::Result<Option<f64>, String> {
    match claims.get(name) {
        None => Ok(None),
        Some(value) => {
            let seconds =
                value.as_f64().ok_or_else(|| format!("claim {name} must be a numeric date"))?;
            Ok((seconds != 0.0).then_some(seconds))
        }
    }
}

/// Validate request JWT credentials when a secret is configured.
pub(super) async fn auth_middleware(
    State(state): State<AppState>,
    request: Request,
    next: Next,
) -> Response {
    if request.method() == Method::OPTIONS {
        return next.run(request).await;
    }

    if let Some(jwt_auth) = state.jwt_auth.as_ref() &&
        let Err(err) = jwt_auth.validate_headers(request.headers())
    {
        return error_response(http::StatusCode::UNAUTHORIZED, err);
    }

    next.run(request).await
}
