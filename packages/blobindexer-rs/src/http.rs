use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
};
use chrono::Utc;
use serde::Serialize;
use tokio::net::TcpListener;
use tokio_util::sync::CancellationToken;
use tower_http::trace::TraceLayer;

use crate::{
    beacon::BeaconClient,
    config::Config,
    errors::BlobIndexerError,
    models::{BlobRecord, BlockRecord},
    storage::Storage,
    utils::conversions::{decode_b256, encode_b256, encode_hex_bytes},
};

pub async fn serve(
    config: Config,
    storage: Storage,
    beacon: BeaconClient,
    shutdown: CancellationToken,
) -> crate::errors::Result<()> {
    let app = build_router().with_state(AppState { storage, beacon });
    let listener = TcpListener::bind(config.http_bind).await?;

    tracing::info!(address = %config.http_bind, "starting HTTP server");

    axum::serve(listener, app)
        .with_graceful_shutdown(async move {
            shutdown.cancelled().await;
        })
        .await?;

    Ok(())
}

fn build_router() -> Router<AppState> {
    Router::new()
        .route("/healthz", get(health))
        .route("/v1/status", get(status))
        .route("/v1/status/head", get(get_head_status))
        .route("/v1/blobs/:versioned_hash", get(get_blob_by_hash))
        .route("/v1/blobs/by-slot/:slot", get(list_blobs_by_slot))
        .route("/v1/blobs/by-root/:block_root", get(list_blobs_by_root))
        .layer(TraceLayer::new_for_http())
}

#[derive(Clone)]
struct AppState {
    storage: Storage,
    beacon: BeaconClient,
}

#[derive(Debug)]
struct ApiError {
    status: StatusCode,
    message: String,
}

impl ApiError {
    fn new(status: StatusCode, message: impl Into<String>) -> Self {
        Self {
            status,
            message: message.into(),
        }
    }

    fn bad_request(message: impl Into<String>) -> Self {
        Self::new(StatusCode::BAD_REQUEST, message)
    }

    fn not_found(message: impl Into<String>) -> Self {
        Self::new(StatusCode::NOT_FOUND, message)
    }

    fn internal(message: impl Into<String>) -> Self {
        Self::new(StatusCode::INTERNAL_SERVER_ERROR, message)
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let body = Json(ErrorBody {
            message: self.message.clone(),
        });
        (self.status, body).into_response()
    }
}

impl From<BlobIndexerError> for ApiError {
    fn from(value: BlobIndexerError) -> Self {
        match value {
            BlobIndexerError::InvalidData(msg) => ApiError::bad_request(msg),
            other => {
                tracing::error!(error = ?other, "internal server error");
                ApiError::internal("internal server error")
            }
        }
    }
}

#[derive(Serialize)]
struct ErrorBody {
    message: String,
}

type RestResult<T> = std::result::Result<T, ApiError>;

async fn health() -> &'static str {
    "ok"
}

async fn status(State(state): State<AppState>) -> RestResult<Json<StatusResponse>> {
    let sync_status = state
        .beacon
        .get_sync_status()
        .await
        .map_err(ApiError::from)?;

    let finalized_slot = state
        .beacon
        .get_finalized_slot()
        .await
        .map_err(ApiError::from)?;

    let last_processed = state
        .storage
        .get_last_processed_slot()
        .await
        .map_err(ApiError::from)?
        .map(|slot| u64::try_from(slot).map_err(|_| ApiError::internal("negative slot stored")))
        .transpose()?;

    let beacon_synced =
        !sync_status.is_syncing && sync_status.sync_distance == 0 && !sync_status.el_offline;

    let response = StatusResponse {
        beacon_synced,
        beacon: BeaconStatus {
            head_slot: sync_status.head_slot,
            finalized_slot,
            sync_distance: sync_status.sync_distance,
            is_syncing: sync_status.is_syncing,
            is_optimistic: sync_status.is_optimistic,
            el_offline: sync_status.el_offline,
        },
        last_processed_slot: last_processed,
    };

    Ok(Json(response))
}

async fn get_head_status(State(state): State<AppState>) -> RestResult<Json<HeadStatusResponse>> {
    let Some(block) = state
        .storage
        .get_canonical_head()
        .await
        .map_err(ApiError::from)?
    else {
        return Err(ApiError::not_found("no canonical head available"));
    };

    let response = HeadStatusResponse::try_from(block)?;
    Ok(Json(response))
}

