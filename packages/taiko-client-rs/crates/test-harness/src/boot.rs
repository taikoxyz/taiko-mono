//! The devnet boot sequence (see [`Devnet::start`](crate::Devnet::start)).

use std::{
    fs,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    time::Duration,
};

use abci::{
    ActivationRecord, ChainParams, GenesisDoc, RegistryEntry, RpcL1Source, Schedule, Snapshot,
    build_genesis,
    committee::{self, record_hash},
    l1::layout::inbox::ETNA_ACTIVE,
};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{B256, U256};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result, ensure};
use rpc::client::connect_http_with_timeout;
use url::Url;

use crate::{
    DevnetSpec,
    app::{AppConfig, AppNode, free_port},
    cometbft::{CmtClient, HomeConfig, write_home},
    docker::{DockerEnv, host_port},
    keys::{ValidatorKey, node_keys, validator_keys},
    l1::finalized_number,
    lander::{Lander, LanderCtx},
    planter::{InboxValues, Planter, registry_entry},
    wait::wait_until,
};

/// Default anvil image (override with `ANVIL_IMAGE`).
const ANVIL_IMAGE: &str = "ghcr.io/foundry-rs/foundry:stable";
/// Default alethia-reth #248 image (override with `ALETHIA_RETH_IMAGE`).
const RETH_IMAGE: &str = "us-docker.pkg.dev/evmchain/images/alethia-reth:sha-1e25b48";
/// Default CometBFT image (override with `COMETBFT_IMAGE`).
const COMETBFT_IMAGE: &str = "cometbft/cometbft:v0.40.0";

/// anvil's command line after the image: 1 s blocks, `finalized = latest − 2`.
const ANVIL_CMD: &str = "--host 0.0.0.0 --block-time 1 --slots-in-an-epoch 1 --gas-limit 200000000";
/// alethia-reth's command line after the image: devnet with Etna from genesis, no discovery.
const RETH_CMD: &str = "./alethia-reth node --chain devnet --devnet-etna-timestamp 0 --http \
    --http.addr 0.0.0.0 --http.api eth,net,debug --authrpc.addr 0.0.0.0 \
    --authrpc.jwtsecret /jwt.hex --disable-discovery";

/// Effective stake of every planted validator: 10 TAIKO.
pub(crate) const VALIDATOR_STAKE: u128 = 10_000_000_000_000_000_000;

/// Deadline for a container's RPC to come up.
pub(crate) const RPC_TIMEOUT: Duration = Duration::from_secs(90);
/// Poll interval of the readiness waits.
pub(crate) const POLL: Duration = Duration::from_millis(250);

/// One alethia-reth container.
#[derive(Clone, Debug)]
pub(crate) struct RethNode {
    /// Public JSON-RPC URL on the host.
    pub http: Url,
    /// Engine API URL on the host.
    pub auth: Url,
}

/// Everything [`boot`] starts.
pub(crate) struct Booted {
    /// The fake lander.
    pub lander: Lander,
    /// The apps, by validator index.
    pub apps: Vec<AppNode>,
    /// The CometBFT RPC clients, by validator index.
    pub cmt: Vec<CmtClient>,
    /// The alethia-reth nodes, by validator index.
    pub reth: Vec<RethNode>,
    /// anvil's JSON-RPC URL on the host.
    pub l1_http: Url,
    /// anvil provider.
    pub l1: RootProvider,
    /// The validator keys.
    pub keys: Vec<ValidatorKey>,
    /// The chain parameters the apps run with.
    pub params: ChainParams,
    /// The planted activation record.
    pub activation: ActivationRecord,
    /// The CometBFT genesis.
    pub genesis: GenesisDoc,
    /// Writes L1 state.
    pub planter: Planter,
}

