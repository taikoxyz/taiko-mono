use std::{pin::Pin, time::Duration};

use alloy::{network::Network, providers::RootProvider};

use crate::robust_provider::{
    Error, IntoRootProvider, RobustProvider, subscription::DEFAULT_RECONNECT_INTERVAL,
};

type BoxedProviderFuture<N> = Pin<Box<dyn Future<Output = Result<RootProvider<N>, Error>> + Send>>;

// RPC retry and timeout settings
/// Default timeout used by `RobustProvider`
pub const DEFAULT_CALL_TIMEOUT: Duration = Duration::from_secs(60);
/// Default timeout for subscriptions
pub const DEFAULT_SUBSCRIPTION_TIMEOUT: Duration = Duration::from_secs(120);
/// Default maximum number of retry attempts.
pub const DEFAULT_MAX_RETRIES: usize = 3;
/// Default base delay between retries.
pub const DEFAULT_MIN_DELAY: Duration = Duration::from_secs(1);
/// Default subscription channel size.
pub const DEFAULT_SUBSCRIPTION_BUFFER_CAPACITY: usize = 128;
/// Default polling interval for HTTP subscriptions.
///
/// Set to 12 seconds to match approximate Ethereum mainnet block time.
/// Adjust based on the target chain's block time.
#[cfg(feature = "http-subscription")]
pub const DEFAULT_POLL_INTERVAL: Duration = Duration::from_secs(12);

/// Builder for constructing a [`RobustProvider`].
///
/// Use this to configure timeouts, retry/backoff, and one or more fallback providers.
pub struct RobustProviderBuilder<N: Network, P: IntoRootProvider<N>> {
    primary_provider: P,
    fallback_providers: Vec<BoxedProviderFuture<N>>,
    call_timeout: Duration,
    subscription_timeout: Duration,
    max_retries: usize,
    min_delay: Duration,
    reconnect_interval: Duration,
    subscription_buffer_capacity: usize,
    #[cfg(feature = "http-subscription")]
    poll_interval: Duration,
    #[cfg(feature = "http-subscription")]
    allow_http_subscriptions: bool,
}

impl<N: Network, P: IntoRootProvider<N>> RobustProviderBuilder<N, P> {
    /// Create a new [`RobustProvider`] with default settings.
    ///
    /// The provided provider is treated as the primary provider.
    /// Any type implementing [`IntoRootProvider`] can be used.
    #[must_use]
    pub fn new(provider: P) -> Self {
        Self {
            primary_provider: provider,
            fallback_providers: vec![],
            call_timeout: DEFAULT_CALL_TIMEOUT,
            subscription_timeout: DEFAULT_SUBSCRIPTION_TIMEOUT,
            max_retries: DEFAULT_MAX_RETRIES,
            min_delay: DEFAULT_MIN_DELAY,
            reconnect_interval: DEFAULT_RECONNECT_INTERVAL,
            subscription_buffer_capacity: DEFAULT_SUBSCRIPTION_BUFFER_CAPACITY,
            #[cfg(feature = "http-subscription")]
            poll_interval: DEFAULT_POLL_INTERVAL,
            #[cfg(feature = "http-subscription")]
            allow_http_subscriptions: false,
        }
    }

    /// Create a new [`RobustProvider`] with no retry attempts and only timeout set.
    ///
    /// The provided provider is treated as the primary provider.
    #[must_use]
    pub fn fragile(provider: P) -> Self {
        Self::new(provider).max_retries(0).min_delay(Duration::ZERO)
    }

