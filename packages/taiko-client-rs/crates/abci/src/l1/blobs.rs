//! Forced inclusion blobs for `PrepareProposal`: [`BlobSource`], and [`BeaconBlobs`] over the
//! operator's L1 beacon node.
//!
//! Only a proposer building the block that consumes a due forced inclusion entry fetches a blob.
//! The block then carries the blob, so `ProcessProposal`, `FinalizeBlock` and replay never fetch
//! one.

use std::fmt;

use alloy_eips::eip4844::kzg_to_versioned_hash;
use alloy_primitives::{B256, Bytes};
use async_trait::async_trait;
use rpc::blob::BlobDataSource;

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

    /// A beacon node stub (genesis at 0, 12-second slots) whose blobs endpoint answers `blobs`
    /// whatever is asked; returns its URL and the request targets it receives.
    async fn beacon(blobs: Vec<Bytes>) -> (Url, Arc<Mutex<Vec<String>>>) {
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("binds");
        let url = Url::parse(&format!("http://{}", listener.local_addr().unwrap())).unwrap();
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
                let body = match target.split('?').next().unwrap_or_default() {
                    "/eth/v1/beacon/genesis" => r#"{"data":{"genesis_time":"0"}}"#.to_string(),
                    "/eth/v1/config/spec" => {
                        r#"{"data":{"SECONDS_PER_SLOT":"12","SLOTS_PER_EPOCH":"32"}}"#.to_string()
                    }
                    _ => blobs_body.clone(),
                };
                seen.lock().unwrap().push(target);
                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\
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
}
