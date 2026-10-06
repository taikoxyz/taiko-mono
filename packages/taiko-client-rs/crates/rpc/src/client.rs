//! RPC client for interacting with L1 and L2 nodes.

use std::{
    fs, io,
    path::{Path, PathBuf},
    time::Duration,
};

use alethia_reth_primitives::{ETNA_EXTRA_DATA_LEN, addresses::get_treasury_address};
use alloy::{rpc::client::RpcClient, transports::http::reqwest::Url};
use alloy_eips::{BlockId, BlockNumberOrTag, eip1898::RpcBlockHash};
use alloy_primitives::{Address, B256};
use alloy_provider::{
    Provider, ProviderBuilder, RootProvider, WsConnect, fillers::FillProvider,
    utils::JoinedRecommendedFillers,
};
use alloy_rpc_types_engine::JwtSecret;
use alloy_transport_http::{AuthLayer, Http, HyperClient};
use bindings::{anchor::Anchor::AnchorInstance, inbox::Inbox::InboxInstance};
use http_body_util::Full;
use hyper::body::Bytes;
use hyper_util::{
    client::legacy::{Client as HyperService, connect::HttpConnector},
    rt::TokioExecutor,
};
use protocol::shasta::{
    etna_fork_timestamp_for_chain, is_etna_at, unzen_active_for_chain_timestamp,
};
use reqwest::Client as ReqwestClient;
use tower::{ServiceBuilder, timeout::TimeoutLayer};
use tracing::info;

use crate::{
    SubscriptionSource,
    error::{Result, RpcClientError},
};

/// L1 provider type used by [`Client`]: recommended fillers over an HTTP/WS root provider.
pub type DefaultProvider = FillProvider<JoinedRecommendedFillers, RootProvider>;

/// Default HTTP timeout for RPC and auxiliary HTTP clients.
pub const DEFAULT_HTTP_TIMEOUT: Duration = Duration::from_secs(12);

/// Instances of Shasta protocol contracts.
#[derive(Clone, Debug)]
pub struct ShastaProtocolInstance {
    /// Inbox contract instance on L1.
    pub inbox: InboxInstance<DefaultProvider>,
    /// Anchor contract instance on L2 (auth provider).
    pub anchor: AnchorInstance<RootProvider>,
}

/// A client for interacting with L1 and L2 providers and Shasta protocol contracts.
///
/// The client is read-only towards L1: it never signs or submits transactions, so it
/// carries no wallet. L1 transaction submission is owned by the proposer's transaction
/// manager, which keeps nonce management on a single path.
#[derive(Clone, Debug)]
pub struct Client {
    /// L2 chain ID, fetched from the L2 provider at startup.
    pub chain_id: u64,
    /// Walletless L1 provider used for contract calls and event scans.
    pub l1_provider: DefaultProvider,
    /// L2 public provider for read-only access.
    pub l2_provider: RootProvider,
    /// L2 authenticated provider for engine/anchor interactions.
    pub l2_auth_provider: RootProvider,
    /// Shasta protocol contract bundle (Inbox/Anchor).
    pub shasta: ShastaProtocolInstance,
}

/// Configuration for the `Client`.
#[derive(Clone, Debug)]
pub struct ClientConfig {
    /// Source describing how to build the L1 provider used by contract calls and event scans.
    pub l1_provider_source: SubscriptionSource,
    /// HTTP endpoint for the L2 public provider.
    pub l2_provider_url: Url,
    /// HTTP endpoint for the L2 authenticated provider.
    pub l2_auth_provider_url: Url,
    /// Path to the engine JWT secret.
    pub jwt_secret: PathBuf,
    /// L1 address of the Inbox contract.
    pub inbox_address: Address,
}

