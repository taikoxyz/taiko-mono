//! Offline dependencies for unit tests that build the REST service or the importer.

use std::{path::PathBuf, sync::Arc, time::Duration};

use alloy_primitives::Address;
use axum::{Json, Router, routing::get};
use bindings::{anchor::Anchor::AnchorInstance, inbox::Inbox::InboxInstance};
use driver::{DriverConfig, EventSyncer};
use reqwest::Url;
use rpc::{
    SubscriptionSource,
    beacon::BeaconClient,
    client::{Client, ClientConfig, ShastaProtocolInstance, connect_http_with_timeout},
};
use serde_json::json;
use tokio::{net::TcpListener, task::JoinHandle};

/// Dependencies of the REST service and the importer that never reach a live node: an RPC client
/// whose endpoints refuse connections, an event syncer over it, and a beacon client over a local
/// stub beacon node.
pub(crate) struct OfflineDeps {
    /// RPC client whose every request fails fast with a refused connection.
    pub(crate) rpc: Client,
    /// Event syncer over [`Self::rpc`].
    pub(crate) event_syncer: Arc<EventSyncer>,
    /// Beacon client over the stub beacon node.
    pub(crate) beacon_client: Arc<BeaconClient>,
    /// Stub beacon node task, stopped on drop.
    beacon: JoinHandle<()>,
}

impl OfflineDeps {
    /// Build the dependencies for `chain_id`, binding the anchor contract to `anchor_address`.
    pub(crate) async fn new(chain_id: u64, anchor_address: Address) -> Self {
        let (beacon_url, beacon) = start_beacon_stub().await;
        // Nothing listens on port 1, so any RPC the code under test sends fails at once.
        let refused = Url::parse("http://127.0.0.1:1").expect("valid URL");

        let l1_provider = SubscriptionSource::Http(refused.clone())
            .to_provider()
            .await
            .expect("an HTTP provider builds without connecting");
        let l2_provider = connect_http_with_timeout(refused.clone());
        let l2_auth_provider = connect_http_with_timeout(refused.clone());
        let shasta = ShastaProtocolInstance {
            inbox: InboxInstance::new(Address::ZERO, l1_provider.clone()),
            anchor: AnchorInstance::new(anchor_address, l2_auth_provider.clone()),
        };
        let rpc = Client { chain_id, l1_provider, l2_provider, l2_auth_provider, shasta };

        let client_config = ClientConfig {
            l1_provider_source: SubscriptionSource::Http(refused.clone()),
            l2_provider_url: refused.clone(),
            l2_auth_provider_url: refused,
            jwt_secret: PathBuf::from("/dev/null"),
            inbox_address: Address::ZERO,
        };
        let driver_config = DriverConfig::new(
            client_config,
            Duration::from_secs(1),
            beacon_url.clone(),
            None,
            None,
            true,
        );
        let event_syncer = Arc::new(
            EventSyncer::new(&driver_config, rpc.clone()).await.expect("the event syncer builds"),
        );
        let beacon_client =
            Arc::new(BeaconClient::new(beacon_url).await.expect("the beacon client builds"));

        Self { rpc, event_syncer, beacon_client, beacon }
    }
}

impl Drop for OfflineDeps {
    /// Stop the stub beacon node.
    fn drop(&mut self) {
        self.beacon.abort();
    }
}

/// Serve the genesis and spec endpoints a beacon client reads at construction (genesis at 0,
/// 12-second slots, 32-slot epochs) on an ephemeral local port.
async fn start_beacon_stub() -> (Url, JoinHandle<()>) {
    let app = Router::new()
        .route(
            "/eth/v1/beacon/genesis",
            get(|| async { Json(json!({ "data": { "genesis_time": "0" } })) }),
        )
        .route(
            "/eth/v1/config/spec",
            get(|| async {
                Json(json!({ "data": { "SECONDS_PER_SLOT": "12", "SLOTS_PER_EPOCH": "32" } }))
            }),
        );
    let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind an ephemeral port");
    let url = Url::parse(&format!("http://{}", listener.local_addr().expect("local address")))
        .expect("valid URL");
    let server = tokio::spawn(async move {
        axum::serve(listener, app).await.expect("the stub beacon node serves");
    });
    (url, server)
}
