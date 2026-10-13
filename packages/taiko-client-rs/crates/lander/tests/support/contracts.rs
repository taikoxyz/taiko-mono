//! Deploy the pinned real Inbox, registry and SignalService, without planting their storage.

use abci::{
    ChainParams, CommitteeState, GenesisRecord, RegistryEntry, Schedule, Snapshot,
    committee::{committee_config_hash, derive, record_hash},
};
use alloy::{
    rpc::types::TransactionRequest,
    sol,
    sol_types::{SolCall, SolConstructor},
};
use alloy_consensus::Header;
use alloy_eips::BlockId;
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result, ensure};
use ed25519_dalek::SigningKey;
use test_harness::{StandaloneAnvil, dev_signer, mine_l1_blocks};

sol!(EtnaInbox, "../../crates/lander/tests/fixtures/contracts/EtnaInbox.json");
sol!(EtnaStakingRegistry, "../../crates/lander/tests/fixtures/contracts/EtnaStakingRegistry.json");
sol!(SignalService, "../../crates/lander/tests/fixtures/contracts/SignalService.json");
sol!(ERC1967Proxy, "../../crates/lander/tests/fixtures/contracts/ERC1967Proxy.json");
sol!(
    MockLandProofVerifier,
    "../../crates/lander/tests/fixtures/contracts/MockLandProofVerifier.json"
);
sol!(TestERC20, "../../crates/lander/tests/fixtures/contracts/TestERC20.json");

/// Known ephemeral Ed25519 seed used only in these throw-away integration fixtures.
pub const CONSENSUS_SEED: [u8; 32] = [0x19; 32];
/// Effective stake: one TAIKO, with default devnet power mapping.
pub const STAKE: u128 = 1_000_000_000_000_000_000;
/// The devnet chain id accepted by builtin client configuration.
pub const L2_CHAIN_ID: u64 = 167001;
/// Epoch length is small enough for a cross-epoch actual-contract scenario.
pub const EPOCH_LEN: u64 = 8;
/// Forced inclusion delay installed at genesis, in seconds.
pub const FORCED_INCLUSION_DELAY: u64 = 3_600;
/// Maximum anchor age installed at genesis, in seconds.
pub const MAX_ANCHOR_AGE: u64 = 7_200;

/// An actual deployed protocol instance on one disposable Osaka anvil.
pub struct ContractFixture {
    pub anvil: StandaloneAnvil,
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
}

