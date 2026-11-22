//! Deploy the pinned real Inbox, registry and SignalService, without planting their
//! storage.

// Current generated registry ABI includes an eight-field event constructor.
#![allow(clippy::too_many_arguments)]

use abci::{
    ChainParams, CommitteeRecord, CommitteeState, GenesisRecord, Member, RegistryEntry,
    fallback::FallbackKeys,
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
use std::process::Command;
use test_harness::{StandaloneAnvil, StandaloneReth, ValidatorKey, dev_signer, mine_l1_blocks};

sol!(EtnaInboxBootstrap, "../../crates/lander/tests/fixtures/contracts/EtnaInboxBootstrap.json");
sol!(EtnaInbox, "../../crates/lander/tests/fixtures/contracts/EtnaInbox.json");
sol!(EtnaStakingRegistry, "../../crates/lander/tests/fixtures/contracts/EtnaStakingRegistry.json");
/// Kept apart from EtnaInbox: both ABIs declare `ICheckpointStore`, which the Inbox's
/// `saveCheckpoint` takes.
mod signal_service {
    alloy::sol!(SignalService, "../../crates/lander/tests/fixtures/contracts/SignalService.json");
}
pub use signal_service::SignalService;
sol!(ERC1967Proxy, "../../crates/lander/tests/fixtures/contracts/ERC1967Proxy.json");
sol!(
    MockLandProofVerifier,
    "../../crates/lander/tests/fixtures/contracts/MockLandProofVerifier.json"
);
sol!(TestERC20, "../../crates/lander/tests/fixtures/contracts/TestERC20.json");
sol!(MockUnzenInbox, "../../crates/lander/tests/fixtures/contracts/MockUnzenInbox.json");

/// Each fixture bond's stake and the registry's `minStake`: 7,600,000 TAIKO, the devnet
/// default (`DEFAULT_REGISTRY_MIN_STAKE`) and the built-in `min_stake`. The registry constructor
/// requires `4096 * minStake > 10^27` (more than 244,140.625 TAIKO). The default devnet power
/// mapping gives each entry 7.6 * 10^15 voting power.
pub const STAKE: u128 = 7_600_000 * 10u128.pow(18);
/// The Inbox's recovery capacity F: the devnet deployment default (`DEFAULT_RECOVERY_CAPACITY`),
/// the measured largest exclusion count whose worst-case `recover` fits the L1 per-transaction gas
/// cap. `init` requires `K = floor(10^27 / minStake) <= F` (START-10-14), 131 at [`STAKE`].
pub const RECOVERY_CAPACITY: u16 = 131;
/// The devnet chain id accepted by builtin client configuration.
pub const L2_CHAIN_ID: u64 = 167001;
/// Accelerated canonical epoch: D(1)=12, S(1)=13, H(1)=15.
pub const EPOCH_LEN: u64 = 14;
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
    /// Generation 0's origin fallback key list, the registered keys: its hash is at slot 278.
    pub fallback_keys: FallbackKeys,
    pub entry: RegistryEntry,
    pub keys: Vec<ValidatorKey>,
    pub signer_storage: tempfile::TempDir,
    /// On a switching deployment ([`ContractFixture::deploy_switching`]), the mock live Unzen
    /// Inbox the EtnaInbox reads `proposeCutoff()` and `getCoreState()` from; `None` on a new
    /// network.
    pub unzen: Option<Address>,
}