/// Boots the devnet `id` into `docker`, keeping files under `tmp`:
///
/// 1. anvil and one alethia-reth per validator, waiting for their RPCs;
/// 2. the chain parameters for alethia-reth's chain id with `spec`'s `d_max` / `margin_v`;
/// 3. the setter contracts, then registry checkpoint 0 (the first `initial_validators` keys) and
///    the activated Inbox, both in L1 block `L1_0`;
/// 4. once `L1_0` is final, the CometBFT genesis via `abci::build_genesis`;
/// 5. one app per validator, listening before CometBFT starts;
/// 6. one CometBFT node per validator, waiting for their RPCs;
/// 7. the fake lander (planting committee records iff `spec.land_committees`).
pub(crate) async fn boot(
    id: &str,
    spec: &DevnetSpec,
    docker: &mut DockerEnv,
    tmp: &Path,
) -> Result<Booted> {
    let n = spec.validators;
    let jwt = jwt_path()?;

    // 1. L1 and ELs.
    let anvil = format!("abci-{id}-anvil");
    let anvil_image = image("ANVIL_IMAGE", ANVIL_IMAGE);
    let mut args = vec!["-p", "8545", "--entrypoint", "anvil", &anvil_image];
    args.extend(ANVIL_CMD.split_whitespace());
    docker.run(&anvil, &args).await?;
    let reth_image = image("ALETHIA_RETH_IMAGE", RETH_IMAGE);
    let jwt_mount = format!("{}:/jwt.hex:ro", jwt.display());
    let reth_names: Vec<String> = (0..n).map(|i| format!("abci-{id}-reth-{i}")).collect();
    for name in &reth_names {
        let mut args = vec!["-p", "8545", "-p", "8551", "-v", &jwt_mount, &reth_image];
        args.extend(RETH_CMD.split_whitespace());
        docker.run(name, &args).await?;
    }

    let l1_http = local_url(host_port(&anvil, 8545).await?)?;
    let l1 = connect_http_with_timeout(l1_http.clone());
    wait_until("anvil RPC", RPC_TIMEOUT, POLL, || async { Ok(Some(l1.get_block_number().await?)) })
        .await?;
    let mut reth = Vec::with_capacity(n);
    for name in &reth_names {
        let node = RethNode {
            http: local_url(host_port(name, 8545).await?)?,
            auth: local_url(host_port(name, 8551).await?)?,
        };
        let provider = connect_http_with_timeout(node.http.clone());
        wait_until(&format!("{name} RPC"), RPC_TIMEOUT, POLL, || async {
            Ok(Some(provider.get_chain_id().await?))
        })
        .await?;
        reth.push(node);
    }

    // 2. The L2 genesis anchor and the chain parameters.
    let l2 = connect_http_with_timeout(reth[0].http.clone());
    let chain_id = l2.get_chain_id().await?;
    let (genesis_hash, genesis_state_root) = genesis_block(&l2).await?;
    for node in &reth[1..] {
        let (other, _) = genesis_block(&connect_http_with_timeout(node.http.clone())).await?;
        ensure!(other == genesis_hash, "alethia-reth genesis hashes differ");
    }
    let params = ChainParams::builtin(chain_id)?
        .with_overrides(&format!("d_max = {}\nmargin_v = {}\n", spec.d_max, spec.margin_v))?;
    params.validate()?;

    // 3. L1 state: registry checkpoint 0 and the activated Inbox, both in block L1_0.
    let keys = validator_keys(n);
    let planter = Planter::new(l1.clone(), params.inbox, params.registry);
    planter.install().await?;
    let entries: Vec<_> = keys[..spec.initial_validators]
        .iter()
        .map(|k| registry_entry(k.pubkey(), U256::from(VALIDATOR_STAKE)))
        .collect();
    let activation =
        plant_genesis(&planter, &params, spec, &entries, (genesis_hash, genesis_state_root))
            .await?;
    let l1_0 = activation.l1_0;
    tracing::info!(l1_0, %genesis_hash, "activation planted");

    // 4. Genesis, once L1_0 is final.
    wait_until("L1 finalized >= L1_0", RPC_TIMEOUT, POLL, || async {
        Ok((finalized_number(&l1).await? >= l1_0).then_some(()))
    })
    .await?;
    let genesis = build_genesis(&RpcL1Source::new(l1.clone()), &params).await?;
    let genesis_json = genesis.to_json_pretty();

    // 5. The apps, listening before CometBFT starts.
    let mut apps = Vec::with_capacity(n);
    for (i, node) in reth.iter().enumerate() {
        let config = AppConfig {
            index: i,
            reth: node.clone(),
            l1_http: l1_http.clone(),
            params: params.clone(),
            jwt: jwt.clone(),
            store_dir: tmp.join(format!("app-{i}")),
            port: free_port()?,
        };
        apps.push(AppNode::start(config).await?);
    }

    // 6. CometBFT.
    let node_keys = node_keys(n);
    let cmt_image = image("COMETBFT_IMAGE", COMETBFT_IMAGE);
    let user = host_user().await?;
    let cmt_names: Vec<String> = (0..n).map(|i| format!("abci-{id}-cmt-{i}")).collect();
    for i in 0..n {
        let home = tmp.join(format!("cmt-{i}"));
        let peers = (0..n)
            .filter(|j| *j != i)
            .map(|j| format!("{}@{}:26656", node_keys[j].node_id(), cmt_names[j]))
            .collect::<Vec<_>>()
            .join(",");
        write_home(
            &home,
            &HomeConfig {
                moniker: &cmt_names[i],
                proxy_app: &format!("tcp://host.docker.internal:{}", apps[i].port()),
                timeout_commit_ms: spec.timeout_commit_ms,
                persistent_peers: &peers,
                genesis_json: &genesis_json,
                validator: &keys[i],
                node: &node_keys[i],
            },
        )?;
        make_world_writable(&home)?;
        let mount = format!("{}:/cometbft", home.display());
        let args = [
            "--add-host",
            "host.docker.internal:host-gateway",
            "--user",
            &user,
            "-p",
            "26657",
            "-v",
            &mount,
            "--entrypoint",
            "cometbft",
            &cmt_image,
            "start",
        ];
        docker.run(&cmt_names[i], &args).await?;
    }
    let mut cmt = Vec::with_capacity(n);
    for name in &cmt_names {
        let client = CmtClient::new(local_url(host_port(name, 26657).await?)?);
        wait_until(&format!("{name} RPC"), RPC_TIMEOUT, POLL, || async {
            Ok(Some(client.latest_height().await?))
        })
        .await?;
        cmt.push(client);
    }

    // 7. The fake lander.
    let lander = Lander::spawn(
        LanderCtx {
            planter: planter.clone(),
            l2,
            cmt: cmt[0].clone(),
            schedule: Schedule::from_activation(&activation),
            l2_chain_id: params.l2_chain_id,
        },
        spec.land_committees,
    );

    Ok(Booted { lander, apps, cmt, reth, l1_http, l1, keys, params, activation, genesis, planter })
}

