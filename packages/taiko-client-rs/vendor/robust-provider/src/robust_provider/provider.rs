//! Core [`RobustProvider`] implementation with retry and failover logic.

use std::{borrow::Cow, fmt::Debug, future::Future, time::Duration};

use backon::{ExponentialBuilder, Retryable};
use serde_json::value::RawValue;
use tokio::time::timeout;

use super::errors::{FailoverError, is_retryable_error};
use alloy::{
    consensus::{BlockHeader, TrieAccount},
    eips::{BlockId, BlockNumberOrTag, eip1559::Eip1559Estimation},
    network::{BlockResponse, Ethereum, Network},
    primitives::{
        Address, B256, BlockHash, BlockNumber, Bytes, StorageKey, StorageValue, TxHash, U256,
    },
    providers::{
        PendingTransactionBuilder, Provider, RootProvider,
        utils::{
            EIP1559_FEE_ESTIMATION_PAST_BLOCKS, EIP1559_FEE_ESTIMATION_REWARD_PERCENTILE,
            Eip1559Estimator,
        },
    },
    rpc::{
        client::PollerBuilder,
        json_rpc::{RpcRecv, RpcSend},
        types::{
            AccessListResult, AccountInfo, Bundle, EIP1186AccountProofResponse, EthCallResponse,
            FeeHistory, FillTransaction, Filter, Log, SyncStatus,
            erc4337::TransactionConditional,
            simulate::{SimulatePayload, SimulatedBlock},
        },
    },
    transports::{RpcError, TransportErrorKind},
};

use crate::{
    Error,
    robust_provider::{RobustSubscription, subscription::SubscriptionBackend},
};

/// Provider wrapper with built-in retry and timeout mechanisms.
///
/// This wrapper around Alloy providers automatically handles retries,
/// timeouts, and error logging for RPC calls.
#[derive(Clone, Debug)]
pub struct RobustProvider<N: Network = Ethereum> {
    pub(crate) primary_provider: RootProvider<N>,
    pub(crate) fallback_providers: Vec<RootProvider<N>>,
    pub(crate) call_timeout: Duration,
    pub(crate) subscription_timeout: Duration,
    pub(crate) max_retries: usize,
    pub(crate) min_delay: Duration,
    pub(crate) reconnect_interval: Duration,
    pub(crate) subscription_buffer_capacity: usize,
    /// Polling interval for HTTP-based subscriptions.
    #[cfg(feature = "http-subscription")]
    pub(crate) poll_interval: Duration,
    /// Whether HTTP providers can participate in subscriptions via polling.
    #[cfg(feature = "http-subscription")]
    pub(crate) allow_http_subscriptions: bool,
}

impl<N: Network> RobustProvider<N> {
    #[must_use]
    pub fn primary(&self) -> &RootProvider<N> {
        &self.primary_provider
    }

    #[must_use]
    pub fn fallback_providers(&self) -> &[RootProvider<N>] {
        &self.fallback_providers
    }

    #[must_use]
    pub fn call_timeout(&self) -> Duration {
        self.call_timeout
    }

    #[must_use]
    pub fn max_retries(&self) -> usize {
        self.max_retries
    }

    #[must_use]
    pub fn min_delay(&self) -> Duration {
        self.min_delay
    }

    robust_rpc!(fn get_accounts() -> Vec<Address>);
    robust_rpc!(fn get_blob_base_fee() -> u128);

    robust_rpc!(
        doc_args = [(tx, "The transaction request to simulate.")]
        @clone [tx]
        fn call(tx: N::TransactionRequest) -> Bytes
    );

    robust_rpc!(
        doc_args = [(bundles, "A slice of transaction bundles to execute.")]
        fn call_many(bundles: &[Bundle]) -> Vec<Vec<EthCallResponse>>
    );

    robust_rpc!(fn get_chain_id() -> u64);

    robust_rpc!(fn get_net_version() -> u64);

    robust_rpc!(
        doc_args = [(data, "The data to hash.")]
        fn get_sha3(data: &[u8]) -> B256
    );

