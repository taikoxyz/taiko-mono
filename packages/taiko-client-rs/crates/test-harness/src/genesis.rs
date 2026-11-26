//! Reproducible alloc-only Etna genesis and an isolated EL for real L1 fixtures.
use std::{collections::BTreeMap, fs, time::Duration};

use crate::{
    boot::{POLL, RETH_CMD, RETH_IMAGE, RPC_TIMEOUT, auth_provider, jwt_path, local_url},
    docker::{DockerEnv, host_port},
    wait_until,
};
use abci::{AccountWitness, ChainParams, ChainParamsExt, StorageProof};
use alloy::{consensus::Header, rlp};
use alloy_eips::{BlockNumberOrTag, eip7685::EMPTY_REQUESTS_HASH};
use alloy_genesis::{Genesis, GenesisAccount};
use alloy_primitives::{Address, B256, Bytes, KECCAK256_EMPTY, U256, address, keccak256};
use alloy_provider::{Provider, RootProvider};
use alloy_trie::{
    EMPTY_ROOT_HASH, HashBuilder, Nibbles, TrieAccount,
    proof::{ProofNodes, ProofRetainer},
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
    /// Full canonical header corresponding to the independently computed block-zero hash.
    pub header: Header,
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
        let state_root = state_root_unhashed(
            genesis.alloc.iter().map(|(address, account)| (*address, trie_account(account))),
        );
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
        Ok(Self { json, hash: header.hash_slow(), header, state_root })
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

    /// Fail startup unless the EL's block-start call targets `staking`, the proxy the client's
    /// configuration hash commits, as `taikoAuth_etnaStakingAddress` on the JWT-authenticated
    /// endpoint `auth` reports it, and the EL serves this genesis's predeployed proxy code there.
    pub async fn verify_staking(
        &self,
        l2: &RootProvider,
        auth: &RootProvider,
        staking: Address,
    ) -> Result<()> {
        let served: Option<Address> =
            auth.raw_request("taikoAuth_etnaStakingAddress".into(), ()).await?;
        ensure!(
            served == Some(staking),
            "the EL's block-start call targets {served:?}, not {staking}"
        );
        let genesis: Genesis = serde_json::from_str(&self.json)?;
        let code = genesis.alloc.get(&staking).and_then(|account| account.code.as_ref());
        let code = code.filter(|code| !code.is_empty()).context("no EtnaStaking predeploy")?;
        ensure!(l2.get_code_at(staking).await? == *code, "EtnaStaking code mismatch at {staking}");
        Ok(())
    }

    /// The EIP-1186 proof of `address` and its storage `slots` under block zero's state root, as
    /// `eth_getProof` at block zero answers it. For an address the alloc does not hold it is the
    /// exclusion proof, with empty account fields and every requested word zero, each without
    /// storage proof nodes.
    pub fn account_witness(&self, address: Address, slots: &[B256]) -> Result<AccountWitness> {
        let genesis: Genesis = serde_json::from_str(&self.json)?;
        let leaves = genesis
            .alloc
            .iter()
            .map(|(address, account)| (keccak256(address), rlp::encode(trie_account(account))));
        let (root, account_nodes) = proof_trie(leaves, &[keccak256(address)]);
        ensure!(root == self.state_root, "genesis alloc root differs from block zero's");
        let account_proof = proof_nodes(&account_nodes, keccak256(address));
        let Some(account) = genesis.alloc.get(&address) else {
            return Ok(AccountWitness {
                address,
                nonce: 0,
                balance: U256::ZERO,
                storage_root: EMPTY_ROOT_HASH,
                code_hash: KECCAK256_EMPTY,
                account_proof,
                storage: slots
                    .iter()
                    .map(|slot| StorageProof { slot: *slot, value: U256::ZERO, proof: vec![] })
                    .collect(),
            });
        };
        let words = storage_words(account).collect::<BTreeMap<_, _>>();
        let hashed = slots.iter().map(keccak256).collect::<Vec<_>>();
        let (storage_root, storage_nodes) = proof_trie(
            words.iter().map(|(slot, word)| (keccak256(slot), rlp::encode(word))),
            &hashed,
        );
        let trie = trie_account(account);
        ensure!(storage_root == trie.storage_root, "genesis storage root mismatch");
        Ok(AccountWitness {
            address,
            nonce: trie.nonce,
            balance: trie.balance,
            storage_root,
            code_hash: trie.code_hash,
            account_proof,
            storage: slots
                .iter()
                .map(|slot| StorageProof {
                    slot: *slot,
                    value: words.get(slot).copied().unwrap_or_default(),
                    proof: proof_nodes(&storage_nodes, keccak256(slot)),
                })
                .collect(),
        })
    }
}

