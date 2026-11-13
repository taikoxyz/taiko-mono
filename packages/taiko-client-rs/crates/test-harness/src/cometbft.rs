//! CometBFT node homes and a minimal CometBFT RPC client.

use std::{fs, os::unix::fs::DirBuilderExt, path::Path, time::Duration};

use abci::{
    CommitteeState, EtnaEnvelope, Status, key::ConsensusKey, single_envelope, valstate::ValEntry,
};
use alloy_primitives::{B256, Bytes};
use anyhow::{Context, Result, bail, ensure};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use serde_json::Value;
use url::Url;

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
    /// Mandatory remote guarded signer listener; the real key is outside this home.
    pub signer_addr: &'a str,
    /// The node key (`node_key.json`).
    pub node: &'a crate::keys::NodeKey,
}

/// Writes a CometBFT home into `dir`: a minimal `config/config.toml`, `config/genesis.json`,
/// the node key, a mandatory remote signer listener and the supervisor's private `run/` for
/// Unix signer sockets. The real FilePV files live elsewhere.
pub(crate) fn write_home(dir: &Path, c: &HomeConfig<'_>) -> Result<()> {
    ensure!(!c.signer_addr.is_empty(), "validator harness requires priv_validator_laddr");
    let config = dir.join("config");
    let data = dir.join("data");
    fs::create_dir_all(&config)?;
    fs::create_dir_all(&data)?;
    fs::DirBuilder::new().mode(0o700).create(dir.join("run"))?;
    let toml = format!(
        r#"proxy_app = "{proxy_app}"
moniker = "{moniker}"
priv_validator_laddr = "{signer_addr}"

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
        signer_addr = c.signer_addr,
        peers = c.persistent_peers,
        timeout_commit = c.timeout_commit_ms,
    );
    fs::write(config.join("config.toml"), toml)?;
    fs::write(config.join("genesis.json"), c.genesis_json)?;
    fs::write(
        config.join("node_key.json"),
        serde_json::to_string_pretty(&c.node.node_key_json())?,
    )?;
    Ok(())
}

