//! Deploy the pinned real Inbox, registry and SignalService, without planting their
//! storage.

// Current generated registry ABI includes an eight-field event constructor.
#![allow(clippy::too_many_arguments)]

use abci::{
    ChainParams, CommitteeState, GenesisRecord, RegistryEntry, Snapshot,
    committee::{committee_config_hash, derive, record_hash},
};
use alloy::{
    rpc::types::{TransactionReceipt, TransactionRequest},
    signers::{SignerSync, local::PrivateKeySigner},
    sol,
    sol_types::{SolCall, SolConstructor},
};
use alloy_consensus::{Header, SignableTransaction, TxEnvelope};
use alloy_eips::{BlockId, eip2718::Encodable2718};
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result, ensure};
use std::{path::PathBuf, process::Command};
use test_harness::{StandaloneAnvil, StandaloneReth, ValidatorKey, dev_signer, mine_l1_blocks};

sol!(EtnaInboxBootstrap, "../../crates/lander/tests/fixtures/contracts/EtnaInboxBootstrap.json");
sol!(EtnaInbox, "../../crates/lander/contracts/EtnaInbox.json");
sol!(EtnaStakingRegistry, "../../crates/lander/tests/fixtures/contracts/EtnaStakingRegistry.json");
sol!(SignalService, "../../crates/lander/tests/fixtures/contracts/SignalService.json");
sol!(ERC1967Proxy, "../../crates/lander/tests/fixtures/contracts/ERC1967Proxy.json");
sol!(
    MockLandProofVerifier,
    "../../crates/lander/tests/fixtures/contracts/MockLandProofVerifier.json"
);
sol!(TestERC20, "../../crates/lander/tests/fixtures/contracts/TestERC20.json");

/// Effective stake: one TAIKO, with default devnet power mapping.
pub const STAKE: u128 = 1_000_000_000_000_000_000;
/// The devnet chain id accepted by builtin client configuration.
pub const L2_CHAIN_ID: u64 = 167001;
/// Accelerated epoch length with D(1)=12 on the legal K=6 landing grid.
pub const EPOCH_LEN: u64 = 15;
/// Forced inclusion delay installed at genesis, in seconds.
pub const FORCED_INCLUSION_DELAY: u64 = 3_600;
/// Maximum anchor age installed at genesis, in seconds.
pub const MAX_ANCHOR_AGE: u64 = 7_200;
/// Anvil's third development key: a forced inclusion user, neither the lander nor the admin.
pub const USER_KEY: &str = "5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";
/// An actual deployed protocol instance on one disposable Osaka anvil.
pub struct ContractFixture {
    pub anvil: StandaloneAnvil,
    pub l2: StandaloneReth,
    pub inbox: Address,
    pub registry: Address,
    pub signal: Address,
    pub verifier: Address,
    pub admin: Address,
    pub params: ChainParams,
    pub genesis: GenesisRecord,
    pub parent_header: Header,
    pub committee: CommitteeState,
    pub entry: RegistryEntry,
    pub keys: Vec<ValidatorKey>,
    pub signer_storage: tempfile::TempDir,
}

impl ContractFixture {
    /// Deploy the real contracts and initialize the genesis checkpoint through the real proxy.
    pub async fn deploy() -> Result<Self> {
        Self::deploy_validators(1).await
    }

    /// Creates keys exactly once with the shipped signer CLI and registers actual PoPs.
    pub async fn deploy_validators(count: usize) -> Result<Self> {
        Self::deploy_config(count, 120, EPOCH_LEN).await
    }

