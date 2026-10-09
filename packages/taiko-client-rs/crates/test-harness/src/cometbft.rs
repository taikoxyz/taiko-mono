//! CometBFT node homes and a minimal CometBFT RPC client.

use std::{fs, path::Path, time::Duration};

use abci::{CommitteeState, Status};
use alloy_primitives::B256;
use anyhow::{Context, Result, bail};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use serde_json::Value;
use url::Url;

use crate::keys::ValidatorKey;

/// What differs between the devnet's CometBFT homes.
#[derive(Clone, Debug)]
pub(crate) struct HomeConfig<'a> {
    /// The node's moniker.
    pub moniker: &'a str,
    /// `proxy_app`: where the node reaches its ABCI app.
    pub proxy_app: &'a str,
    /// `[consensus] timeout_commit`, in milliseconds.
    pub timeout_commit_ms: u64,
    /// `[p2p] persistent_peers` (`<node id>@<host>:<port>`, comma separated).
    pub persistent_peers: &'a str,
    /// The genesis document.
    pub genesis_json: &'a str,
    /// The validator key (`priv_validator_key.json`).
    pub validator: &'a ValidatorKey,
    /// The node key (`node_key.json`).
    pub node: &'a ValidatorKey,
}

/// Writes a CometBFT home into `dir`: a minimal `config/config.toml`, `config/genesis.json`,
/// the key files and `data/priv_validator_state.json`.
pub(crate) fn write_home(dir: &Path, c: &HomeConfig<'_>) -> Result<()> {
    let config = dir.join("config");
    let data = dir.join("data");
    fs::create_dir_all(&config)?;
    fs::create_dir_all(&data)?;
    let toml = format!(
        r#"proxy_app = "{proxy_app}"
moniker = "{moniker}"

[rpc]
laddr = "tcp://0.0.0.0:26657"

[p2p]
laddr = "tcp://0.0.0.0:26656"
persistent_peers = "{peers}"
allow_duplicate_ip = true
addr_book_strict = false

[mempool]
type = "nop"

[consensus]
timeout_commit = "{timeout_commit}ms"
"#,
        proxy_app = c.proxy_app,
        moniker = c.moniker,
        peers = c.persistent_peers,
        timeout_commit = c.timeout_commit_ms,
    );
    fs::write(config.join("config.toml"), toml)?;
    fs::write(config.join("genesis.json"), c.genesis_json)?;
    fs::write(
        config.join("priv_validator_key.json"),
        serde_json::to_string_pretty(&c.validator.priv_validator_key_json())?,
    )?;
    fs::write(
        config.join("node_key.json"),
        serde_json::to_string_pretty(&c.node.node_key_json())?,
    )?;
    fs::write(data.join("priv_validator_state.json"), r#"{"height": "0", "round": 0, "step": 0}"#)?;
    Ok(())
}

/// One validator of a CometBFT validator set.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CmtValidator {
    /// The Ed25519 public key.
    pub pubkey: B256,
    /// The voting power.
    pub power: u64,
}

/// A CometBFT node's view of the chain.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CmtStatus {
    /// `sync_info.latest_block_height`.
    pub latest_height: u64,
    /// The validator set at the latest height.
    pub validators: Vec<CmtValidator>,
}

/// A minimal client of CometBFT's JSON-RPC (URI over HTTP GET).
#[derive(Clone, Debug)]
pub struct CmtClient {
    /// The HTTP client.
    http: reqwest::Client,
    /// The RPC base URL (`http://host:port/`).
    base: Url,
}

impl CmtClient {
    /// A client of the RPC at `base`.
    pub fn new(base: Url) -> Self {
        let http = reqwest::Client::builder()
            .timeout(Duration::from_secs(5))
            .build()
            .expect("a reqwest client with a timeout builds");
        Self { http, base }
    }

    /// The RPC base URL.
    pub fn url(&self) -> &Url {
        &self.base
    }

    /// `GET <base>/<method>?<query>` and its JSON-RPC `result`.
    pub async fn call(&self, method: &str, query: &[(&str, String)]) -> Result<Value> {
        let mut url = self.base.join(method)?;
        if !query.is_empty() {
            url.query_pairs_mut().extend_pairs(query);
        }
        let body: Value = self
            .http
            .get(url.clone())
            .send()
            .await
            .with_context(|| format!("GET {url}"))?
            .json()
            .await
            .with_context(|| format!("decoding GET {url}"))?;
        if let Some(error) = body.get("error") {
            bail!("{method}: {error}");
        }
        Ok(body.get("result").cloned().unwrap_or(body))
    }

    /// The latest committed height.
    pub async fn latest_height(&self) -> Result<u64> {
        let status = self.call("status", &[]).await?;
        str_u64(&status["sync_info"]["latest_block_height"])
    }

    /// The validator set at `height` (the latest when `None`).
    pub async fn validators(&self, height: Option<u64>) -> Result<Vec<CmtValidator>> {
        let mut query = vec![("per_page", "100".to_string())];
        if let Some(h) = height {
            query.push(("height", h.to_string()));
        }
        let result = self.call("validators", &query).await?;
        result["validators"]
            .as_array()
            .context("validators: no array")?
            .iter()
            .map(|v| {
                let key = STANDARD.decode(v["pub_key"]["value"].as_str().context("pub_key")?)?;
                Ok(CmtValidator {
                    pubkey: B256::try_from(key.as_slice()).context("32-byte key")?,
                    power: str_u64(&v["voting_power"])?,
                })
            })
            .collect()
    }

    /// The latest height and the validator set there.
    pub async fn status(&self) -> Result<CmtStatus> {
        let latest_height = self.latest_height().await?;
        Ok(CmtStatus { latest_height, validators: self.validators(Some(latest_height)).await? })
    }

    /// `abci_query` of `path`: the value when the app answers code 0, `None` otherwise.
    pub async fn abci_query(&self, path: &str) -> Result<Option<Vec<u8>>> {
        let result = self.call("abci_query", &[("path", format!("\"{path}\""))]).await?;
        let response = &result["response"];
        if response["code"].as_u64().unwrap_or(0) != 0 {
            return Ok(None);
        }
        let value = response["value"].as_str().unwrap_or_default();
        Ok(Some(STANDARD.decode(value)?))
    }

    /// The app's `/status`.
    pub async fn abci_status(&self) -> Result<Status> {
        let bytes = self.abci_query("/status").await?.context("the app rejected /status")?;
        Ok(serde_json::from_slice(&bytes)?)
    }

    /// The app's committee of `epoch`, if it knows one.
    pub async fn committee(&self, epoch: u64) -> Result<Option<CommitteeState>> {
        match self.abci_query(&format!("/committee/{epoch}")).await? {
            Some(bytes) => Ok(Some(serde_json::from_slice(&bytes)?)),
            None => Ok(None),
        }
    }

    /// The `app_hash` in the header of the block at `height`.
    pub async fn header_app_hash(&self, height: u64) -> Result<B256> {
        let block = self.call("block", &[("height", height.to_string())]).await?;
        let hash = block["block"]["header"]["app_hash"].as_str().context("app_hash")?;
        hash.parse().with_context(|| format!("app_hash {hash:?}"))
    }
}

/// A decimal-string (or number) JSON value as `u64`.
fn str_u64(v: &Value) -> Result<u64> {
    match v {
        Value::String(s) => Ok(s.parse()?),
        Value::Number(n) => n.as_u64().context("u64"),
        other => bail!("expected a decimal string, got {other}"),
    }
}
