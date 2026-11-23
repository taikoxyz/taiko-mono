//! Deploy the pinned real Inbox and SignalService, without planting their storage.

use abci::{ChainParams, ChainParamsExt, GenesisRecord, fallback::FallbackKeys};
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
sol!(MockUnzenInbox, "../../crates/lander/tests/fixtures/contracts/MockUnzenInbox.json");

/// The devnet chain id accepted by builtin client configuration.
pub const L2_CHAIN_ID: u64 = 167001;
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
    pub signal: Address,
    pub verifier: Address,
    pub admin: Address,
    pub params: ChainParams,
    pub genesis: GenesisRecord,
    pub parent_header: Header,
    /// Generation 0's origin fallback key list, the signer-generated keys: `init` stores it and
    /// its hash (slot 278). With `minTotalStake` at its maximum and no L2 staking contract, these
    /// keys sign every block, each at power 1.
    pub fallback_keys: FallbackKeys,
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

    /// Creates keys exactly once with the shipped signer CLI; they are the fallback keys.
    pub async fn deploy_validators(count: usize) -> Result<Self> {
        Self::deploy_config(count, 120).await
    }

    /// `count` fallback keys and the unsettled limit U.
    pub async fn deploy_config(count: usize, unsettled_limit: u64) -> Result<Self> {
        Self::deploy_network(count, unsettled_limit, None).await
    }

    /// A switching network (START-10-5): the EtnaInbox names a mock live Unzen Inbox and an
    /// `ETNA_FORK_TIME` `fork_after` seconds after the current L1 time, and its initialization
    /// leaves the start unwritten until the permissionless `setOrigin(S)`. `genesis` describes
    /// that unwritten start (height 0, zero hash and root); the chain parameters carry the
    /// matching `[switch]` configuration.
    pub async fn deploy_switching(fork_after: u64) -> Result<(Self, Switching)> {
        Self::deploy_network(1, 120, Some(fork_after)).await.map(|fixture| {
            let switch = fixture.params.switch.as_ref().expect("switching parameters");
            let switching =
                Switching { unzen: switch.unzen_inbox, fork_time: switch.fork_timestamp };
            (fixture, switching)
        })
    }

    async fn deploy_network(
        count: usize,
        unsettled_limit: u64,
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
        let l1_chain_id: U256 = p.raw_request("eth_chainId".into(), ()).await?;
        let signer_storage = tempfile::Builder::new().prefix("etna-signer-").tempdir_in("/tmp")?;
        let binary = test_harness::signer_binary()?;
        let mut keys = Vec::new();
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
            keys.push(ValidatorKey::from_file(&key_file)?);
        }
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
            l1_chain_id,
            unsettled_limit,
            fee_recipient: Address::repeat_byte(0x77),
            switch: switch.clone(),
            ..ChainParams::builtin(L2_CHAIN_ID)?
        };
        // The generated keys are generation 0's fallback keys, each at power 1.
        let mut origin_keys: Vec<_> = keys.iter().map(|key| key.pubkey()).collect();
        origin_keys.sort();
        let fallback_keys = FallbackKeys::new(origin_keys)?;
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
                    // The configuration hash binds the L2 staking proxy the client reads.
                    etnaStaking: params.staking,
                    l2ChainId: L2_CHAIN_ID,
                    maxBatchBlocks: 1000,
                    forcedInclusionFeeInGwei: 1,
                    forcedInclusionFeeDoubleThreshold: 50,
                    protocolFeeRecipient: admin,
                    unsettledLimit: params.unsettled_limit,
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
            fallbackKeys: fallback_keys
                .keys()
                .iter()
                .map(|key| IEtnaInbox::FallbackKey { ckPrefix: key.prefix(), ckX: key.x() })
                .collect(),
            // No candidate is ever usable: the fallback keys sign every block.
            minTotalStake: U256::MAX,
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
            signal,
            verifier,
            admin,
            params,
            genesis,
            parent_header,
            fallback_keys,
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

    /// The DAO's `setMinTotalStake(value)` on the real Inbox, from its owner; returns the L1 block
    /// that holds it.
    pub async fn set_min_total_stake(&self, value: U256) -> Result<u64> {
        let p = &self.anvil.provider;
        let owner = view(p, self.inbox, EtnaInbox::ownerCall {}, None).await?;
        let call = EtnaInbox::setMinTotalStakeCall { _value: value };
        let receipt = transact(p, owner, self.inbox, call.abi_encode()).await?;
        ensure!(
            view(p, self.inbox, EtnaInbox::minTotalStakeCall {}, None).await? == value,
            "setMinTotalStake did not store {value}"
        );
        receipt.block_number.context("setMinTotalStake receipt without a block")
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
