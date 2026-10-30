//! Reproducible alloc-only Etna genesis and an isolated EL for real L1 fixtures.
use std::{fs, time::Duration};

use crate::{
    boot::{POLL, RETH_CMD, RETH_IMAGE, RPC_TIMEOUT, jwt_path, local_url},
    docker::{DockerEnv, host_port},
    wait_until,
};
use alloy::consensus::Header;
use alloy_eips::{BlockNumberOrTag, eip7685::EMPTY_REQUESTS_HASH};
use alloy_genesis::Genesis;
use alloy_primitives::{Address, B256, U256, address, keccak256};
use alloy_provider::{Provider, RootProvider};
use alloy_trie::{
    EMPTY_ROOT_HASH, TrieAccount,
    root::{state_root_unhashed, storage_root_unhashed},
};
use anyhow::{Context, Result, ensure};
use rpc::client::{DEFAULT_HTTP_TIMEOUT, connect_http_with_timeout};
use serde_json::{Value, json};
use tempfile::TempDir;
use url::Url;

/// Canonical EIP-4788 roots predeploy.
pub const ROOTS: Address = address!("000f3df6d732807ef1319fb7b8bb8522d0beac02");
/// Canonical EIP-2935 historical block-hash predeploy.
pub const HISTORY: Address = address!("0000f90827f1c53a10cb7a02335b175320002935");
const BASE: &str = include_str!("../contracts/devnet-genesis.json");
const SYSTEMS: &str = include_str!("../contracts/system-runtimes.json");

/// Canonical system predeploys and independently computed fresh Etna block zero.
#[derive(Debug, Clone)]
pub struct EtnaGenesis {
    /// Deterministic custom-chain JSON; canonical fields except alloc and derived stateRoot.
    pub json: String,
    /// Independently computed canonical Osaka block-zero header hash.
    pub hash: B256,
    /// Alloc trie root, computed without trusting the JSON stateRoot field.
    pub state_root: B256,
}

impl EtnaGenesis {
    /// Build canonical generated genesis with the pinned execution system predeploys.
    pub fn build() -> Result<Self> {
        let mut base: Value = serde_json::from_str(BASE)?;
        let mut alloc = serde_json::Map::new();
        for (key, value) in base["alloc"].as_object().context("genesis alloc")? {
            let address: Address = key.parse()?;
            ensure!(
                alloc.insert(format!("{address:#x}"), value.clone()).is_none(),
                "duplicate alloc address"
            );
        }
        let systems: serde_json::Map<String, Value> = serde_json::from_str(SYSTEMS)?;
        for (address, code) in systems {
            alloc.insert(address, json!({"balance":"0x0", "nonce":"0x1", "code":code}));
        }
        base["alloc"] = Value::Object(alloc);
        base.as_object_mut().context("genesis object")?.remove("stateRoot");
        let json = serde_json::to_string_pretty(&base)? + "\n";
        let genesis: Genesis = serde_json::from_str(&json)?;
        let state_root = state_root_unhashed(genesis.alloc.iter().map(|(address, account)| {
            (
                *address,
                TrieAccount {
                    nonce: account.nonce.unwrap_or_default(),
                    balance: account.balance,
                    code_hash: keccak256(
                        account.code.as_ref().map_or(&[][..], |code| code.as_ref()),
                    ),
                    storage_root: storage_root_unhashed(
                        account.storage.iter().flatten().filter_map(|(key, value)| {
                            (!value.is_zero()).then_some((*key, U256::from_be_bytes(value.0)))
                        }),
                    ),
                },
            )
        }));
        // The pinned devnet activates Osaka at genesis. Only the state root differs from
        // its canonical header: do not add Ethereum fork fields to the source JSON.
        let header = Header {
            number: genesis.number.unwrap_or_default(),
            parent_hash: genesis.parent_hash.unwrap_or_default(),
            gas_limit: genesis.gas_limit,
            difficulty: genesis.difficulty,
            nonce: genesis.nonce.into(),
            extra_data: genesis.extra_data,
            state_root,
            timestamp: genesis.timestamp,
            mix_hash: genesis.mix_hash,
            beneficiary: genesis.coinbase,
            base_fee_per_gas: genesis.base_fee_per_gas.map(|v| v as u64),
            withdrawals_root: Some(EMPTY_ROOT_HASH),
            parent_beacon_block_root: Some(B256::ZERO),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            requests_hash: Some(EMPTY_REQUESTS_HASH),
            ..Default::default()
        };
        Ok(Self { json, hash: header.hash_slow(), state_root })
    }

    /// Fail startup if EL ignored generated allocs, fork overrides, system code or genesis
    /// identity.
    pub async fn verify(&self, l2: &RootProvider) -> Result<()> {
        ensure!(l2.get_chain_id().await? == 167001, "unexpected L2 chain id");
        let block = l2
            .get_block_by_number(BlockNumberOrTag::Number(0))
            .await?
            .context("block zero missing")?;
        ensure!(
            (block.header.hash, block.header.state_root) == (self.hash, self.state_root),
            "custom genesis hash or state root mismatch"
        );
        let genesis: Genesis = serde_json::from_str(&self.json)?;
        for address in [ROOTS, HISTORY] {
            let expected = genesis.alloc[&address].code.as_ref().context("runtime missing")?;
            ensure!(
                !expected.is_empty() && l2.get_code_at(address).await? == *expected,
                "genesis runtime mismatch at {address}"
            );
        }
        Ok(())
    }
}