    robust_rpc!(
        doc_args = [(request, "The transaction request to create an access list for.")]
        fn create_access_list(request: &N::TransactionRequest) -> AccessListResult
    );

    robust_rpc!(
        doc_args = [(tx, "The transaction request to estimate gas for.")]
        @clone [tx]
        fn estimate_gas(tx: N::TransactionRequest) -> u64
    );

    robust_rpc!(
        fn estimate_eip1559_fees() -> Eip1559Estimation
    );

    robust_rpc!(
        doc_args = [
            (block_count, "The number of blocks to include in the fee history."),
            (last_block, "The last block to include in the fee history."),
            (reward_percentiles, "A list of percentiles to compute reward values for.")
        ]
        fn get_fee_history(block_count: u64, last_block: BlockNumberOrTag, reward_percentiles: &[f64]) -> FeeHistory
    );

    robust_rpc!(fn get_gas_price() -> u128);
    robust_rpc!(fn get_max_priority_fee_per_gas() -> u128);

    robust_rpc!(
        doc_args = [(address, "The address for which to get the account info.")]
        fn get_account_info(address: Address) -> AccountInfo
    );

    robust_rpc!(
        doc_args = [(address, "The address to get the account for.")]
        fn get_account(address: Address) -> TrieAccount
    );

    robust_rpc!(
        doc_args = [(address, "The address to get the balance for.")]
        fn get_balance(address: Address) -> U256
    );

    robust_rpc!(
        doc_include_error = [block_not_found_doc!()]
        doc_args = [(number, "The block number or tag.")]
        fn get_block_by_number(number: BlockNumberOrTag) -> N::BlockResponse; or BlockNotFound
    );

    robust_rpc!(
        doc_include_error = [block_not_found_doc!()]
        doc_args = [(id, "The block identifier.")]
        fn get_block(id: BlockId) -> N::BlockResponse; or BlockNotFound
    );

    robust_rpc!(fn get_block_number() -> BlockNumber);

    robust_rpc!(
        doc_include_error = [block_not_found_doc!()]
        doc_args = [(block_id, "The block identifier to fetch the block number for.")]
        fn get_block_number_by_id(block_id: BlockId) -> BlockNumber; or BlockNotFound
    );

    robust_rpc!(
        doc_include_error = [block_not_found_doc!()]
        doc_args = [(hash, "The block hash.")]
        fn get_block_by_hash(hash: BlockHash) -> N::BlockResponse; or BlockNotFound
    );

    robust_rpc!(
        doc_include_error = [block_not_found_doc!()]
        doc_args = [(block, "The block identifier (hash, number, or tag).")]
        fn get_block_receipts(block: BlockId) -> Vec<N::ReceiptResponse>; or BlockNotFound
    );

    robust_rpc!(
        doc_include_error = [block_not_found_doc!()]
        doc_args = [(hash, "The block hash.")]
        fn get_block_transaction_count_by_hash(hash: BlockHash) -> u64; or BlockNotFound
    );

    robust_rpc!(
        doc_include_error = [block_not_found_doc!()]
        doc_args = [(block_number, "The block number or tag.")]
        fn get_block_transaction_count_by_number(block_number: BlockNumberOrTag) -> u64; or BlockNotFound
    );

    robust_rpc!(
        doc_args = [(filter, "The log filter.")]
        fn get_logs(filter: &Filter) -> Vec<Log>
    );

    robust_rpc!(
        doc_args = [(address, "The address to get the code for.")]
        fn get_code_at(address: Address) -> Bytes
    );

    robust_rpc!(
        doc_args = [(filter_id, "The filter ID to fetch logs for.")]
        fn get_filter_logs(filter_id: U256) -> Vec<Log>
    );

    robust_rpc!(
        doc_args = [(filter_id, "The filter ID to get changes for.")]
        fn get_filter_changes<R: RpcRecv>(filter_id: U256) -> Vec<R>
    );

    robust_rpc!(
        doc_args = [(filter, "The filter to create.")]
        fn new_filter(filter: &Filter) -> U256
    );

    robust_rpc!(fn new_block_filter() -> U256);

