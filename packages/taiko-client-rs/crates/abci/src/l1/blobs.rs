//! Forced inclusion blobs for `PrepareProposal`: [`BlobSource`], [`BeaconBlobs`] over the
//! operator's L1 beacon node, and [`LazyBeaconBlobs`], which connects to it on the first fetch.
//!
//! A background startup probe warms metadata and checks the endpoint; only a proposer building
//! the block that consumes a due forced inclusion entry fetches that entry's blob.
//! The block then carries the blob, so `ProcessProposal`, `FinalizeBlock` and replay never fetch
//! one, and a node starts, replays and votes without a reachable beacon.

use std::fmt;

use alloy_eips::eip4844::kzg_to_versioned_hash;
use alloy_primitives::{B256, Bytes};
use async_trait::async_trait;
use rpc::blob::BlobDataSource;
use tokio::sync::OnceCell;
use url::Url;

use crate::metrics::AbciMetrics;

/// Where a proposer fetches forced inclusion blobs from.
#[async_trait]
pub trait BlobSource: Send + Sync {
    /// The raw 131,072-byte blob with KZG versioned hash `versioned_hash`, carried by the L1
    /// block with timestamp `timestamp`; the error says why it cannot be served.
    async fn blob(&self, timestamp: u64, versioned_hash: B256) -> Result<Bytes, String>;
}

impl fmt::Debug for dyn BlobSource {
    /// `BlobSource`: implementations need not be `Debug`.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("BlobSource")
    }
}

/// A [`BlobSource`] over the L1 beacon node's blobs endpoint ([`BlobDataSource`]), which matches
/// every returned blob to the requested versioned hash by its KZG commitment.
#[derive(Debug)]
pub struct BeaconBlobs(pub BlobDataSource);

#[async_trait]
impl BlobSource for BeaconBlobs {
    /// Requests exactly `versioned_hash` from the beacon block at `timestamp`'s slot, and
    /// accepts only one sidecar of one blob whose commitment has that versioned hash.
    async fn blob(&self, timestamp: u64, versioned_hash: B256) -> Result<Bytes, String> {
        let sidecars =
            self.0.get_blobs(timestamp, &[versioned_hash]).await.map_err(|e| e.to_string())?;
        let [sidecar] = sidecars.as_slice() else {
            return Err(format!("expected one blob sidecar, got {}", sidecars.len()));
        };
        let ([blob], [commitment]) = (sidecar.blobs.as_slice(), sidecar.commitments.as_slice())
        else {
            return Err(format!(
                "expected one blob and commitment, got {} and {}",
                sidecar.blobs.len(),
                sidecar.commitments.len()
            ));
        };
        let got = kzg_to_versioned_hash(commitment.as_slice());
        if got != versioned_hash {
            return Err(format!("served blob {got}, requested {versioned_hash}"));
        }
        Ok(Bytes::copy_from_slice(blob.as_slice()))
    }
}

/// [`BeaconBlobs`] over the beacon node at an endpoint, built on the first fetch rather than at
/// startup: building reads the beacon's genesis and spec. A nonfatal startup [`Self::probe`]
/// can warm those reads outside the proposal deadline; fetches initialize it when needed too.
///
/// A fetch while the client cannot be built fails like any other unavailable blob, and the next
/// fetch tries to build it again; once built, the client is kept. Neither its errors nor its
/// `Debug` output render the endpoint, whose path or query may carry a provider key.
pub struct LazyBeaconBlobs {
    /// The beacon node's REST endpoint.
    endpoint: Url,
    /// The client, once built.
    beacon: OnceCell<BeaconBlobs>,
}

impl fmt::Debug for LazyBeaconBlobs {
    /// Reports whether the client is built, without the credential-bearing endpoint.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("LazyBeaconBlobs")
            .field("connected", &self.beacon.initialized())
            .finish_non_exhaustive()
    }
}

impl LazyBeaconBlobs {
    /// A source over the beacon node at `endpoint`; contacts nothing until the first fetch.
    pub fn new(endpoint: Url) -> Self {
        Self { endpoint, beacon: OnceCell::new() }
    }

    /// Builds the client and smoke-tests `/eth/v1/beacon/blobs/head`, allowing startup to warm
    /// metadata before a proposal needs it. Failure is nonfatal and later probes or fetches
    /// retry. Success does not guarantee retention or reconstruction of a particular due blob.
    pub async fn probe(&self) -> Result<(), String> {
        let result =
            async { self.client().await?.0.probe_beacon_blobs().await.map_err(|e| e.to_string()) }
                .await;
        AbciMetrics::beacon_blob_endpoint_up().set(i64::from(result.is_ok()));
        result
    }

    /// Returns the initialized client, keeping successful metadata initialization across
    /// proposals and probes and retrying initialization errors without rendering the endpoint.
    async fn client(&self) -> Result<&BeaconBlobs, String> {
        self.beacon
            .get_or_try_init(|| async {
                BlobDataSource::new(Some(self.endpoint.clone()), None, false).await.map(BeaconBlobs)
            })
            .await
            .map_err(|e| format!("beacon client unavailable: {e}"))
    }
}