/// A fresh custom-genesis EL. Real fixtures predict Inbox before starting this node.
#[derive(Debug)]
pub struct StandaloneReth {
    /// Public JSON-RPC access to this owned EL.
    pub provider: RootProvider,
    /// Loopback public RPC endpoint.
    pub http: Url,
    /// Loopback JWT-authenticated Engine endpoint.
    pub auth: Url,
    /// Genesis whose header and deployed code were verified during startup.
    pub genesis: EtnaGenesis,
    docker: DockerEnv,
    _tmp: TempDir,
}
impl StandaloneReth {
    /// Start a fresh EL with canonical generated system predeploys and no obsolete fee vault.
    pub async fn start() -> Result<Self> {
        let genesis = EtnaGenesis::build()?;
        let tmp = tempfile::Builder::new().prefix("etna-el-").tempdir()?;
        let name = tmp.path().file_name().unwrap().to_string_lossy().to_string();
        let mut docker = DockerEnv::create(format!("{name}-net")).await?;
        let path = tmp.path().join("genesis.json");
        fs::write(&path, &genesis.json)?;
        let mount = format!("{}:/genesis.json:ro", path.display());
        let jwt_mount = format!("{}:/jwt.hex:ro", jwt_path()?.display());
        let image = std::env::var("ALETHIA_RETH_IMAGE").unwrap_or_else(|_| RETH_IMAGE.into());
        let mut args = vec![
            "-p",
            "127.0.0.1::8545",
            "-p",
            "127.0.0.1::8551",
            "-v",
            &mount,
            "-v",
            &jwt_mount,
            &image,
        ];
        args.extend(RETH_CMD.split_whitespace());
        docker.run(&name, &args).await?;
        let http = local_url(host_port(&name, 8545).await?)?;
        let auth = local_url(host_port(&name, 8551).await?)?;
        let provider = connect_http_with_timeout(http.clone(), DEFAULT_HTTP_TIMEOUT);
        wait_until("custom genesis EL", RPC_TIMEOUT, POLL, || async {
            Ok(Some(provider.get_chain_id().await?))
        })
        .await?;
        genesis.verify(&provider).await?;
        Ok(Self { provider, http, auth, genesis, docker, _tmp: tmp })
    }
    /// Engine access for tests that explicitly build and validate subsequent blocks.
    pub fn engine(&self) -> Result<abci::RpcEngine> {
        Ok(abci::RpcEngine::new(
            self.http.clone(),
            self.auth.clone(),
            &jwt_path()?,
            Duration::from_secs(30),
        )?)
    }
    /// Explicitly remove this instance's container and private network.
    pub async fn stop(mut self) -> Result<()> {
        self.docker.cleanup().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::Bytes;
    #[test]
    fn genesis_preserves_non_alloc_and_predeploys_change_header() {
        let mut original: Value = serde_json::from_str(BASE).unwrap();
        let a = EtnaGenesis::build().unwrap();
        let b = EtnaGenesis::build().unwrap();
        let mut actual: Value = serde_json::from_str(&a.json).unwrap();
        for (key, account) in original["alloc"].as_object().unwrap() {
            let address: Address = key.parse().unwrap();
            if ![ROOTS, HISTORY].contains(&address) {
                assert_eq!(actual["alloc"][format!("{address:#x}")], *account);
            }
        }
        assert!(original.get("stateRoot").is_some());
        assert!(actual.get("stateRoot").is_none(), "alloc changes invalidate the source root");
        original.as_object_mut().unwrap().remove("stateRoot");
        actual["alloc"] = original["alloc"].clone();
        assert_eq!(actual, original);
        assert_eq!(a.hash, b.hash);
        assert_eq!(a.state_root, b.state_root);
        assert_eq!(a.json, EtnaGenesis::build().unwrap().json);
    }
    #[test]
    fn committed_genesis_inputs_match_provenance() {
        use sha2::{Digest, Sha256};
        let manifest: Value =
            serde_json::from_str(include_str!("../contracts/genesis.manifest.json")).unwrap();
        for (name, data) in [("devnet-genesis.json", BASE), ("system-runtimes.json", SYSTEMS)] {
            assert_eq!(manifest["artifacts"][name], format!("{:x}", Sha256::digest(data)));
        }
        let fixture_manifest: Value =
            serde_json::from_str(include_str!("../contracts/FeeRoutingFixture.manifest.json"))
                .unwrap();
        for (field, bytes) in [
            ("source", include_bytes!("../contracts/FeeRoutingFixture.sol").as_slice()),
            ("artifact", include_bytes!("../contracts/FeeRoutingFixture.json").as_slice()),
        ] {
            assert_eq!(fixture_manifest[field]["sha256"], format!("{:x}", Sha256::digest(bytes)));
        }
        assert_eq!(fixture_manifest["compiler"]["version"], "0.8.30+commit.73712a01");
        assert_eq!(fixture_manifest["settings"]["evmVersion"], "osaka");
        let systems: Value = serde_json::from_str(SYSTEMS).unwrap();
        for (address, hash) in [
            (ROOTS, "cb7bd3e115730f7d57c15cd892880ed517ff4421bf43dfc7591198868fffe31d"),
            (HISTORY, "41cd74981e0201f79ebca054c4e8102a7e6faa28ce015d0048ab2250c1222c67"),
        ] {
            let code: Bytes = systems[format!("{address:#x}")].as_str().unwrap().parse().unwrap();
            assert_eq!(format!("{:x}", Sha256::digest(code)), hash);
        }
    }
}