impl ContractFixture {
    /// Deploy all real contracts and initialize the genesis checkpoint through the real proxy.
    pub async fn deploy() -> Result<Self> {
        let anvil = StandaloneAnvil::start().await?;
        let p = &anvil.provider;
        let owner = dev_signer().address();
        let admin = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8".parse()?;
        let parent_header = Header {
            state_root: B256::repeat_byte(0x31),
            timestamp: 1,
            gas_limit: 45_000_000,
            base_fee_per_gas: Some(1_000_000_000),
            ..Default::default()
        };
        let genesis_hash = parent_header.hash_slow();
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
                _taikoToken: token,
                _minStake: U256::from(STAKE),
                _activationDelay: 0,
                _exitDelay: 20,
                _withdrawalDelay: 30,
                _heartbeatWindow: u64::MAX / 2,
                _churnWindow: 0,
                _churnBps: 0,
                _minChurnPerWindow: U256::ZERO,
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
        transact(
            p,
            owner,
            token,
            TestERC20::mintCall { to: owner, amount: U256::from(STAKE) }.abi_encode(),
        )
        .await?;
        transact(
            p,
            owner,
            token,
            TestERC20::approveCall { spender: registry, amount: U256::from(STAKE) }.abi_encode(),
        )
        .await?;
        let pubkey = B256::from(SigningKey::from_bytes(&CONSENSUS_SEED).verifying_key().to_bytes());
        let registered = transact(
            p,
            owner,
            registry,
            EtnaStakingRegistry::registerCall { _pubkey: pubkey, _amount: U256::from(STAKE) }
                .abi_encode(),
        )
        .await?;
        let register_block = registered.block_number.context("registration receipt block")?;
        let heartbeat = transact(
            p,
            owner,
            registry,
            EtnaStakingRegistry::heartbeatCall { _bondId: U256::ZERO }.abi_encode(),
        )
        .await?;
        let cutoff = heartbeat.block_number.context("heartbeat receipt block")?;
        let verifier = deploy(
            p,
            owner,
            include_str!("../fixtures/contracts/MockLandProofVerifier.json"),
            Vec::new(),
        )
        .await?;
        let next_nonce = p.get_transaction_count(owner).await?;
        let predicted_inbox = owner.create(next_nonce + 3);
        let signal_impl = deploy(
            p,
            owner,
            include_str!("../fixtures/contracts/SignalService.json"),
            SignalService::constructorCall {
                authorizedSyncer: predicted_inbox,
                remoteSignalService: Address::repeat_byte(0xdd),
                _pauser: Address::ZERO,
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
                },
            }
            .abi_encode(),
        )
        .await?;
        let params = ChainParams::builtin(L2_CHAIN_ID)?.with_overrides(&format!(
            "inbox = \"{predicted_inbox}\"\nregistry = \"{registry}\"\nd_max = 5\nmargin_v = 0\n"
        ))?;
        let schedule =
            Schedule { l1_0: 0, epoch_len: EPOCH_LEN, epoch_len_l1: 1, genesis_cutoff: cutoff };
        let entry = RegistryEntry {
            pubkey,
            eff_stake: U256::from(STAKE),
            active_from_l1: register_block,
            exit_effective_l1: u64::MAX,
            last_heartbeat_at: 0,
            last_heartbeat_seq: 1,
        };
        let snapshot =
            Snapshot { checkpoint_index: 1, l1_block: cutoff, entries: vec![entry.clone()] };
        let (record, members) = derive(&snapshot, cutoff, 0, &schedule, &params)?;
        let committee = CommitteeState { record, members };
        let input = IEtnaInbox::GenesisParams {
            genesisBlockHash: genesis_hash,
            genesisStateRoot: parent_header.state_root,
            epochLenL2: EPOCH_LEN,
            epochLenL1: 1,
            genesisCutoff: cutoff,
            committeeRecordHash: record_hash(L2_CHAIN_ID, &committee.record),
            committeeConfigHash: committee_config_hash(&params),
            forcedInclusionDelay: FORCED_INCLUSION_DELAY,
            maxAnchorAge: MAX_ANCHOR_AGE,
        };
        let inbox = proxy(
            p,
            owner,
            inbox_impl,
            EtnaInbox::initCall { _owner: owner, _params: input }.abi_encode().into(),
        )
        .await?;
        ensure!(inbox == predicted_inbox, "CREATE-predicted authorized syncer differs");
        let activated = view(p, inbox, EtnaInbox::activationCall {}, None).await?;
        let genesis = GenesisRecord {
            committee_config_hash: committee_config_hash(&params),
            genesis_height: 0,
            l1_0: activated.l1Block,
            epoch_len: EPOCH_LEN,
            epoch_len_l1: 1,
            genesis_hash,
            genesis_state_root: parent_header.state_root,
            genesis_cutoff: cutoff,
            forced_inclusion_delay: FORCED_INCLUSION_DELAY,
            max_anchor_age: MAX_ANCHOR_AGE,
        };
        mine_l1_blocks(p, 3).await?;
        ensure!(
            Self::checkpoint_at(p, inbox).await? == (0, genesis_hash),
            "real proxy genesis checkpoint"
        );
        Ok(Self {
            anvil,
            inbox,
            registry,
            signal,
            verifier,
            admin,
            params,
            genesis,
            parent_header,
            committee,
            entry,
        })
    }

    /// Latest real Inbox checkpoint, decoded through its ABI getter.
    pub async fn checkpoint(&self) -> Result<(u64, B256)> {
        Self::checkpoint_at(&self.anvil.provider, self.inbox).await
    }

    async fn checkpoint_at(provider: &RootProvider, inbox: Address) -> Result<(u64, B256)> {
        let value = view(provider, inbox, EtnaInbox::lastCheckpointCall {}, None).await?;
        Ok((value.height, value.blockHash))
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

    /// Require the verifier to receive this exact V6 public statement.
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
) -> Result<alloy::rpc::types::TransactionReceipt> {
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
pub async fn receipt(
    provider: &RootProvider,
    hash: B256,
) -> Result<alloy::rpc::types::TransactionReceipt> {
    test_harness::wait_until(
        "actual-contract transaction receipt",
        std::time::Duration::from_secs(20),
        std::time::Duration::from_millis(25),
        || async { Ok(provider.get_transaction_receipt(hash).await?) },
    )
    .await
}