impl Client {
    /// Create a new `Client` from the given configuration.
    pub async fn new(config: ClientConfig) -> Result<Self> {
        let l1_provider = config.l1_provider_source.to_provider().await.map_err(|e| {
            RpcClientError::Connection(format!(
                "L1 provider source (l1.http or l1.ws) connection failed: {}",
                e
            ))
        })?;
        let l2_provider =
            connect_provider_with_timeout(config.l2_provider_url.clone()).await.map_err(|e| {
                RpcClientError::Connection(format!(
                    "L2 HTTP RPC (l2.http) connection failed for {}: {}",
                    config.l2_provider_url, e
                ))
            })?;
        let jwt_secret = read_jwt_secret(config.jwt_secret.as_path()).ok_or_else(|| {
            RpcClientError::JwtSecretReadFailed(config.jwt_secret.display().to_string())
        })?;
        let l2_auth_provider =
            build_jwt_http_provider(config.l2_auth_provider_url.clone(), jwt_secret);

        let chain_id = l2_provider.get_chain_id().await.map_err(|e| {
            RpcClientError::RpcMessage(format!(
                "L2 HTTP RPC (l2.http) failed to get chain id from {}: {}",
                config.l2_provider_url, e
            ))
        })?;

        let inbox = InboxInstance::new(config.inbox_address, l1_provider.clone());
        let anchor = AnchorInstance::new(get_treasury_address(chain_id), l2_auth_provider.clone());

        info!(
            inbox_address = ?config.inbox_address,
            anchor_address = ?anchor.address(),
            "Shasta protocol contract addresses"
        );

        let shasta = ShastaProtocolInstance { inbox, anchor };

        Ok(Self { chain_id, l1_provider, l2_provider, l2_auth_provider, shasta })
    }

    /// Fetch the anchor block number advertised by the anchor contract at the given
    /// parent block hash.
    pub async fn shasta_anchor_block_number_by_hash(&self, block_hash: B256) -> Result<u64> {
        let block_id = BlockId::Hash(RpcBlockHash { block_hash, require_canonical: Some(false) });

        let block_state = self.shasta.anchor.getBlockState().block(block_id).call().await?;

        Ok(block_state.anchorBlockNumber.to::<u64>())
    }

    /// Refuse an execution engine this client cannot drive: one without the Osaka Engine API
    /// methods ([`Client::check_engine_capabilities`]), or one whose L2 head contradicts the
    /// client's Etna fork schedule ([`Client::check_etna_schedule`]).
    pub async fn check_execution_engine(&self) -> Result<()> {
        self.check_engine_capabilities().await?;
        self.check_etna_schedule().await
    }

    /// Verify that the L2 `latest` head agrees with the client's Etna fork schedule.
    ///
    /// The execution engine gives every non-genesis Etna block a nonzero `parentBeaconBlockRoot`
    /// and 13-byte `extraData`, and no earlier block both, so a client whose Etna activation time
    /// differs from the engine's fails here once the head has passed either time (see
    /// [`check_etna_schedule_for_head`]). A mismatch the head has not reached yet goes unseen.
    pub async fn check_etna_schedule(&self) -> Result<()> {
        let chain_id = self.chain_id;
        let etna_fork_timestamp = etna_fork_timestamp_for_chain(chain_id)
            .map_err(|source| RpcClientError::EtnaScheduleUnresolved { chain_id, source })?;
        let head = self
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or_else(|| RpcClientError::Provider("missing L2 latest block".to_string()))?;

        check_etna_schedule_for_head(
            chain_id,
            etna_fork_timestamp,
            EtnaScheduleHead {
                number: head.header.number,
                timestamp: head.header.timestamp,
                parent_beacon_block_root: head.header.parent_beacon_block_root,
                extra_data_len: head.header.extra_data.len(),
            },
        )
    }
}

/// L2 head fields inspected by [`check_etna_schedule_for_head`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EtnaScheduleHead {
    /// L2 head block number.
    pub number: u64,
    /// L2 head block timestamp, in seconds.
    pub timestamp: u64,
    /// L2 head `parentBeaconBlockRoot`: absent before Unzen, zero on Unzen blocks, nonzero on
    /// Etna blocks.
    pub parent_beacon_block_root: Option<B256>,
    /// Length in bytes of the L2 head's `extraData`.
    pub extra_data_len: usize,
}

impl EtnaScheduleHead {
    /// Whether the head has an Etna header: a nonzero `parentBeaconBlockRoot` and 13-byte
    /// `extraData`.
    pub fn is_etna_block(&self) -> bool {
        self.parent_beacon_block_root.is_some_and(|root| !root.is_zero()) &&
            self.extra_data_len == ETNA_EXTRA_DATA_LEN
    }
}