    pub async fn deploy_config(count: usize, unsettled_limit: u64, epoch_len: u64) -> Result<Self> {
        let anvil = StandaloneAnvil::start().await?;
        let p = &anvil.provider;
        let owner = dev_signer().address();
        let admin = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8".parse()?;
        let bootstrap =
            deploy(p, owner, include_str!("../fixtures/contracts/EtnaInboxBootstrap.json"), vec![])
                .await?;
        let inbox = proxy(
            p,
            owner,
            bootstrap,
            EtnaInboxBootstrap::initCall { _owner: owner }.abi_encode().into(),
        )
        .await?;
        let token = deploy(
            p,
            owner,
            include_str!("../fixtures/contracts/TestERC20.json"),
            TestERC20::constructorCall { name: "Taiko fixture".into(), symbol: "TAIKO".into() }
                .abi_encode(),
        )
        .await?;
        let registry_impl = deploy(
            p,
            owner,
            include_str!("../fixtures/contracts/EtnaStakingRegistry.json"),
            EtnaStakingRegistry::constructorCall {
                _config: IEtnaStakingRegistry::Config {
                    token,
                    minStake: U256::from(STAKE),
                    activationDelay: U256::from(1),
                    exitDelay: U256::from(20),
                    withdrawalDelay: U256::from(30),
                    slashBountyBps: U256::ZERO,
                    slashSink: admin,
                    l2ChainId: L2_CHAIN_ID,
                    inbox,
                },
            }
            .abi_encode(),
        )
        .await?;
        let registry = proxy(
            p,
            owner,
            registry_impl,
            EtnaStakingRegistry::initCall { _owner: owner }.abi_encode().into(),
        )
        .await?;
        let amount = U256::from(STAKE) * U256::from(count);
        transact(p, owner, token, TestERC20::mintCall { to: owner, amount }.abi_encode()).await?;
        transact(
            p,
            owner,
            token,
            TestERC20::approveCall { spender: registry, amount }.abi_encode(),
        )
        .await?;
        let l1_chain_id: U256 = p.raw_request("eth_chainId".into(), ()).await?;
        let signer_storage =
            tempfile::Builder::new().prefix("etna-authority-").tempdir_in("/tmp")?;
        let binary = std::env::var_os("ETNA_SIGNER_BIN").map(PathBuf::from).unwrap_or_else(|| {
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../target/etna-signer/etna-signer")
        });
        let mut keys = Vec::new();
        let mut entries = Vec::new();
        for i in 0..count {
            let dir = signer_storage.path().join(i.to_string());
            std::fs::create_dir(&dir)?;
            let key_file = dir.join("key.json");
            let state_file = dir.join("state.json");
            let generated = Command::new(&binary)
                .arg("keygen")
                .arg("--priv-key")
                .arg(&key_file)
                .arg("--priv-state")
                .arg(&state_file)
                .output()?;
            ensure!(
                generated.status.success(),
                "explicit keygen failed: {}",
                String::from_utf8_lossy(&generated.stderr)
            );
            if count == 4 {
                eprintln!(
                    "ACCEPTANCE keygen node={i} {}",
                    String::from_utf8_lossy(&generated.stdout).trim()
                );
            }
            let key = ValidatorKey::from_file(&key_file)?;
            let proof = Command::new(&binary)
                .arg("pop")
                .arg("--priv-key")
                .arg(&key_file)
                .args([
                    "--owner",
                    &owner.to_string(),
                    "--registry",
                    &registry.to_string(),
                    "--l1-chain-id",
                    &l1_chain_id.to_string(),
                ])
                .output()?;
            ensure!(proof.status.success(), "registration PoP failed");
            let pop: serde_json::Value = serde_json::from_slice(&proof.stdout)?;
            if count == 4 {
                eprintln!("ACCEPTANCE pop node={i} {pop}");
            }
            let registered = transact(
                p,
                owner,
                registry,
                EtnaStakingRegistry::registerCall {
                    _publicKey: Bytes::copy_from_slice(key.pubkey().as_bytes()),
                    _amount: U256::from(STAKE),
                    _popSig: pop["signature"].as_str().context("PoP signature")?.parse()?,
                }
                .abi_encode(),
            )
            .await?;
            let public_key = key.pubkey();
            let bytes = public_key.as_bytes();
            entries.push(RegistryEntry {
                ck_prefix: bytes[0],
                ck_x: B256::from_slice(&bytes[1..]),
                eff_stake: U256::from(STAKE),
                active_from_l1: registered.block_number.context("registration block")? + 1,
                exit_effective_l1: (1u64 << 48) - 1,
            });
            keys.push(key);
        }
        mine_l1_blocks(p, 3).await?;
        let cutoff = test_harness::finalized_number(p).await?;
        let params = ChainParams {
            inbox,
            registry,
            l1_chain_id,
            unsettled_limit,
            fee_recipient: Address::repeat_byte(0x77),
            ..ChainParams::builtin(L2_CHAIN_ID)?
        };
        let snapshot = Snapshot {
            checkpoint_index: count as u64 - 1,
            l1_block: cutoff,
            entries: entries.clone(),
        };
        let (record, members) = derive(&snapshot, cutoff, 0, &params)?;
        let committee = CommitteeState { record, members };
        let l2 = StandaloneReth::start().await?;
        let parent_header = l2
            .provider
            .get_block_by_number(alloy_eips::BlockNumberOrTag::Number(0))
            .await?
            .context("EL genesis")?
            .header
            .inner;
        let genesis_hash = parent_header.hash_slow();
        let verifier = deploy(
            p,
            owner,
            include_str!("../fixtures/contracts/MockLandProofVerifier.json"),
            vec![],
        )
        .await?;
        let signal_impl = deploy(
            p,
            owner,
            include_str!("../fixtures/contracts/SignalService.json"),
            SignalService::constructorCall {
                authorizedSyncer: inbox,
                remoteSignalService: Address::repeat_byte(0xdd),
                _pauser: owner,
            }
            .abi_encode(),
        )
        .await?;
        let signal = proxy(
            p,
            owner,
            signal_impl,
            SignalService::initCall { _owner: owner }.abi_encode().into(),
        )
        .await?;
        let inbox_impl = deploy(
            p,
            owner,
            include_str!("../fixtures/contracts/EtnaInbox.json"),
            EtnaInbox::constructorCall {
                _config: IEtnaInbox::Config {
                    proofVerifier: verifier,
                    signalService: signal,
                    stakingRegistry: registry,
                    l2ChainId: L2_CHAIN_ID,
                    maxBatchBlocks: 1000,
                    forcedInclusionFeeInGwei: 1,
                    forcedInclusionFeeDoubleThreshold: 50,
                    protocolFeeRecipient: admin,
                },
            }
            .abi_encode(),
        )
        .await?;
        let input = IEtnaInbox::InitParams {
            genesisBlockHash: genesis_hash,
            genesisStateRoot: parent_header.state_root,
            epochLenL2: U256::from(epoch_len),
            genesisCutoff: U256::from(cutoff),
            committeeRecordHash: record_hash(L2_CHAIN_ID, &committee.record),
            committeeConfig: IEtnaInbox::CommitteeConfig {
                vpUnit: params.vp_unit,
                sMin: params.s_min,
                nMax: U256::from(params.n_max),
                unsettledLimit: U256::from(params.unsettled_limit),
            },
            forcedInclusionDelay: U256::from(FORCED_INCLUSION_DELAY),
            maxAnchorAge: U256::from(MAX_ANCHOR_AGE),
        };
        let initialized = transact(
            p,
            owner,
            inbox,
            EtnaInbox::upgradeToAndCallCall {
                _newImplementation: inbox_impl,
                _data: EtnaInbox::initCall { _params: input }.abi_encode().into(),
            }
            .abi_encode(),
        )
        .await?;
        let genesis = GenesisRecord {
            committee_config_hash: committee_config_hash(&params),
            genesis_height: 0,
            l1_0: initialized.block_number.context("owner init block")?,
            epoch_len,
            genesis_hash,
            genesis_state_root: parent_header.state_root,
            genesis_cutoff: cutoff,
            forced_inclusion_delay: FORCED_INCLUSION_DELAY,
            max_anchor_age: MAX_ANCHOR_AGE,
        };
        mine_l1_blocks(p, 3).await?;
        ensure!(Self::checkpoint_at(p, inbox).await? == (0, genesis_hash), "real proxy checkpoint");
        Ok(Self {
            anvil,
            l2,
            inbox,
            registry,
            signal,
            verifier,
            admin,
            params,
            genesis,
            parent_header,
            committee,
            entry: entries[0].clone(),
            keys,
            signer_storage,
        })
    }

