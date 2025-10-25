use std::str::FromStr;
use std::sync::Arc;

use alloy::network::{Ethereum, EthereumWallet};
use alloy::primitives::{Address, B256};
use alloy::providers::fillers::{
    BlobGasFiller, ChainIdFiller, FillProvider, GasFiller, JoinFill, NonceFiller, WalletFiller,
};
use alloy::providers::{Identity, ProviderBuilder, RootProvider};
use alloy::signers::local::PrivateKeySigner;
use alloy::signers::Signer;
use alloy::{hex, sol};
use anyhow::{anyhow, Context, Result};
use async_trait::async_trait;
use reqwest::Url;
use tracing::{info, warn};

use crate::types::{Preconfirmer, Violation};

/// Abstraction over the contract responsible for enforcing blacklists on-chain.
#[async_trait]
pub trait BlacklistContract: Send + Sync {
    /// Blacklists the preconfirmer on-chain using contextual violation details.
    async fn blacklist(&self, preconfirmer: &Preconfirmer, violation: &Violation) -> Result<()>;
}

sol! {
    #[derive(Debug)]
    #[sol(rpc)]
    contract IRegistryBlacklist {
        function overseers(address) external view returns (bool);
        function isOperatorBlacklisted(bytes32) external view returns (bool);
        function blacklistOperator(bytes32) external;
    }
}

type ProviderStack = JoinFill<
    JoinFill<
        JoinFill<
            Identity,
            JoinFill<GasFiller, JoinFill<BlobGasFiller, JoinFill<NonceFiller, ChainIdFiller>>>,
        >,
        ChainIdFiller,
    >,
    WalletFiller<EthereumWallet>,
>;

type HttpWalletProvider = FillProvider<ProviderStack, RootProvider<Ethereum>, Ethereum>;

type BlacklistInstance = IRegistryBlacklist::IRegistryBlacklistInstance<Arc<HttpWalletProvider>>;

/// On-chain implementation backed by Alloy providers and contract bindings.
pub struct OnchainBlacklistContract {
    contract: BlacklistInstance,
    wallet_address: Address,
}

impl OnchainBlacklistContract {
    /// Creates a new on-chain blacklist contract client and verifies overseer permissions.
    pub async fn new(
        rpc_url: &str,
        private_key: &str,
        contract_address: &str,
        chain_id: u64,
    ) -> Result<Self> {
        let mut signer = PrivateKeySigner::from_str(private_key)
            .with_context(|| "failed to parse private key".to_string())?;
        signer.set_chain_id(Some(chain_id));
        let wallet_address = signer.address();

        let url = Url::parse(rpc_url).with_context(|| "invalid rpc url".to_string())?;

        let provider = ProviderBuilder::new()
            .with_chain_id(chain_id)
            .wallet(signer)
            .connect_http(url);
        let provider = Arc::new(provider);

        let contract_address = Address::from_str(contract_address)
            .with_context(|| format!("invalid blacklist contract address: {contract_address}"))?;
        let contract = IRegistryBlacklist::new(contract_address, provider.clone());

        let instance = Self {
            contract,
            wallet_address,
        };

        instance.ensure_overseer().await?;

        info!(
            target: "overseer::contracts",
            wallet = ?instance.wallet_address,
            contract = ?contract_address,
            "successfully initialised on-chain blacklist client"
        );

        Ok(instance)
    }

    async fn ensure_overseer(&self) -> Result<()> {
        let allowed = self
            .contract
            .overseers(self.wallet_address)
            .call()
            .await
            .with_context(|| "failed to query overseer status".to_string())?;
        if !allowed {
            return Err(anyhow!(
                "wallet {} is not authorised as an overseer on the blacklist contract",
                hex_addr(self.wallet_address)
            ));
        }

        Ok(())
    }

    async fn is_blacklisted(&self, root: B256) -> Result<bool> {
        let response = self
            .contract
            .isOperatorBlacklisted(root)
            .call()
            .await
            .with_context(|| "failed to query blacklist status".to_string())?;
        Ok(response)
    }
}

#[async_trait]
impl BlacklistContract for OnchainBlacklistContract {
    async fn blacklist(&self, preconfirmer: &Preconfirmer, _violation: &Violation) -> Result<()> {
        let operator_registration_root = preconfirmer.registration_root;

        if self.is_blacklisted(operator_registration_root).await? {
            warn!(
                target: "overseer::contracts",
                preconfirmer = %preconfirmer,
                "preconfirmer already blacklisted; skipping"
            );
            return Ok(());
        }

        let pending = self
            .contract
            .blacklistOperator(operator_registration_root)
            .send()
            .await
            .with_context(|| "failed to submit blacklist transaction".to_string())?;

        let tx_hash = *pending.tx_hash();

        pending
            .get_receipt()
            .await
            .with_context(|| "failed to confirm blacklist transaction".to_string())?;

        info!(
            target: "overseer::contracts",
            preconfirmer = %preconfirmer,
            wallet = %hex_addr(self.wallet_address),
            tx_hash = ?tx_hash,
            "blacklist transaction confirmed"
        );

        Ok(())
    }
}

fn hex_addr(address: Address) -> String {
    format!("0x{}", hex::encode(address.as_slice()))
}