/// The state-trie account of a genesis alloc entry.
fn trie_account(account: &GenesisAccount) -> TrieAccount {
    TrieAccount {
        nonce: account.nonce.unwrap_or_default(),
        balance: account.balance,
        code_hash: keccak256(account.code.as_ref().map_or(&[][..], |code| code.as_ref())),
        storage_root: storage_root_unhashed(storage_words(account)),
    }
}

/// The nonzero storage words of a genesis alloc entry.
fn storage_words(account: &GenesisAccount) -> impl Iterator<Item = (B256, U256)> + '_ {
    account.storage.iter().flatten().filter_map(|(key, value)| {
        (!value.is_zero()).then_some((*key, U256::from_be_bytes(value.0)))
    })
}

/// The root of the trie of `leaves`, keyed by hashed path, and the nodes that prove each of
/// `targets`.
fn proof_trie(
    leaves: impl Iterator<Item = (B256, Vec<u8>)>,
    targets: &[B256],
) -> (B256, ProofNodes) {
    let retainer = ProofRetainer::new(targets.iter().map(|key| Nibbles::unpack(key)).collect());
    let mut builder = HashBuilder::default().with_proof_retainer(retainer);
    for (key, value) in leaves.collect::<BTreeMap<_, _>>() {
        builder.add_leaf(Nibbles::unpack(key), &value);
    }
    (builder.root(), builder.take_proof_nodes())
}