    /// Latest real Inbox checkpoint, decoded through its ABI getter.
    pub async fn checkpoint(&self) -> Result<(u64, B256)> {
        Self::checkpoint_at(&self.anvil.provider, self.inbox).await
    }

    async fn checkpoint_at(provider: &RootProvider, inbox: Address) -> Result<(u64, B256)> {
        let value = view(provider, inbox, EtnaInbox::lastCheckpointCall {}, None).await?;
        Ok((value.height.to(), value.blockHash))
    }

    /// Select whether the pinned proof verifier rejects the dummy proof.
    pub async fn set_rejects(&self, rejects: bool) -> Result<()> {
        transact(
            &self.anvil.provider,
            self.admin,
            self.verifier,
            MockLandProofVerifier::setRejectsCall { _rejects: rejects }.abi_encode(),
        )
        .await
        .map(drop)
    }

    /// The Inbox's forced inclusion queue `(head, tail)`.
    pub async fn forced_inclusion_state(&self) -> Result<(u64, u64)> {
        let state =
            view(&self.anvil.provider, self.inbox, EtnaInbox::getForcedInclusionStateCall {}, None)
                .await?;
        Ok((state.head_.to(), state.tail_.to()))
    }

    /// Calls `saveForcedInclusion` from [`USER_KEY`] and pays exactly the current fee.
    /// Returns the receipt, the exact admitted transaction bytes and the fee in wei.
    pub async fn save_forced_inclusion(
        &self,
        payload: &[u8],
    ) -> Result<(TransactionReceipt, Bytes, U256)> {
        let p = &self.anvil.provider;
        let fee_gwei =
            view(p, self.inbox, EtnaInbox::getCurrentForcedInclusionFeeCall {}, None).await?;
        let fee = U256::from(fee_gwei) * U256::from(1_000_000_000u64);
        let signer: PrivateKeySigner = USER_KEY.parse()?;
        let tx = alloy_consensus::TxEip1559 {
            chain_id: p.get_chain_id().await?,
            nonce: p.get_transaction_count(signer.address()).await?,
            gas_limit: 1_000_000,
            max_fee_per_gas: 20_000_000_000,
            max_priority_fee_per_gas: 1_000_000_000,
            to: alloy_primitives::TxKind::Call(self.inbox),
            value: fee,
            input: EtnaInbox::saveForcedInclusionCall { _tx: Bytes::copy_from_slice(payload) }
                .abi_encode()
                .into(),
            access_list: Default::default(),
        };
        let signature = signer.sign_hash_sync(&tx.signature_hash())?;
        let network = TxEnvelope::Eip1559(tx.into_signed(signature)).encoded_2718();
        let hash = *p.send_raw_transaction(&network).await?.tx_hash();
        let blob = Bytes::copy_from_slice(payload);
        let saved = receipt(p, hash).await?;
        ensure!(saved.status(), "saveForcedInclusion reverted: {hash}");
        Ok((saved, blob, fee))
    }