    robust_rpc!(
        doc_args = [(full, "Whether to include full transaction objects.")]
        fn new_pending_transactions_filter(full: bool) -> U256
    );

    robust_rpc!(
        doc_args = [
            (tx, "The transaction request to sign.")
        ]
        @clone [tx]
        fn sign_transaction(tx: N::TransactionRequest) -> Bytes
    );

    robust_rpc!(
        doc_args = [
            (tx, "The transaction request to fill.")
        ]
        @clone [tx]
        fn fill_transaction(tx: N::TransactionRequest) -> FillTransaction<N::TxEnvelope>
        where N::TxEnvelope: RpcRecv
    );

    robust_rpc!(
        doc_args = [
            (address, "The address of the account."),
            (keys, "A vector of storage keys to include in the proof.")
        ]
        @clone [keys]
        fn get_proof(address: Address, keys: Vec<StorageKey>) -> EIP1186AccountProofResponse
    );

    robust_rpc!(
        doc_args = [
            (address, "The address of the storage."),
            (key, "The position in the storage.")
        ]
        fn get_storage_at(address: Address, key: U256) -> StorageValue
    );

    robust_rpc!(
        doc_args = [
            (block_hash, "The hash of the block."),
            (index, "The transaction index position.")
        ]
        fn get_transaction_by_block_hash_and_index(block_hash: B256, index: usize) -> Option<N::TransactionResponse>
    );

    robust_rpc!(
        doc_args = [
            (block_number, "The block number or tag."),
            (index, "The transaction index position.")
        ]
        fn get_transaction_by_block_number_and_index(block_number: BlockNumberOrTag, index: usize) -> Option<N::TransactionResponse>
    );

    robust_rpc!(
        doc_args = [(hash, "The transaction hash.")]
        fn get_transaction_by_hash(hash: TxHash) -> Option<N::TransactionResponse>
    );

    robust_rpc!(
        doc_args = [(hash, "The transaction hash.")]
        fn get_raw_transaction_by_hash(hash: TxHash) -> Option<Bytes>
    );

    robust_rpc!(
        doc_args = [(address, "The address to get the transaction count for.")]
        fn get_transaction_count(address: Address) -> u64
    );

    robust_rpc!(
        doc_args = [(hash, "The transaction hash.")]
        fn get_transaction_receipt(hash: TxHash) -> Option<N::ReceiptResponse>
    );

    robust_rpc!(
        doc_args = [(block, "The block identifier (hash or number).")]
        fn get_uncle_count(block: BlockId) -> u64
    );

    robust_rpc!(
        doc_args = [
            (tag, "The block identifier (hash or number)."),
            (idx, "The uncle index position.")
        ]
        fn get_uncle(tag: BlockId, idx: u64) -> Option<N::BlockResponse>
    );

    robust_rpc!(
        doc_args = [(request, "The simulation request")]
        fn simulate(request: &SimulatePayload) -> Vec<SimulatedBlock<N::BlockResponse>>
    );

    robust_rpc!(fn syncing() -> SyncStatus);

    robust_rpc!(
        doc_args = [(id, "The filter ID to uninstall.")]
        fn uninstall_filter(id: U256) -> bool
    );

    robust_rpc!(
        doc_args = [(encoded_tx, "The RLP-encoded signed transaction bytes")]
        fn send_raw_transaction(encoded_tx: &[u8]) -> PendingTransactionBuilder<N>
    );

    robust_rpc!(
        doc_args = [(encoded_tx, "The RLP-encoded signed transaction bytes")]
        fn send_raw_transaction_sync(encoded_tx: &[u8]) -> N::ReceiptResponse
    );

    robust_rpc!(
        doc_args = [
            (encoded_tx, "The RLP-encoded signed transaction bytes"),
            (conditional, "The transaction conditional to apply")
        ]
        @clone [conditional]
        fn send_raw_transaction_conditional(encoded_tx: &[u8], conditional: TransactionConditional) -> PendingTransactionBuilder<N>
    );