async fn get_blob_by_hash(
    State(state): State<AppState>,
    Path(versioned_hash): Path<String>,
) -> RestResult<Json<BlobServerResponse>> {
    let hash =
        decode_b256(&versioned_hash).map_err(|err| ApiError::bad_request(err.to_string()))?;
    let blob = state
        .storage
        .get_blob_by_versioned_hash(&hash)
        .await
        .map_err(ApiError::from)?
        .ok_or_else(|| ApiError::not_found("blob not found"))?;

    let response = BlobServerResponse::try_from(blob)?;
    Ok(Json(response))
}

async fn list_blobs_by_slot(
    State(state): State<AppState>,
    Path(slot): Path<u64>,
) -> RestResult<Json<Vec<BlobServerResponse>>> {
    let slot_i64 = i64::try_from(slot).map_err(|_| ApiError::bad_request("slot out of range"))?;

    let blobs = state
        .storage
        .get_blobs_by_slot(slot_i64)
        .await
        .map_err(ApiError::from)?;

    let responses = blobs
        .into_iter()
        .map(BlobServerResponse::try_from)
        .collect::<std::result::Result<Vec<_>, ApiError>>()?;

    Ok(Json(responses))
}

async fn list_blobs_by_root(
    State(state): State<AppState>,
    Path(block_root): Path<String>,
) -> RestResult<Json<Vec<BlobServerResponse>>> {
    let root = decode_b256(&block_root).map_err(|err| ApiError::bad_request(err.to_string()))?;

    let _block = state
        .storage
        .get_block_by_root(state.storage.pool(), &root)
        .await
        .map_err(ApiError::from)?
        .filter(|b| b.canonical)
        .ok_or_else(|| ApiError::not_found("canonical block not found"))?;

    let blobs = state
        .storage
        .get_blobs_by_block_root(&root)
        .await
        .map_err(ApiError::from)?;

    let responses = blobs
        .into_iter()
        .map(BlobServerResponse::try_from)
        .collect::<std::result::Result<Vec<_>, ApiError>>()?;

    Ok(Json(responses))
}

#[derive(Serialize)]
struct HeadStatusResponse {
    slot: u64,
    block_root: String,
    parent_root: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    timestamp: Option<chrono::DateTime<Utc>>,
}

impl TryFrom<BlockRecord> for HeadStatusResponse {
    type Error = ApiError;

    fn try_from(value: BlockRecord) -> RestResult<Self> {
        let slot =
            u64::try_from(value.slot).map_err(|_| ApiError::internal("negative slot stored"))?;
        Ok(Self {
            slot,
            block_root: encode_b256(&value.block_root),
            parent_root: encode_b256(&value.parent_root),
            timestamp: value.timestamp,
        })
    }
}

#[derive(Serialize)]
struct BlobServerResponse {
    commitment: String,
    data: String,
    #[serde(rename = "versionedHash")]
    versioned_hash: String,
}

#[derive(Serialize)]
struct StatusResponse {
    #[serde(rename = "beaconSynced")]
    beacon_synced: bool,
    beacon: BeaconStatus,
    #[serde(rename = "lastProcessedSlot", skip_serializing_if = "Option::is_none")]
    last_processed_slot: Option<u64>,
}

#[derive(Serialize)]
struct BeaconStatus {
    #[serde(rename = "headSlot")]
    head_slot: u64,
    #[serde(rename = "finalizedSlot", skip_serializing_if = "Option::is_none")]
    finalized_slot: Option<u64>,
    #[serde(rename = "syncDistance")]
    sync_distance: u64,
    #[serde(rename = "isSyncing")]
    is_syncing: bool,
    #[serde(rename = "isOptimistic")]
    is_optimistic: bool,
    #[serde(rename = "elOffline")]
    el_offline: bool,
}

impl TryFrom<BlobRecord> for BlobServerResponse {
    type Error = ApiError;

    fn try_from(value: BlobRecord) -> RestResult<Self> {
        Ok(Self {
            versioned_hash: encode_b256(&value.versioned_hash),
            commitment: encode_hex_bytes(value.commitment.as_slice()),
            data: encode_hex_bytes(&value.blob),
        })
    }
}