/// A switching deployment's Unzen side: the mock Unzen Inbox address and `ETNA_FORK_TIME`.
#[derive(Clone, Copy, Debug)]
pub struct Switching {
    /// The mock live Unzen Inbox, the only caller the checkpoint forwarder accepts.
    pub unzen: Address,
    /// `ETNA_FORK_TIME` in L1 Unix seconds.
    pub fork_time: u64,
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
        Self::deploy_committee_config(count, unsettled_limit, epoch_len, 128).await
    }

    /// Authenticates a bounded committee cap so registered standby keys can enter after recovery.
    pub async fn deploy_committee_config(
        count: usize,
        unsettled_limit: u64,
        epoch_len: u64,
        n_max: usize,
    ) -> Result<Self> {
        Self::deploy_network(count, unsettled_limit, epoch_len, n_max, None).await
    }

    /// A switching network (START-10-5): the EtnaInbox names a mock live Unzen Inbox and an
    /// `ETNA_FORK_TIME` `fork_after` seconds after the current L1 time, and its initialization
    /// leaves the start unwritten until the permissionless `setOrigin(S)`. `genesis` describes
    /// that unwritten start (height 0, zero hash and root); the chain parameters carry the
    /// matching `[switch]` configuration.
    pub async fn deploy_switching(fork_after: u64) -> Result<(Self, Switching)> {
        Self::deploy_network(1, 120, EPOCH_LEN, 128, Some(fork_after)).await.map(|fixture| {
            let switch = fixture.params.switch.as_ref().expect("switching parameters");
            let switching =
                Switching { unzen: switch.unzen_inbox, fork_time: switch.fork_timestamp };
            (fixture, switching)
        })
    }

    async fn deploy_network(
        count: usize,
        unsettled_limit: u64,
        epoch_len: u64,
        n_max: usize,
        switching: Option<u64>,
    ) -> Result<Self> {
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
                    forfeitBps: U256::from(1000),
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
        let signer_storage = tempfile::Builder::new().prefix("etna-signer-").tempdir_in("/tmp")?;
        let binary = test_harness::signer_binary()?;
        let mut keys = Vec::new();
        let mut entries = Vec::new();
        for i in 0..count {
            // An operator's bootstrap: the key, then the domains log. Consensus start runs
            // `init-state` once the genesis chain ID is known.
            let dir = signer_storage.path().join(i.to_string());
            std::fs::create_dir(&dir)?;
            let key_file = dir.join("key.json");
            let generated =
                Command::new(&binary).arg("keygen").arg("--priv-key").arg(&key_file).output()?;
            ensure!(
                generated.status.success(),
                "explicit keygen failed: {}",
                String::from_utf8_lossy(&generated.stderr)
            );
            test_harness::init_signer_domains_log(&dir)?;
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
        let unzen = match switching {
            Some(_) => Some(
                deploy(p, owner, include_str!("../fixtures/contracts/MockUnzenInbox.json"), vec![])
                    .await?,
            ),
            None => None,
        };
        let now = p
            .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
            .await?
            .context("L1 head")?
            .header
            .timestamp;
        let switch = match (unzen, switching) {
            (Some(unzen_inbox), Some(fork_after)) => Some(abci::SwitchConfig {
                unzen_inbox,
                fork_timestamp: now + fork_after,
                // L1-side scenarios read no L2 SignalService or staking implementation.
                signal_service_implementation: Address::repeat_byte(0x5e),
                staking_implementation: Address::repeat_byte(0x5f),
            }),
            _ => None,
        };
        let params = ChainParams {
            inbox,
            registry,
            l1_chain_id,
            unsettled_limit,
            n_max,
            fee_recipient: Address::repeat_byte(0x77),
            switch: switch.clone(),
            ..ChainParams::builtin(L2_CHAIN_ID)?
        };
        // The registered keys are generation 0's fallback keys, each at power 1. The pinned
        // contracts predate fallback keys: their `committeeRecordHash` lands at slot 278, so it
        // takes the list's hash.
        let mut origin_keys: Vec<_> = keys.iter().map(|key| key.pubkey()).collect();
        origin_keys.sort();
        let fallback_keys = FallbackKeys::new(origin_keys)?;
        let members: Vec<Member> = fallback_keys
            .keys()
            .iter()
            .map(|key| Member { pubkey: *key, eff_stake: U256::ZERO, power: 1 })
            .collect();
        let record = CommitteeRecord {
            target_epoch: 0,
            cutoff_l1_block: cutoff,
            checkpoint_index: 0,
            set_hash: B256::ZERO,
            total_power: members.len() as u64,
        };
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
                // False on L1 (START-10-5).
                _usesBeaconRoots: false,
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
                    unzenInbox: unzen.unwrap_or_default(),
                    etnaForkTime: switch
                        .as_ref()
                        .map_or(0, |switch| switch.fork_timestamp)
                        .try_into()?,
                    proofVerifier: verifier,
                    signalService: signal,
                    stakingRegistry: registry,
                    l2ChainId: L2_CHAIN_ID,
                    maxBatchBlocks: 1000,
                    forcedInclusionFeeInGwei: 1,
                    forcedInclusionFeeDoubleThreshold: 50,
                    protocolFeeRecipient: admin,
                    recoveryCapacity: RECOVERY_CAPACITY,
                },
            }
            .abi_encode(),
        )
        .await?;
        // A switching network leaves the start to `setOrigin` (START-10-5a).
        let (start_hash, start_root) = if switch.is_some() {
            (B256::ZERO, B256::ZERO)
        } else {
            (genesis_hash, parent_header.state_root)
        };
        let input = IEtnaInbox::InitParams {
            genesisBlockHash: start_hash,
            genesisStateRoot: start_root,
            epochLenL2: U256::from(epoch_len),
            genesisCutoff: U256::from(cutoff),
            committeeRecordHash: fallback_keys.hash(),
            committeeConfig: IEtnaInbox::CommitteeConfig {
                vpUnit: params.vp_unit,
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
            config_hash: params.config_hash(),
            genesis_height: 0,
            l1_0: initialized.block_number.context("owner init block")?,
            genesis_hash: start_hash,
            genesis_state_root: start_root,
            forced_inclusion_delay: FORCED_INCLUSION_DELAY,
            max_anchor_age: MAX_ANCHOR_AGE,
        };
        mine_l1_blocks(p, 3).await?;
        ensure!(Self::checkpoint_at(p, inbox).await? == (0, start_hash), "real proxy checkpoint");
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
            fallback_keys,
            entry: entries[0].clone(),
            keys,
            signer_storage,
            unzen,
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