    /// Add a fallback provider to the list.
    ///
    /// Fallback providers are used when the primary provider times out or fails.
    #[must_use]
    pub fn fallback<F: IntoRootProvider<N> + Send + 'static>(mut self, provider: F) -> Self {
        self.fallback_providers.push(Box::pin(provider.into_root_provider()));
        self
    }

    /// Set the maximum timeout for RPC operations.
    #[must_use]
    pub fn call_timeout(mut self, timeout: Duration) -> Self {
        self.call_timeout = timeout;
        self
    }

    /// Set the timeout for subscription operations.
    ///
    /// This should be set higher than [`call_timeout`](Self::call_timeout) to accommodate chains
    /// with slow block times. Default is [`DEFAULT_SUBSCRIPTION_TIMEOUT`].
    #[must_use]
    pub fn subscription_timeout(mut self, timeout: Duration) -> Self {
        self.subscription_timeout = timeout;
        self
    }

    /// Set the subscription stream buffer capacity.
    ///
    /// Controls the buffer capacity for subscription streams. If new blocks arrive
    /// while the stream buffer is full, a lagged error will be emitted, indicating
    /// that stream items were dropped due to the consumer not keeping pace with the stream.
    ///
    /// Internally calls [`alloy::providers::GetSubscription::channel_size`].
    ///
    /// Default is [`DEFAULT_SUBSCRIPTION_BUFFER_CAPACITY`].
    #[must_use]
    pub fn subscription_buffer_capacity(mut self, buffer_capacity: usize) -> Self {
        self.subscription_buffer_capacity = buffer_capacity;
        self
    }

    /// Set the maximum number of retry attempts.
    #[must_use]
    pub fn max_retries(mut self, max_retries: usize) -> Self {
        self.max_retries = max_retries;
        self
    }

    /// Set the base delay for exponential backoff retries.
    #[must_use]
    pub fn min_delay(mut self, min_delay: Duration) -> Self {
        self.min_delay = min_delay;
        self
    }

    /// Set the interval for attempting to reconnect to the primary provider.
    ///
    /// After a failover to a fallback provider, the subscription will periodically
    /// attempt to reconnect to the primary provider at this interval.
    /// Default is [`DEFAULT_RECONNECT_INTERVAL`].
    #[must_use]
    pub fn reconnect_interval(mut self, reconnect_interval: Duration) -> Self {
        self.reconnect_interval = reconnect_interval;
        self
    }

    /// Set the polling interval for HTTP-based subscriptions.
    ///
    /// This controls how frequently HTTP providers poll for new blocks
    /// when used as subscription sources. Only relevant when
    /// [`allow_http_subscriptions`](Self::allow_http_subscriptions) is enabled.
    ///
    /// Default is [`DEFAULT_POLL_INTERVAL`].
    /// Adjust based on your target chain's block time.
    ///
    /// # Feature Flag
    ///
    /// This method requires the `http-subscription` feature.
    ///
    /// # Example
    ///
    /// ```rust,ignore
    /// let robust = RobustProviderBuilder::new(http_provider)
    ///     .allow_http_subscriptions(true)
    ///     .poll_interval(Duration::from_secs(6)) // For faster chains
    ///     .build()
    ///     .await?;
    /// ```
    #[cfg(feature = "http-subscription")]
    #[must_use]
    pub fn poll_interval(mut self, interval: Duration) -> Self {
        self.poll_interval = interval;
        self
    }

    /// Enable HTTP providers for subscriptions via polling.
    ///
    /// When enabled, HTTP providers can participate in subscriptions
    /// by polling for new blocks at the configured [`poll_interval`](Self::poll_interval).
    ///
    /// # Trade-offs
    ///
    /// * **Latency**: New blocks detected with up to `poll_interval` delay
    /// * **RPC Load**: Generates one RPC call per `poll_interval`
    /// * **Intermediate Blocks**: Depending on the node/provider semantics, you may not observe
    ///   every intermediate block when `poll_interval` is larger than the chain's block time (e.g.
    ///   if only the latest head is exposed).
    ///
    /// # Feature Flag
    ///
    /// This method requires the `http-subscription` feature.
    ///
    /// # Example
    ///
    /// ```rust,ignore
    /// let robust = RobustProviderBuilder::new(http_provider)
    ///     .allow_http_subscriptions(true)
    ///     .build()
    ///     .await?;
    /// ```
    #[cfg(feature = "http-subscription")]
    #[must_use]
    pub fn allow_http_subscriptions(mut self, allow: bool) -> Self {
        self.allow_http_subscriptions = allow;
        self
    }

    /// Build the `RobustProvider`.
    ///
    /// Final builder method: consumes the builder and returns the built [`RobustProvider`].
    ///
    /// # Errors
    ///
    /// Returns an error if any of the providers fail to connect.
    pub async fn build(self) -> Result<RobustProvider<N>, Error> {
        debug!(
            call_timeout_ms = self.call_timeout.as_millis(),
            subscription_timeout_ms = self.subscription_timeout.as_millis(),
            max_retries = self.max_retries,
            fallback_count = self.fallback_providers.len(),
            "Building RobustProvider"
        );

        let primary_provider = self.primary_provider.into_root_provider().await?;

        let mut fallback_providers = Vec::with_capacity(self.fallback_providers.len());
        for (idx, fallback) in self.fallback_providers.into_iter().enumerate() {
            trace!(fallback_index = idx, "Connecting fallback provider");
            // ignore unused var warning when tracing disabled
            _ = idx;

            fallback_providers.push(fallback.await?);
        }

        info!("RobustProvider initialized");

        Ok(RobustProvider {
            primary_provider,
            fallback_providers,
            call_timeout: self.call_timeout,
            subscription_timeout: self.subscription_timeout,
            max_retries: self.max_retries,
            min_delay: self.min_delay,
            reconnect_interval: self.reconnect_interval,
            subscription_buffer_capacity: self.subscription_buffer_capacity,
            #[cfg(feature = "http-subscription")]
            poll_interval: self.poll_interval,
            #[cfg(feature = "http-subscription")]
            allow_http_subscriptions: self.allow_http_subscriptions,
        })
    }
}