    robust_rpc!(
        doc_args = [(tx, "The transaction request to send")]
        @clone [tx]
        fn send_transaction(tx: N::TransactionRequest) -> PendingTransactionBuilder<N>
    );

    robust_rpc!(
        doc_args = [
            (tx, "The signed transaction envelope to send.")
        ]
        @clone [tx]
        fn send_tx_envelope(tx: N::TxEnvelope) -> PendingTransactionBuilder<N>
        where N::TxEnvelope: Clone
    );

    robust_rpc!(
        doc_args = [(tx, "The transaction request to send synchronously")]
        @clone [tx]
        fn send_transaction_sync(tx: N::TransactionRequest) -> N::ReceiptResponse
    );

    robust_rpc!(
        doc_args = [
            (sender, "The sender address"),
            (nonce, "The nonce of the transaction")
        ]
        fn get_transaction_by_sender_nonce(sender: Address, nonce: u64) -> Option<N::TransactionResponse>
    );

    robust_rpc!(
        doc_args = [
            (block_hash, "The hash of the block"),
            (index, "The transaction index position")
        ]
        fn get_raw_transaction_by_block_hash_and_index(block_hash: B256, index: usize) -> Option<Bytes>
    );

    robust_rpc!(
        doc_args = [
            (block_number, "The block number or tag"),
            (index, "The transaction index position")
        ]
        fn get_raw_transaction_by_block_number_and_index(block_number: BlockNumberOrTag, index: usize) -> Option<Bytes>
    );

    robust_rpc!(
        doc_alias = "web3_client_version"
        fn get_client_version() -> String
    );

    /// Estimates the [EIP-1559] `maxFeePerGas` and `maxPriorityFeePerGas` fields using a custom
    /// estimator.
    ///
    /// # Implementation Note
    ///
    /// Unlike most methods in `RobustProvider`, this method **does not** wrap the underlying
    /// provider's `estimate_eip1559_fees_with` call with retry/failover logic. Instead, it
    /// implements the estimation logic directly (copied from alloy's implementation).
    ///
    /// Ref <https://github.com/alloy-rs/alloy/blob/9a90a57acde7f30787b675815334cf54c6be4ba1/crates/provider/src/provider/trait.rs#L283>
    ///
    /// **Reason:** This method accepts an **owned**, **non-cloneable** `Eip1559Estimator` value.
    /// The current retry implementation (`try_operation_with_failover`) requires operations to
    /// be retryable across multiple providers, which means closures must be able to run
    /// multiple times. This only works with `Copy` or `Clone` types. Since `Eip1559Estimator`
    /// consumes itself and cannot be cloned, we cannot use the standard retry wrapper.
    ///
    /// There is a pending issue on alloy <https://github.com/alloy-rs/alloy/issues/3669> which
    /// would allow [`Eip1559Estimator`] to implement Clone. If this is merged we can remove this
    /// custom impl.
    ///
    /// However, **the individual RPC calls** within this method (`get_fee_history` and
    /// `get_block_by_number`) **do** benefit from full retry and failover support, as they use
    /// the standard robust wrappers internally.
    ///
    /// # Parameters
    ///
    /// * `estimator` - The [`Eip1559Estimator`] to use for calculating fees.
    ///
    /// # Errors
    ///
    /// * [`Error::RpcError`] - if the underlying RPC calls fail after exhausting retries on all
    ///   providers
    /// * [`Error::Timeout`] - if the operation exceeds the configured timeout
    /// * [`Error::RpcError`] with `UnsupportedFeature("eip1559")` - if the chain doesn't support
    ///   EIP-1559 (i.e., the latest block has no `base_fee_per_gas`)
    pub async fn estimate_eip1559_fees_with(
        &self,
        estimator: Eip1559Estimator,
    ) -> Result<Eip1559Estimation, Error> {
        let fee_history = self
            .get_fee_history(
                EIP1559_FEE_ESTIMATION_PAST_BLOCKS,
                BlockNumberOrTag::Latest,
                &[EIP1559_FEE_ESTIMATION_REWARD_PERCENTILE],
            )
            .await?;

        // if the base fee of the Latest block is 0 then we need check if the latest block even has
        // a base fee/supports EIP1559
        let base_fee_per_gas = match fee_history.latest_block_base_fee() {
            Some(base_fee) if base_fee != 0 => base_fee,
            _ => {
                // empty response, fetch basefee from latest block directly
                self.get_block_by_number(BlockNumberOrTag::Latest)
                    .await
                    .map_err(|e| {
                        // this is how alloy implements it - if block not found, return NullResp,
                        // see: https://github.com/alloy-rs/alloy/blob/aef6655961fa4b75ccf3b8a45186c57b09e7954e/crates/provider/src/provider/trait.rs#L303
                        if matches!(e, Error::BlockNotFound) {
                            RpcError::NullResp.into()
                        } else {
                            e
                        }
                    })?
                    .header()
                    .as_ref()
                    .base_fee_per_gas()
                    .ok_or(RpcError::UnsupportedFeature("eip1559"))?
                    .into()
            }
        };

        Ok(estimator.estimate(base_fee_per_gas, &fee_history.reward.unwrap_or_default()))
    }