/// One validator of a CometBFT validator set.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CmtValidator {
    /// Canonical native compressed consensus key.
    pub pubkey: abci::key::ConsensusKey,
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
    /// The RPC base URL (`http://host:port/`); a restarted node keeps its fixed host port.
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
    pub fn url(&self) -> Url {
        self.base.clone()
    }

    /// `GET <base>/<method>?<query>` and its JSON-RPC `result`.
    pub async fn call(&self, method: &str, query: &[(&str, String)]) -> Result<Value> {
        let mut url = self.url().join(method)?;
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
        self.validator_entries(height)
            .await?
            .into_iter()
            .map(|e| Ok(CmtValidator { pubkey: e.key, power: u64::try_from(e.power)? }))
            .collect()
    }

    /// Every validator `/validators` reports at `height` (the latest when `None`), page by
    /// page, in CometBFT order with its power and proposer priority. CometBFT stores a set in
    /// full only at genesis, at each height a changed set first signs and every 100,000
    /// heights; at any other height it rebuilds the priorities in bulk, which can differ from
    /// the live state.
    pub async fn validator_entries(&self, mut height: Option<u64>) -> Result<Vec<ValEntry>> {
        /// CometBFT's largest `per_page`.
        const PER_PAGE: u64 = 100;
        let mut entries = Vec::new();
        for page in 1u64.. {
            let mut query = vec![("per_page", PER_PAGE.to_string()), ("page", page.to_string())];
            if let Some(h) = height {
                query.push(("height", h.to_string()));
            }
            let result = self.call("validators", &query).await?;
            // Later pages read the height the first one answered for.
            height = Some(str_u64(&result["block_height"])?);
            let total = usize::try_from(str_u64(&result["total"])?)?;
            let validators = result["validators"].as_array().context("validators: no array")?;
            ensure!(!validators.is_empty() || total == 0, "validators: empty page {page}");
            for v in validators {
                ensure!(
                    v["pub_key"]["type"] == "tendermint/PubKeySecp256k1eth",
                    "native validator key type required"
                );
                let key = STANDARD.decode(v["pub_key"]["value"].as_str().context("pub_key")?)?;
                entries.push(ValEntry {
                    key: ConsensusKey::from_slice(&key)?,
                    power: str_i64(&v["voting_power"])?,
                    priority: str_i64(&v["proposer_priority"])?,
                });
            }
            ensure!(entries.len() <= total, "validators: more than the total {total}");
            if entries.len() == total {
                break;
            }
        }
        Ok(entries)
    }

    /// The validator updates the app's `FinalizeBlock` returned at `height`, as `/block_results`
    /// records them (a removal at power 0).
    pub async fn validator_updates(&self, height: u64) -> Result<Vec<(ConsensusKey, u64)>> {
        /// The JSON type name of a secp256k1eth `crypto.PublicKey`.
        const SECP256K1ETH: &str = "tendermint.crypto.PublicKey_Secp256K1Eth";
        let result = self.call("block_results", &[("height", height.to_string())]).await?;
        let Some(updates) = result["validator_updates"].as_array() else {
            ensure!(result["validator_updates"].is_null(), "block_results: validator_updates");
            return Ok(Vec::new());
        };
        updates
            .iter()
            .map(|u| {
                let sum = &u["pub_key"]["Sum"];
                ensure!(sum["type"] == SECP256K1ETH, "native validator update key required: {u}");
                let key = sum["value"]["secp256k1eth"].as_str().context("secp256k1eth key")?;
                // A zero power is omitted.
                let power = if u["power"].is_null() { 0 } else { str_u64(&u["power"])? };
                Ok((ConsensusKey::from_slice(&STANDARD.decode(key)?)?, power))
            })
            .collect()
    }

    /// The round of the commit that decided `height`.
    pub async fn commit_round(&self, height: u64) -> Result<u64> {
        let result = self.call("commit", &[("height", height.to_string())]).await?;
        str_u64(&result["signed_header"]["commit"]["round"])
    }

    /// The latest height and the validator set there.
    pub async fn status(&self) -> Result<CmtStatus> {
        let latest_height = self.latest_height().await?;
        Ok(CmtStatus { latest_height, validators: self.validators(Some(latest_height)).await? })
    }

    /// `abci_query` of `path`: the value when the app answers code 0, `None` otherwise.
    pub async fn abci_query(&self, path: &str) -> Result<Option<Vec<u8>>> {
        Ok(self.abci_answer(path).await?.ok())
    }

    /// `abci_query` of `path`: the value when the app answers code 0, otherwise the app's
    /// refusal log.
    pub async fn abci_answer(&self, path: &str) -> Result<std::result::Result<Vec<u8>, String>> {
        let result = self.call("abci_query", &[("path", format!("\"{path}\""))]).await?;
        let response = &result["response"];
        if response["code"].as_u64().unwrap_or(0) != 0 {
            return Ok(Err(response["log"].as_str().unwrap_or_default().to_string()));
        }
        let value = response["value"].as_str().unwrap_or_default();
        Ok(Ok(STANDARD.decode(value)?))
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

    /// The validator addresses (upper-case hex, as [`ValidatorKey::address`]) whose precommit
    /// for the block is in the commit of `height` (`block_id_flag` = commit). Below the latest
    /// height this is the canonical commit carried by block `height + 1`.
    pub async fn commit_signers(&self, height: u64) -> Result<Vec<String>> {
        /// CometBFT's `BlockIDFlagCommit`.
        const BLOCK_ID_FLAG_COMMIT: u64 = 2;
        let result = self.call("commit", &[("height", height.to_string())]).await?;
        let signatures = result["signed_header"]["commit"]["signatures"]
            .as_array()
            .context("commit: no signatures array")?;
        let mut signers = Vec::new();
        for sig in signatures {
            if str_u64(&sig["block_id_flag"])? == BLOCK_ID_FLAG_COMMIT {
                let address = sig["validator_address"].as_str().context("validator_address")?;
                signers.push(address.to_uppercase());
            }
        }
        Ok(signers)
    }

    /// The `/block` result at `height`.
    async fn block(&self, height: u64) -> Result<Value> {
        self.call("block", &[("height", height.to_string())]).await
    }

    /// The `app_hash` in the header of the block at `height`.
    pub async fn header_app_hash(&self, height: u64) -> Result<B256> {
        let block = self.block(height).await?;
        let hash = block["block"]["header"]["app_hash"].as_str().context("app_hash")?;
        hash.parse().with_context(|| format!("app_hash {hash:?}"))
    }

    /// The address (upper-case hex, as [`ValidatorKey::address`]) of the validator that
    /// proposed the block at `height`.
    pub async fn proposer_address(&self, height: u64) -> Result<String> {
        let block = self.block(height).await?;
        let address =
            block["block"]["header"]["proposer_address"].as_str().context("proposer_address")?;
        Ok(address.to_uppercase())
    }

    /// The Etna envelope the block at `height` carries as its single transaction.
    pub async fn envelope(&self, height: u64) -> Result<EtnaEnvelope> {
        let block = self.block(height).await?;
        let txs = block["block"]["data"]["txs"]
            .as_array()
            .with_context(|| format!("block {height}: no txs array"))?
            .iter()
            .map(|tx| Ok(Bytes::from(STANDARD.decode(tx.as_str().context("tx")?)?)))
            .collect::<Result<Vec<_>>>()?;
        single_envelope(&txs).with_context(|| format!("block {height} envelope"))
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

/// A signed decimal-string (or number) JSON value as `i64`.
fn str_i64(v: &Value) -> Result<i64> {
    match v {
        Value::String(s) => Ok(s.parse()?),
        Value::Number(n) => n.as_i64().context("i64"),
        other => bail!("expected a decimal string, got {other}"),
    }
}