/// The proof nodes on the path to `key`, root first.
fn proof_nodes(nodes: &ProofNodes, key: B256) -> Vec<Bytes> {
    nodes.matching_nodes_sorted(&Nibbles::unpack(key)).into_iter().map(|(_, node)| node).collect()
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
    /// Owned network for attaching another fixture container without exposing Engine RPC.
    pub fn docker_network(&self) -> &str {
        self.docker.network()
    }

    /// Name of this exact retained EL container, also used for restart.
    pub fn docker_container(&self) -> &str {
        self._tmp.path().file_name().unwrap().to_str().unwrap()
    }

    /// Start a fresh EL with canonical generated system predeploys and no obsolete fee vault.
    pub async fn start() -> Result<Self> {
        Self::start_with_ports(|| Ok((crate::app::free_port()?, crate::app::free_port()?))).await
    }

    /// Start with caller-supplied explicit HTTP/auth port pairs for initial Docker publication.
    /// Make at most three initial attempts, removing the exact failed container and network
    /// before requesting a fresh pair after a Docker port conflict. The winning pair stays fixed
    /// across restart. Readiness and genesis failures are returned without another attempt.
    pub async fn start_with_ports(mut ports: impl FnMut() -> Result<(u16, u16)>) -> Result<Self> {
        let genesis = EtnaGenesis::build()?;
        let tmp = tempfile::Builder::new().prefix("etna-el-").tempdir()?;
        let name = tmp.path().file_name().unwrap().to_string_lossy().to_string();
        let path = tmp.path().join("genesis.json");
        fs::write(&path, &genesis.json)?;
        let mount = format!("{}:/genesis.json:ro", path.display());
        let jwt_mount = format!("{}:/jwt.hex:ro", jwt_path()?.display());
        let image = std::env::var("ALETHIA_RETH_IMAGE").unwrap_or_else(|_| RETH_IMAGE.into());
        // Recovery profiles bind these endpoints immutably. Keep explicit loopback mappings;
        // free_port only observes availability, so initial Docker acquisition can still race.
        let mut attempt = 0;
        let docker = loop {
            attempt += 1;
            let pair = ports()?;
            let http_port = format!("127.0.0.1:{}:8545", pair.0);
            let auth_port = format!("127.0.0.1:{}:8551", pair.1);
            let mut args =
                vec!["-p", &http_port, "-p", &auth_port, "-v", &mount, "-v", &jwt_mount, &image];
            args.extend(RETH_CMD.split_whitespace());
            let mut docker = DockerEnv::create(format!("{name}-net")).await?;
            match docker.run(&name, &args).await {
                Ok(()) => break docker,
                Err(error) if attempt < 3 && is_initial_port_conflict(&error, pair) => {
                    docker.cleanup().await.with_context(|| {
                        format!("cleaning failed initial EL publication after {error:#}")
                    })?;
                }
                Err(error) => return Err(error),
            }
        };
        let http = local_url(host_port(&name, 8545).await?)?;
        let auth = local_url(host_port(&name, 8551).await?)?;
        let provider = connect_http_with_timeout(http.clone(), DEFAULT_HTTP_TIMEOUT);
        wait_until("custom genesis EL", RPC_TIMEOUT, POLL, || async {
            Ok(Some(provider.get_chain_id().await?))
        })
        .await?;
        genesis.verify(&provider).await?;
        let staking = ChainParams::builtin(167001)?.staking;
        genesis.verify_staking(&provider, &auth_provider(auth.clone())?, staking).await?;
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
    /// Restart the same owned EL container, retaining its canonical database and ports.
    pub async fn restart(&self) -> Result<()> {
        let name = self._tmp.path().file_name().unwrap().to_string_lossy();
        crate::docker::docker(&["restart", &name]).await?;
        wait_until("restarted custom genesis EL", RPC_TIMEOUT, POLL, || async {
            Ok(Some(self.provider.get_chain_id().await?))
        })
        .await?;
        Ok(())
    }
    /// Explicitly remove this instance's container and private network.
    pub async fn stop(mut self) -> Result<()> {
        self.docker.cleanup().await
    }
}

/// Whether initial Docker publication failed because one of this attempt's host ports is busy.
fn is_initial_port_conflict(error: &anyhow::Error, ports: (u16, u16)) -> bool {
    let message = error.to_string();
    let Some((_, stderr)) = message.strip_prefix("docker run ").and_then(|message| {
        message.split_once(" failed (exit status: 125): docker: Error response from daemon: ")
    }) else {
        return false;
    };
    [ports.0, ports.1].into_iter().any(|port| {
        stderr.contains(&format!(
            "failed to bind host port 127.0.0.1:{port}/tcp: address already in use"
        )) || (stderr.contains(&format!(
            "ports are not available: exposing port TCP 127.0.0.1:{port} -> "
        )) && stderr.contains(&format!(
            "listen tcp4 127.0.0.1:{port}: bind: address already in use"
        ))) || stderr.contains(&format!(
            "Bind for 127.0.0.1:{port} failed: port is already allocated"
        ))
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::Bytes;
    #[test]
    fn initial_port_conflicts_are_narrowly_classified() {
        let bridge = "failed to set up container networking: driver failed programming external connectivity on endpoint etna: failed to bind host port 127.0.0.1:58107/tcp: address already in use";
        let desktop = "ports are not available: exposing port TCP 127.0.0.1:58106 -> 127.0.0.1:0: listen tcp4 127.0.0.1:58106: bind: address already in use";
        let allocated = "Bind for 127.0.0.1:58107 failed: port is already allocated";
        for (status, stderr, expected) in [
            (125, bridge.to_owned(), true),
            (125, desktop.to_owned(), true),
            (125, allocated.to_owned(), true),
            (125, bridge.replace("58107", "58108"), false),
            (125, bridge.replace("127.0.0.1", "0.0.0.0"), false),
            (125, desktop.replace("58106 ->", "58108 ->"), false),
            (125, allocated.replace("58107", "58108"), false),
            (126, bridge.to_owned(), false),
            (125, "network not found".to_owned(), false),
            (125, "manifest unknown".to_owned(), false),
            (125, "invalid reference format".to_owned(), false),
            (125, "unrelated bind: address already in use".to_owned(), false),
            (125, "validation failed: custom genesis mismatch".to_owned(), false),
            (125, "authentication failed".to_owned(), false),
        ] {
            let error = anyhow::anyhow!(
                "docker run --name etna failed (exit status: {status}): docker: Error response from daemon: {stderr}"
            );
            assert_eq!(is_initial_port_conflict(&error, (58106, 58107)), expected, "{error}");
        }
        let unrelated = anyhow::anyhow!("readiness: {bridge}");
        assert!(!is_initial_port_conflict(&unrelated, (58106, 58107)));
    }

    #[test]
    fn genesis_preserves_non_alloc_and_predeploys_change_header() {
        let original: Value = serde_json::from_str(BASE).unwrap();
        let a = EtnaGenesis::build().unwrap();
        let b = EtnaGenesis::build().unwrap();
        let mut actual: Value = serde_json::from_str(&a.json).unwrap();
        for (key, account) in original["alloc"].as_object().unwrap() {
            let address: Address = key.parse().unwrap();
            if ![ROOTS, HISTORY].contains(&address) {
                assert_eq!(actual["alloc"][format!("{address:#x}")], *account);
            }
        }
        // The Etna genesis builder that laid the predeploys over the base dropped its root.
        assert!(original.get("stateRoot").is_none(), "the source carries a stale root");
        assert!(actual.get("stateRoot").is_none(), "alloc changes invalidate the source root");
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

    /// The pinned protocol revision's lander fixtures of the predeploys' contracts.
    const PROXY_ARTIFACT: &str =
        include_str!("../../lander/tests/fixtures/contracts/ERC1967Proxy.json");
    const STAKING_ARTIFACT: &str =
        include_str!("../../lander/tests/fixtures/contracts/EtnaStaking.json");
    const TOKEN_ARTIFACT: &str =
        include_str!("../../lander/tests/fixtures/contracts/BridgedTaikoToken.json");
    const SIGNAL_SERVICE_ARTIFACT: &str =
        include_str!("../../lander/tests/fixtures/contracts/EtnaSignalService.json");

    /// The compiled runtime in a contract fixture.
    fn runtime(artifact: &str) -> Bytes {
        let artifact: Value = serde_json::from_str(artifact).unwrap();
        artifact["deployedBytecode"]["object"].as_str().unwrap().parse().unwrap()
    }

    /// Whether `code` is the runtime `compiled` with its immutables filled in: as long, and equal
    /// at every byte the compiler did not leave zero.
    fn fills_immutables_of(code: &[u8], compiled: &[u8]) -> bool {
        code != compiled &&
            code.len() == compiled.len() &&
            code.iter().zip(compiled).all(|(byte, compiled)| *compiled == 0 || byte == compiled)
    }

    /// The devnet genesis predeploys `EtnaStaking` where alethia-reth's block-start call and the
    /// client's built-in parameters expect it, as the pinned protocol revision's proxy over its
    /// implementation, and bridged TAIKO likewise, holding the harness stakers' premint: three
    /// minStakes for each of anvil's first four dev accounts, which also hold ETH for gas.
    #[test]
    fn devnet_genesis_has_etna_staking_at_the_builtin_address() {
        use alethia_reth_primitives::addresses::etna_staking_address;
        use alloy_primitives::b256;

        const IMPLEMENTATION_SLOT: B256 =
            b256!("360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc");
        let staking = address!("1670010000000000000000000000000000010003");
        let token = address!("1670010000000000000000000000000000000007");
        assert_eq!(ChainParams::builtin(167001).unwrap().staking, staking);
        assert_eq!(etna_staking_address(167001), Some(staking));

        let genesis: Genesis = serde_json::from_str(&EtnaGenesis::build().unwrap().json).unwrap();
        let proxy = runtime(PROXY_ARTIFACT);
        for (address, implementation, artifact) in [
            (staking, address!("0167001000000000000000000000000000010003"), STAKING_ARTIFACT),
            (token, address!("0167001000000000000000000000000000000007"), TOKEN_ARTIFACT),
        ] {
            let account = genesis.alloc.get(&address).expect("predeployed proxy");
            assert_eq!(account.code.as_ref(), Some(&proxy), "{address} is not the pinned proxy");
            let slot = account.storage.as_ref().unwrap()[&IMPLEMENTATION_SLOT];
            assert_eq!(slot, implementation.into_word(), "{address} points elsewhere");
            let code = genesis.alloc[&implementation].code.as_ref().unwrap();
            assert!(fills_immutables_of(code, &runtime(artifact)), "{implementation}");
        }

        let storage = genesis.alloc[&token].storage.as_ref().unwrap();
        let word =
            |slot: B256| U256::from_be_bytes(storage.get(&slot).copied().unwrap_or_default().0);
        let premint = U256::from(23_437_500u64) * U256::from(10u64).pow(U256::from(18));
        let stakers = [
            address!("f39Fd6e51aad88F6F4ce6aB8827279cffFb92266"),
            address!("70997970C51812dc3A010C7d01b50e0d17dc79C8"),
            address!("3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"),
            address!("90F79bf6EB2c4f870365E785982E1f101E93b906"),
        ];
        for staker in stakers {
            // `_balances`, slot 301.
            let balance = keccak256([staker.into_word().0, B256::from(U256::from(301)).0].concat());
            assert_eq!(word(balance), premint, "{staker}");
            assert!(!genesis.alloc[&staker].balance.is_zero(), "{staker} holds no ETH");
        }
        // `_totalSupply`, slot 303.
        assert_eq!(word(B256::from(U256::from(303))), premint * U256::from(stakers.len()));
    }

    /// The devnet genesis's L2 SignalService proxy points at the pinned protocol revision's
    /// root-only `EtnaSignalService`, the implementation L1 runs too, with its immutables filled.
    #[test]
    fn devnet_genesis_runs_the_root_only_signal_service() {
        use alloy_primitives::b256;

        const IMPLEMENTATION_SLOT: B256 =
            b256!("360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc");
        let proxy = abci::l2_signal_service_address(167001);
        let implementation = address!("0167001000000000000000000000000000000005");
        let genesis: Genesis = serde_json::from_str(&EtnaGenesis::build().unwrap().json).unwrap();
        let account = genesis.alloc.get(&proxy).expect("predeployed SignalService proxy");
        assert_eq!(account.code.as_ref(), Some(&runtime(PROXY_ARTIFACT)));
        let slot = account.storage.as_ref().unwrap()[&IMPLEMENTATION_SLOT];
        assert_eq!(slot, implementation.into_word());
        let code = genesis.alloc[&implementation].code.as_ref().unwrap();
        assert!(fills_immutables_of(code, &runtime(SIGNAL_SERVICE_ARTIFACT)));
    }
}