    robust_rpc!(
            @clone [method, params]
            fn raw_request<P, R>(method: Cow<'static, str>, params: P) -> R
            where P: RpcSend, R: RpcRecv
    );

    robust_rpc!(
         @clone [method]
         fn raw_request_dyn(method: Cow<'static, str>, params: &RawValue) -> Box<RawValue>
    );

    /// Subscribe to new block headers with automatic failover and reconnection.
    ///
    /// Returns a [`RobustSubscription`] that automatically:
    /// * Handles connection errors by switching to fallback providers
    /// * Detects and recovers from lagged subscriptions
    /// * Periodically attempts to reconnect to the primary provider
    ///
    /// When the `http-subscription` feature is enabled and
    /// [`allow_http_subscriptions`](crate::RobustProviderBuilder::allow_http_subscriptions)
    /// is set to `true`, HTTP providers can participate in subscriptions via polling.
    ///
    /// This is a wrapper function for [`Provider::subscribe_blocks`].
    ///
    /// # Errors
    ///
    /// * [`Error::RpcError`] - if no fallback providers succeeded; contains the last error returned
    ///   by the last provider attempted on the last retry.
    /// * [`Error::Timeout`] - if the overall operation timeout elapses (i.e. exceeds
    ///   `call_timeout`).
    pub async fn subscribe_blocks(&self) -> Result<RobustSubscription<N>, Error> {
        let subscription: SubscriptionBackend<N> = self
            .try_operation_with_failover(move |provider| async move {
                // if HTTP subscriptions are enabled and the provider currently being tried is HTTP,
                // we will attempt to connect using it.
                // Otherwise try subscribing through a PubSub operation, and if the provider is HTTP
                // just let it fail; the error will be non-retriable, so the algorithm will
                // automatically switch to the next fallback provider (see
                // `try_provider_with_timeout`).
                #[cfg(feature = "http-subscription")]
                {
                    let not_pubsub = provider.client().pubsub_frontend().is_none();
                    if not_pubsub && self.allow_http_subscriptions {
                        return provider.watch_blocks().await.map(|builder| {
                            builder
                                .with_poll_interval(self.poll_interval)
                                .with_channel_size(self.subscription_buffer_capacity)
                                .into()
                        });
                    }
                }
                provider
                    .subscribe_blocks()
                    .channel_size(self.subscription_buffer_capacity)
                    .await
                    .map(Into::<SubscriptionBackend<N>>::into)
            })
            .await?;

        Ok(RobustSubscription::new(subscription, self.clone()))
    }

    // TODO: set watch blocks params from the RP itself
    robust_rpc!(fn watch_blocks() -> PollerBuilder<(U256,), Vec<BlockHash>>);

    /// Execute `operation` with exponential backoff and a total timeout.
    ///
    /// Wraps the retry logic with [`tokio::time::timeout`] so
    /// the entire operation (including time spent inside the RPC call) cannot exceed
    /// `call_timeout`.
    ///
    /// If the timeout is exceeded and fallback providers are available, it will
    /// attempt to use each fallback provider in sequence.
    ///
    /// # Errors
    ///
    /// * [`FailoverError::RpcError`] - if no fallback providers succeeded; contains the last error
    ///   returned by the last provider attempted on the last retry.
    /// * [`FailoverError::Timeout`] - if the overall operation timeout elapses (i.e. exceeds
    ///   `call_timeout`).
    pub async fn try_operation_with_failover<T: Debug, F, Fut>(
        &self,
        operation: F,
    ) -> Result<T, FailoverError>
    where
        F: Fn(RootProvider<N>) -> Fut,
        Fut: Future<Output = Result<T, RpcError<TransportErrorKind>>>,
    {
        let primary = self.primary();

        match self.try_provider_with_timeout(primary, &operation).await {
            Ok(value) => Ok(value),
            Err(last_error) => self
                .try_fallback_providers_from(&operation, last_error, 0)
                .await
                .map(|(value, _)| value),
        }
    }

    /// Try fallback providers starting from a specific index.
    pub(crate) async fn try_fallback_providers_from<T: Debug, F, Fut>(
        &self,
        operation: F,
        mut last_error: FailoverError,
        start_index: usize,
    ) -> Result<(T, usize), FailoverError>
    where
        F: Fn(RootProvider<N>) -> Fut,
        Fut: Future<Output = Result<T, RpcError<TransportErrorKind>>>,
    {
        let fallback_providers = self.fallback_providers();

        debug!(
            start_index = start_index,
            total_fallbacks = fallback_providers.len(),
            "Primary provider failed, attempting fallback providers"
        );

        let fallback_iter = fallback_providers.iter().enumerate().skip(start_index);
        for (fallback_idx, provider) in fallback_iter {
            trace!(
                fallback_index = fallback_idx,
                total_fallbacks = fallback_providers.len(),
                "Attempting fallback provider"
            );

            match self.try_provider_with_timeout(provider, &operation).await {
                Ok(value) => {
                    info!(
                        fallback_index = fallback_idx,
                        total_fallbacks = fallback_providers.len(),
                        "Switched to fallback provider"
                    );
                    return Ok((value, fallback_idx));
                }
                Err(e) => {
                    warn!(
                        fallback_index = fallback_idx,
                        error = %e,
                        "Fallback provider failed"
                    );
                    last_error = e;
                }
            }
        }

        error!(attempted_providers = fallback_providers.len() + 1, "All providers exhausted");

        Err(last_error)
    }

    /// Try executing an operation with a specific provider with retry and timeout.
    pub(crate) fn try_provider_with_timeout<T, F, Fut>(
        &self,
        provider: &RootProvider<N>,
        operation: F,
    ) -> impl Future<Output = Result<T, FailoverError>>
    where
        F: Fn(RootProvider<N>) -> Fut,
        Fut: Future<Output = Result<T, RpcError<TransportErrorKind>>>,
    {
        let retry_strategy = ExponentialBuilder::default()
            .with_max_times(self.max_retries())
            .with_min_delay(self.min_delay());

        let call_timeout = self.call_timeout();
        let provider = provider.clone();

        async move {
            timeout(
                call_timeout,
                (|| operation(provider.clone()))
                    .retry(retry_strategy)
                    .when(|e| match e {
                        // Check if the error is explicitly marked as retryable
                        RpcError::ErrorResp(err_resp) if err_resp.is_retry_err() => true,
                        // Check our custom non-retryable error classification
                        // TODO: check if this can be omitted once https://github.com/OpenZeppelin/Robust-Provider/issues/12 is implemented
                        RpcError::ErrorResp(err_resp) => {
                            is_retryable_error(err_resp.code, err_resp.message.as_ref())
                        }
                        // Transport errors have their own retry logic
                        RpcError::Transport(tr_err) => tr_err.is_retry_err(),
                        // Default to retrying unknown errors
                        _ => true,
                    })
                    .sleep(tokio::time::sleep),
            )
            .await
            .map_err(FailoverError::from)?
            .map_err(FailoverError::from)
        }
    }
}