/// Compare an L2 head with the client's Etna fork schedule for `chain_id`, whose Etna activation
/// time is `etna_fork_timestamp` (`None` = never).
///
/// The genesis head always passes. Any other head must be an Etna block
/// ([`EtnaScheduleHead::is_etna_block`]) exactly when the schedule makes its timestamp Etna;
/// otherwise this returns [`RpcClientError::EtnaScheduleMismatch`] naming the head, the fork the
/// client expects there, and how to fix the schedule.
pub fn check_etna_schedule_for_head(
    chain_id: u64,
    etna_fork_timestamp: Option<u64>,
    head: EtnaScheduleHead,
) -> Result<()> {
    if head.number == 0 {
        return Ok(());
    }

    let expects_etna = is_etna_at(etna_fork_timestamp, head.timestamp);
    if head.is_etna_block() == expects_etna {
        return Ok(());
    }

    let expected_fork = if expects_etna {
        "Etna"
    } else {
        match unzen_active_for_chain_timestamp(chain_id, head.timestamp) {
            Ok(true) => "Unzen",
            Ok(false) => "Shasta",
            Err(_) => "a pre-Etna fork",
        }
    };
    Err(RpcClientError::EtnaScheduleMismatch { head, expected_fork })
}

/// Build a reqwest HTTP client with a bounded timeout.
fn reqwest_client_with_timeout() -> ReqwestClient {
    ReqwestClient::builder().timeout(DEFAULT_HTTP_TIMEOUT).build().expect("http client")
}

/// Build a [`RootProvider`] backed by a reqwest client with a bounded timeout.
pub fn connect_http_with_timeout(url: Url) -> RootProvider {
    ProviderBuilder::default().connect_reqwest(reqwest_client_with_timeout(), url)
}

/// Build a [`RootProvider`] backed by either HTTP or WebSocket transport based on URL scheme.
pub async fn connect_provider_with_timeout(url: Url) -> Result<RootProvider> {
    match url.scheme() {
        "http" | "https" => Ok(connect_http_with_timeout(url)),
        "ws" | "wss" => ProviderBuilder::default()
            .connect_ws(WsConnect::new(url.as_str()))
            .await
            .map_err(|e| RpcClientError::Connection(e.to_string())),
        scheme => Err(RpcClientError::Connection(format!("unsupported RPC scheme: {scheme}"))),
    }
}

/// Builds a [`RootProvider`] backed by an HTTP transport that authenticates each request
/// using the Engine API JWT scheme.
pub fn build_jwt_http_provider(url: Url, secret: JwtSecret) -> RootProvider {
    let hyper_client: HyperService<HttpConnector, Full<Bytes>> =
        HyperService::builder(TokioExecutor::new()).build_http::<Full<Bytes>>();

    let auth_layer = AuthLayer::new(secret);
    let service = ServiceBuilder::new()
        .map_err(io::Error::other)
        .layer(TimeoutLayer::new(DEFAULT_HTTP_TIMEOUT))
        .layer(auth_layer)
        .service(hyper_client);

    let layer_transport = HyperClient::<Full<Bytes>, _>::with_service(service);
    let http_hyper = Http::with_client(layer_transport, url);

    ProviderBuilder::default().connect_client(RpcClient::new(http_hyper, true))
}