    /// Require the verifier to receive this exact V10 public statement.
    pub async fn expect_statement(&self, hash: B256) -> Result<()> {
        transact(
            &self.anvil.provider,
            self.admin,
            self.verifier,
            MockLandProofVerifier::setExpectedStatementHashCall { _statementHash: hash }
                .abi_encode(),
        )
        .await
        .map(drop)
    }
}

/// Submit one call from an unlocked ephemeral anvil account; production landing uses local signing.
pub async fn transact(
    provider: &RootProvider,
    sender: Address,
    to: Address,
    input: Vec<u8>,
) -> Result<TransactionReceipt> {
    let selector = alloy_primitives::hex::encode(input.get(..4).unwrap_or(&input));
    let mut request = TransactionRequest::default().from(sender).to(to).input(input.into());
    let estimate = provider
        .estimate_gas(request.clone())
        .await
        .with_context(|| format!("fixture call {to} selector {selector} estimate"))?;
    request.gas = Some(estimate.saturating_add(estimate / 5));
    let receipt = provider.send_transaction(request).await?.get_receipt().await?;
    ensure!(
        receipt.status(),
        "fixture call {to} selector {selector} reverted: {:?}",
        receipt.transaction_hash
    );
    Ok(receipt)
}

async fn proxy(
    provider: &RootProvider,
    sender: Address,
    implementation: Address,
    data: Bytes,
) -> Result<Address> {
    deploy(
        provider,
        sender,
        include_str!("../fixtures/contracts/ERC1967Proxy.json"),
        ERC1967Proxy::constructorCall { _logic: implementation, _data: data }.abi_encode(),
    )
    .await
}

async fn deploy(
    provider: &RootProvider,
    sender: Address,
    artifact: &str,
    constructor: Vec<u8>,
) -> Result<Address> {
    let value: serde_json::Value = serde_json::from_str(artifact)?;
    let mut code = value["bytecode"]["object"]
        .as_str()
        .context("artifact creation bytecode")?
        .parse::<Bytes>()?
        .to_vec();
    code.extend(constructor);
    let mut request = TransactionRequest::default().from(sender).input(code.into());
    let estimate = provider.estimate_gas(request.clone()).await?;
    request.gas = Some(estimate.saturating_add(estimate / 5));
    let receipt = provider.send_transaction(request).await?.get_receipt().await?;
    ensure!(receipt.status(), "fixture contract deployment reverted");
    receipt.contract_address.context("deployment receipt lacks contract address")
}

/// Decode an exact generated ABI call, optionally at one canonical L1 state hash.
pub async fn view<C: SolCall>(
    provider: &RootProvider,
    to: Address,
    call: C,
    pin: Option<BlockId>,
) -> Result<C::Return> {
    let request = TransactionRequest::default().to(to).input(call.abi_encode().into());
    let operation = provider.call(request);
    let bytes = match pin {
        Some(pin) => operation.block(pin).await?,
        None => operation.await?,
    };
    Ok(C::abi_decode_returns(&bytes)?)
}

/// Wait for asynchronous anvil mining to expose a receipt after raw broadcast.
pub async fn receipt(provider: &RootProvider, hash: B256) -> Result<TransactionReceipt> {
    test_harness::wait_until(
        "actual-contract transaction receipt",
        std::time::Duration::from_secs(20),
        std::time::Duration::from_millis(25),
        || async { Ok(provider.get_transaction_receipt(hash).await?) },
    )
    .await
}