/// The hash and state root of block 0 of the EL behind `l2`.
async fn genesis_block(l2: &RootProvider) -> Result<(B256, B256)> {
    let block = l2
        .get_block_by_number(BlockNumberOrTag::Number(0))
        .await?
        .context("alethia-reth has no block 0")?;
    Ok((block.header.hash, block.header.state_root))
}

/// Plants registry checkpoint 0 with `entries` and the activated Inbox (activation record over
/// the L2 genesis `(hash, state root)`, `lastCheckpoint = (0, genesis hash)`, generation 0,
/// `committee[e_0]`) into one L1 block, `L1_0`, and returns the activation record.
async fn plant_genesis(
    planter: &Planter,
    params: &ChainParams,
    spec: &DevnetSpec,
    entries: &[RegistryEntry],
    (genesis_hash, genesis_state_root): (B256, B256),
) -> Result<ActivationRecord> {
    let mut next = planter.next_block().await?;
    let l1_0 = next.number();
    let index = next.write_registry_checkpoint(entries).await?;
    ensure!(index == 0, "the registry already holds {index} checkpoints");
    let activation = ActivationRecord {
        genesis_height: 0,
        l1_0,
        epoch_len: spec.epoch_len,
        epoch_len_l1: spec.epoch_len_l1,
        genesis_hash,
        genesis_state_root,
    };
    let cutoff = committee::cutoff(l1_0, params.cutoff_grid, params.cutoff_lag)?;
    let snapshot = Snapshot { checkpoint_index: 0, l1_block: l1_0, entries: entries.to_vec() };
    let (record, _) = committee::derive(&snapshot, cutoff, Schedule::E0, params)?;
    next.plant_inbox(&InboxValues {
        migration_state: Some(ETNA_ACTIVE),
        recovery_generation: Some(0),
        last_checkpoint: Some((0, genesis_hash)),
        activation: Some(activation.clone()),
        committee: vec![(Schedule::E0, record_hash(params.l2_chain_id, &record))],
    })
    .await?;
    let mined = next.commit().await?;
    ensure!(mined == l1_0, "activation landed in L1 block {mined}, expected {l1_0}");
    Ok(activation)
}

/// `http://127.0.0.1:<port>/`.
pub(crate) fn local_url(port: u16) -> Result<Url> {
    Ok(Url::parse(&format!("http://127.0.0.1:{port}/"))?)
}

/// The image named by env var `var`, or `default`.
fn image(var: &str, default: &str) -> String {
    std::env::var(var).unwrap_or_else(|_| default.to_string())
}

/// The package's test JWT secret (`tests/docker/jwt.hex`).
fn jwt_path() -> Result<PathBuf> {
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../tests/docker/jwt.hex");
    path.canonicalize().with_context(|| format!("JWT secret {}", path.display()))
}

/// `<uid>:<gid>` of this process, so CometBFT writes its home as the host user.
async fn host_user() -> Result<String> {
    let id = |flag: &'static str| async move {
        let out = tokio::process::Command::new("id").arg(flag).output().await?;
        ensure!(out.status.success(), "id {flag} failed");
        Ok::<_, anyhow::Error>(String::from_utf8_lossy(&out.stdout).trim().to_string())
    };
    Ok(format!("{}:{}", id("-u").await?, id("-g").await?))
}

/// Makes every directory under `dir` (included) mode 0777 and every file 0666.
fn make_world_writable(dir: &Path) -> Result<()> {
    fs::set_permissions(dir, fs::Permissions::from_mode(0o777))?;
    for entry in fs::read_dir(dir)? {
        let path = entry?.path();
        if path.is_dir() {
            make_world_writable(&path)?;
        } else {
            fs::set_permissions(&path, fs::Permissions::from_mode(0o666))?;
        }
    }
    Ok(())
}