/// Returns the JWT secret for the engine API
/// using the provided path. If the file is not found, it will return [None].
pub fn read_jwt_secret(path: &Path) -> Option<JwtSecret> {
    if let Ok(secret) = fs::read_to_string(path) {
        return JwtSecret::from_hex(secret).ok();
    };

    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID;

    #[test]
    fn test_read_jwt_secret() {
        let jwt_path =
            PathBuf::from(concat!(env!("CARGO_MANIFEST_DIR"), "/../../tests/docker/jwt.hex"));

        // Should successfully read the JWT secret
        let secret = read_jwt_secret(jwt_path.as_path());
        assert!(secret.is_some());

        // Verify the secret is a valid 32-byte key
        let secret = secret.unwrap();
        assert_eq!(secret.as_bytes().len(), 32);
    }

    #[test]
    fn test_read_jwt_secret_nonexistent() {
        let jwt_path = PathBuf::from("/nonexistent/path/jwt.hex");

        // Should return None for non-existent file
        let secret = read_jwt_secret(jwt_path.as_path());
        assert!(secret.is_none());
    }

    #[tokio::test]
    async fn connect_provider_rejects_unknown_scheme() {
        let url = Url::parse("ftp://localhost:1234").expect("invalid test URL");
        let err = connect_provider_with_timeout(url).await.unwrap_err();
        assert!(err.to_string().contains("unsupported RPC scheme"));
    }

    /// Etna activation time used by the schedule-check tests.
    const ETNA_TIMESTAMP: u64 = 1_000;

    /// Non-genesis L2 head at `timestamp` with the given root and `extraData` length.
    fn schedule_head(
        timestamp: u64,
        parent_beacon_block_root: Option<B256>,
        extra_data_len: usize,
    ) -> EtnaScheduleHead {
        EtnaScheduleHead { number: 5, timestamp, parent_beacon_block_root, extra_data_len }
    }

    /// Run the schedule check for the devnet chain, whose Unzen fork is active from genesis.
    fn check(etna_fork_timestamp: Option<u64>, head: EtnaScheduleHead) -> Result<()> {
        check_etna_schedule_for_head(TAIKO_DEVNET_CHAIN_ID, etna_fork_timestamp, head)
    }

    #[test]
    fn etna_schedule_check_matrix() {
        let etna_root = Some(B256::with_last_byte(1));
        let etna = Some(ETNA_TIMESTAMP);
        // (case, Etna activation time, head, whether the check passes).
        let cases = [
            (
                "genesis passes whatever its shape",
                etna,
                EtnaScheduleHead { number: 0, ..schedule_head(ETNA_TIMESTAMP, None, 0) },
                true,
            ),
            (
                "Etna head with a nonzero root and 13 bytes",
                etna,
                schedule_head(ETNA_TIMESTAMP, etna_root, 13),
                true,
            ),
            (
                "Etna-scheduled head with a zero root",
                etna,
                schedule_head(ETNA_TIMESTAMP, Some(B256::ZERO), 13),
                false,
            ),
            (
                "Etna-scheduled head without a root",
                etna,
                schedule_head(ETNA_TIMESTAMP, None, 13),
                false,
            ),
            (
                "Etna-scheduled head with 7-byte extraData",
                etna,
                schedule_head(ETNA_TIMESTAMP, etna_root, 7),
                false,
            ),
            (
                "pre-Etna head with a nonzero root",
                etna,
                schedule_head(ETNA_TIMESTAMP - 1, etna_root, 13),
                false,
            ),
            (
                "pre-Etna head with a zero root and 7 bytes",
                etna,
                schedule_head(ETNA_TIMESTAMP - 1, Some(B256::ZERO), 7),
                true,
            ),
            (
                "Etna never and a zero-root 7-byte head",
                None,
                schedule_head(ETNA_TIMESTAMP, Some(B256::ZERO), 7),
                true,
            ),
            (
                "Etna never and a 13-byte nonzero-root head",
                None,
                schedule_head(ETNA_TIMESTAMP, etna_root, 13),
                false,
            ),
        ];

        for (case, etna_fork_timestamp, head, passes) in cases {
            let result = check(etna_fork_timestamp, head);
            assert_eq!(result.is_ok(), passes, "{case}: {result:?}");
            if !passes {
                assert!(
                    matches!(result, Err(RpcClientError::EtnaScheduleMismatch { .. })),
                    "{case}: {result:?}"
                );
            }
        }
    }

    #[test]
    fn etna_schedule_mismatch_names_the_head_the_expected_fork_and_the_hint() {
        let err =
            check(Some(ETNA_TIMESTAMP), schedule_head(ETNA_TIMESTAMP + 1, Some(B256::ZERO), 7))
                .unwrap_err()
                .to_string();
        assert_eq!(
            err,
            format!(
                "L2 head block 5 (timestamp {}, parentBeaconBlockRoot {}, extraData length 7) is \
                 a pre-Etna block, but the client's fork schedule expects Etna at that timestamp: \
                 the client's Etna activation time must match the execution engine's (on a \
                 devnet, set --devnet-etna-timestamp to the execution engine's Etna time)",
                ETNA_TIMESTAMP + 1,
                B256::ZERO
            )
        );

        let root = B256::with_last_byte(1);
        let err =
            check(None, schedule_head(ETNA_TIMESTAMP, Some(root), 13)).unwrap_err().to_string();
        assert!(
            err.contains(&format!(
                "(timestamp {ETNA_TIMESTAMP}, parentBeaconBlockRoot {root}, extraData length 13) \
                 is an Etna block, but the client's fork schedule expects Unzen at that timestamp"
            )),
            "{err}"
        );
        assert!(err.contains("set --devnet-etna-timestamp"), "{err}");

        let err = check(Some(ETNA_TIMESTAMP), schedule_head(ETNA_TIMESTAMP, None, 0))
            .unwrap_err()
            .to_string();
        assert!(err.contains("parentBeaconBlockRoot none, extraData length 0"), "{err}");
    }
}