#[async_trait]
impl BlobSource for LazyBeaconBlobs {
    /// Builds the beacon client if it is not built yet (an error names the failure), then
    /// fetches through [`BeaconBlobs`].
    async fn blob(&self, timestamp: u64, versioned_hash: B256) -> Result<Bytes, String> {
        let result = async { self.client().await?.blob(timestamp, versioned_hash).await }.await;
        AbciMetrics::beacon_blob_endpoint_up().set(i64::from(result.is_ok()));
        result
    }
}

#[cfg(test)]
mod tests {
    use std::sync::{Arc, Mutex};

    use alloy_primitives::hex;
    use tokio::{
        io::{AsyncReadExt, AsyncWriteExt},
        net::TcpListener,
    };
    use url::Url;

    use super::*;
    use crate::test_utils::{forced_blob, manifest_payload, sample_transactions};

    /// [`beacon_under`] with no path prefix on an ephemeral port.
    async fn beacon(blobs: Vec<Bytes>) -> (Url, Arc<Mutex<Vec<String>>>) {
        beacon_under(TcpListener::bind("127.0.0.1:0").await.expect("binds"), "", blobs)
    }

    /// A beacon node stub (genesis at 0, 12-second slots) on `listener` whose blobs endpoint
    /// answers `blobs` whatever is asked; returns its URL and the request targets it receives.
    /// It serves its routes only below the path `prefix` (e.g. a provider's `/<key>`), as a
    /// hosted beacon does; any other path answers 404. The URL carries the prefix.
    fn beacon_under(
        listener: TcpListener,
        prefix: &'static str,
        blobs: Vec<Bytes>,
    ) -> (Url, Arc<Mutex<Vec<String>>>) {
        let url =
            Url::parse(&format!("http://{}{prefix}", listener.local_addr().unwrap())).unwrap();
        let targets = Arc::new(Mutex::new(Vec::new()));
        let seen = targets.clone();
        let data: Vec<String> = blobs.iter().map(hex::encode_prefixed).collect();
        let blobs_body = serde_json::json!({ "data": data }).to_string();
        tokio::spawn(async move {
            while let Ok((mut stream, _)) = listener.accept().await {
                let mut head = Vec::new();
                let mut chunk = [0u8; 1024];
                while !head.windows(4).any(|w| w == b"\r\n\r\n") {
                    match stream.read(&mut chunk).await {
                        Ok(0) | Err(_) => break,
                        Ok(n) => head.extend_from_slice(&chunk[..n]),
                    }
                }
                let head = String::from_utf8_lossy(&head);
                let target = head.split_whitespace().nth(1).unwrap_or_default().to_string();
                let path = target.split('?').next().unwrap_or_default();
                let (status, body) = match path.strip_prefix(prefix) {
                    Some("/eth/v1/beacon/genesis") => {
                        ("200 OK", r#"{"data":{"genesis_time":"0"}}"#.to_string())
                    }
                    Some("/eth/v1/config/spec") => (
                        "200 OK",
                        r#"{"data":{"SECONDS_PER_SLOT":"12","SLOTS_PER_EPOCH":"32"}}"#.to_string(),
                    ),
                    Some(_) => ("200 OK", blobs_body.clone()),
                    None => ("404 Not Found", String::new()),
                };
                seen.lock().unwrap().push(target);
                let response = format!(
                    "HTTP/1.1 {status}\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\
                     Connection: close\r\n\r\n{body}",
                    body.len()
                );
                let _ = stream.write_all(response.as_bytes()).await;
            }
        });
        (url, targets)
    }

    /// The beacon source asks the beacon block at the timestamp's slot for exactly the one
    /// versioned hash, and serves the raw blob with that hash, whatever else the node returns; a
    /// node without it serves nothing.
    #[tokio::test]
    async fn beacon_blobs_serve_exactly_the_requested_blob() {
        let (blob, hash) = forced_blob(&manifest_payload(sample_transactions()));
        let (other, _) = forced_blob(&manifest_payload(vec![]));

        let (url, targets) = beacon(vec![other.clone(), blob.clone()]).await;
        let source = BeaconBlobs(BlobDataSource::new(Some(url), None, false).await.unwrap());
        // Timestamp 84 is slot 7.
        assert_eq!(source.blob(84, hash).await, Ok(blob));
        assert_eq!(
            targets.lock().unwrap().last(),
            Some(&format!("/eth/v1/beacon/blobs/7?versioned_hashes={hash}"))
        );

        let (url, _) = beacon(vec![other]).await;
        let source = BeaconBlobs(BlobDataSource::new(Some(url), None, false).await.unwrap());
        let err = source.blob(84, hash).await.expect_err("the node lacks the blob");
        assert!(err.contains("no beacon or blob server available"), "{err}");
    }

    /// A beacon hosted below a path prefix (a provider's `https://host/<key>/`) is asked below
    /// that prefix, with or without the trailing slash: every request keeps it.
    #[tokio::test]
    async fn beacon_blobs_keep_the_endpoint_path_prefix() {
        let (blob, hash) = forced_blob(&manifest_payload(sample_transactions()));
        for trailing_slash in [false, true] {
            let listener = TcpListener::bind("127.0.0.1:0").await.expect("binds");
            let (mut url, targets) = beacon_under(listener, "/v2/key-123", vec![blob.clone()]);
            if trailing_slash {
                url.set_path("/v2/key-123/");
            }
            let source = LazyBeaconBlobs::new(url);
            assert_eq!(source.blob(84, hash).await, Ok(blob.clone()), "slash {trailing_slash}");
            let targets = targets.lock().unwrap().clone();
            assert_eq!(
                targets,
                [
                    "/v2/key-123/eth/v1/beacon/genesis".to_string(),
                    "/v2/key-123/eth/v1/config/spec".to_string(),
                    format!("/v2/key-123/eth/v1/beacon/blobs/7?versioned_hashes={hash}"),
                ],
                "slash {trailing_slash}"
            );
        }
    }

    /// A provider key in the endpoint's path or query never reaches the lazy source's errors
    /// or its `Debug` output.
    #[tokio::test]
    async fn lazy_beacon_errors_and_debug_omit_the_endpoint() {
        let (_, hash) = forced_blob(&manifest_payload(sample_transactions()));
        // A free port nothing listens on.
        let addr = std::net::TcpListener::bind("127.0.0.1:0").unwrap().local_addr().unwrap();
        let url = Url::parse(&format!("http://{addr}/v2/path-key/?key=query-key")).unwrap();
        let source = LazyBeaconBlobs::new(url);
        let err = source.blob(84, hash).await.expect_err("the beacon is unreachable");
        let debug = format!("{source:?}");
        for secret in ["path-key", "query-key", "http://"] {
            assert!(!err.contains(secret), "error exposes {secret}: {err}");
            assert!(!debug.contains(secret), "Debug exposes {secret}: {debug}");
        }
    }

    /// The lazy beacon source contacts no beacon when built. While the beacon is unreachable a
    /// fetch fails (a fetch error, not a startup failure) and the next fetch tries again; once
    /// the beacon answers, the client is built once and reused.
    #[tokio::test]
    async fn lazy_beacon_blobs_connect_on_the_first_fetch_and_retry() {
        let (blob, hash) = forced_blob(&manifest_payload(sample_transactions()));
        // A free port nothing listens on yet.
        let addr = std::net::TcpListener::bind("127.0.0.1:0").unwrap().local_addr().unwrap();
        let source = LazyBeaconBlobs::new(Url::parse(&format!("http://{addr}")).unwrap());

        for _ in 0..2 {
            let err = source.blob(84, hash).await.expect_err("the beacon is unreachable");
            assert!(err.contains("beacon client unavailable"), "{err}");
        }

        let (_, targets) =
            beacon_under(TcpListener::bind(addr).await.expect("rebinds"), "", vec![blob.clone()]);
        assert_eq!(source.blob(84, hash).await, Ok(blob.clone()));
        assert_eq!(source.blob(84, hash).await, Ok(blob));
        let targets = targets.lock().unwrap().clone();
        let genesis = targets.iter().filter(|t| *t == "/eth/v1/beacon/genesis").count();
        assert_eq!(genesis, 1, "the client is built once: {targets:?}");
    }

    /// A startup smoke test checks the blobs route and initializes metadata once, outside the
    /// proposal timeout. An empty head still checks endpoint shape, without asserting custody.
    #[tokio::test]
    async fn beacon_probe_initializes_metadata_and_checks_the_blob_route() {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let (url, targets) = beacon_under(listener, "/provider-key", vec![]);
        let source = LazyBeaconBlobs::new(url);
        assert_eq!(source.probe().await, Ok(()));
        assert_eq!(source.probe().await, Ok(()));
        let requests = targets.lock().unwrap().clone();
        assert_eq!(requests.iter().filter(|r| r.ends_with("/beacon/genesis")).count(), 1);
        assert_eq!(requests.iter().filter(|r| r.ends_with("/config/spec")).count(), 1);
        assert_eq!(
            requests.iter().filter(|r| *r == "/provider-key/eth/v1/beacon/blobs/head").count(),
            2
        );
    }

    /// Failed preflight is an ordinary error and can be retried without exposing provider keys.
    #[tokio::test]
    async fn failed_beacon_probe_can_recover_without_exposing_credentials() {
        let addr = std::net::TcpListener::bind("127.0.0.1:0").unwrap().local_addr().unwrap();
        let source = LazyBeaconBlobs::new(
            Url::parse(&format!("http://{addr}/path-key?key=query-key")).unwrap(),
        );
        let error = source.probe().await.unwrap_err();
        for secret in ["path-key", "query-key", "http://"] {
            assert!(!error.contains(secret), "{error}");
        }
        let (_, _) = beacon_under(TcpListener::bind(addr).await.unwrap(), "/path-key", vec![]);
        assert_eq!(source.probe().await, Ok(()));
    }
}
