use std::{
    pin::Pin,
    task::{Context, Poll, ready},
    time::{Duration, Instant},
};

use alloy::{
    network::Network,
    providers::{Provider, RootProvider},
    pubsub::Subscription,
};
#[cfg(feature = "http-subscription")]
use alloy::{
    primitives::{BlockHash, U256},
    rpc::client::PollerBuilder,
};
#[cfg(feature = "http-subscription")]
use tokio::sync::mpsc;
use tokio::time::timeout;
use tokio_stream::Stream;
use tokio_util::sync::ReusableBoxFuture;

use crate::{
    Error,
    robust_provider::{FailoverError, RobustProvider},
};

/// Default time interval between primary provider reconnection attempts
pub const DEFAULT_RECONNECT_INTERVAL: Duration = Duration::from_secs(30);

/// Backend for subscriptions - either native WebSocket or HTTP polling.
///
/// This enum allows `RobustSubscription` to transparently handle both
/// WebSocket-based and HTTP polling-based subscriptions.
#[derive(Debug)]
pub(crate) enum SubscriptionBackend<N: Network> {
    /// Native WebSocket subscription using pubsub
    WebSocket(Subscription<N::HeaderResponse>),
    /// HTTP polling-based subscription (requires `http-subscription` feature)
    #[cfg(feature = "http-subscription")]
    HttpPolling(mpsc::Receiver<BlockHash>),
}

impl<N: Network> From<Subscription<N::HeaderResponse>> for SubscriptionBackend<N> {
    fn from(value: Subscription<N::HeaderResponse>) -> Self {
        SubscriptionBackend::WebSocket(value)
    }
}

#[cfg(feature = "http-subscription")]
impl<N: Network> From<PollerBuilder<(U256,), Vec<BlockHash>>> for SubscriptionBackend<N> {
    fn from(value: PollerBuilder<(U256,), Vec<BlockHash>>) -> Self {
        use tokio_stream::StreamExt;

        let (sender, receiver) = mpsc::channel(value.channel_size());

        let mut stream = value.into_stream();
        tokio::spawn(async move {
            while let Some(hashes) = stream.next().await {
                for hash in hashes {
                    if sender.send(hash).await.is_err() {
                        // Receiver dropped, stop polling
                        break;
                    }
                }
            }
        });

        SubscriptionBackend::HttpPolling(receiver)
    }
}

/// A robust subscription wrapper that automatically handles provider failover
/// and periodic reconnection attempts to the primary provider.
#[derive(Debug)]
pub struct RobustSubscription<N: Network> {
    backend: SubscriptionBackend<N>,
    robust_provider: RobustProvider<N>,
    last_reconnect_attempt: Option<Instant>,
    current_fallback_index: Option<usize>,
}

impl<N: Network> RobustSubscription<N> {
    /// Create a new [`RobustSubscription`] with a WebSocket backend.
    pub(crate) fn new(
        subscription: impl Into<SubscriptionBackend<N>>,
        robust_provider: RobustProvider<N>,
    ) -> Self {
        Self {
            backend: subscription.into(),
            robust_provider,
            last_reconnect_attempt: None,
            current_fallback_index: None,
        }
    }

    /// Receive the next item from the subscription with automatic failover.
    ///
    /// This method will:
    /// * Attempt to receive from the current subscription (WebSocket or HTTP polling)
    /// * Handle errors by switching to fallback providers
    /// * Periodically attempt to reconnect to the primary provider
    /// * Will switch to fallback providers if subscription timeout is exhausted
    ///
    /// # Primary Provider Reconnection
    ///
    /// The primary provider is retried in two scenarios:
    /// 1. **Periodic reconnection**: Every `reconnect_interval` (default: 30 seconds) while on a
    ///    fallback provider and successfully receiving blocks. Note: The actual reconnection
    ///    attempt occurs when a new block is received, so if blocks arrive slower than the
    ///    reconnect interval, reconnection will be delayed until the next block.
    /// 2. **Fallback failure**: Immediately when a fallback provider fails, before attempting the
    ///    next fallback provider
    ///
    /// # Errors
    ///
    /// * Propagates any underlying subscription errors.
    /// * If all providers have been exhausted and failed, returns the last attempt's error.
    pub async fn recv(&mut self) -> Result<N::HeaderResponse, Error> {
        let subscription_timeout = self.robust_provider.subscription_timeout;

        loop {
            // Receive from the appropriate backend
            let result = match &mut self.backend {
                SubscriptionBackend::WebSocket(sub) => {
                    match timeout(subscription_timeout, sub.recv()).await {
                        Ok(Ok(header)) => Ok(header),
                        Ok(Err(recv_error)) => Err(Error::from(recv_error)),
                        Err(_elapsed) => Err(Error::Timeout),
                    }
                }
                #[cfg(feature = "http-subscription")]
                SubscriptionBackend::HttpPolling(sub) => {
                    let result = timeout(subscription_timeout, sub.recv()).await;
                    match result {
                        Ok(Some(hash)) => {
                            use alloy::network::BlockResponse;

                            match timeout(
                                subscription_timeout,
                                self.robust_provider.get_block_by_hash(hash),
                            )
                            .await
                            {
                                Ok(Ok(block)) => Ok(block.header().clone()),
                                Ok(Err(e)) => Err(e),
                                Err(_elapsed) => Err(Error::Timeout),
                            }
                        }
                        Ok(None) => Err(Error::Closed),
                        Err(_elapsed) => Err(Error::Timeout),
                    }
                }
            };

            match result {
                Ok(header) => {
                    if self.is_on_fallback() {
                        self.try_reconnect_to_primary(false).await;
                    }
                    return Ok(header);
                }
                Err(Error::Timeout) => {
                    warn!(
                        timeout_secs = subscription_timeout.as_secs(),
                        "Subscription timeout - no block received, switching provider"
                    );
                    self.switch_to_fallback(FailoverError::Timeout).await?;
                }
                // Propagate these errors directly without failover
                Err(Error::Lagged(count)) => return Err(Error::Lagged(count)),
                Err(Error::BlockNotFound) => return Err(Error::BlockNotFound),
                // Closed connection and RPC errors trigger failover
                Err(Error::Closed) => {
                    warn!("Subscription connection unexpectedly closed, switching provider");
                    self.switch_to_fallback(FailoverError::Closed).await?;
                }
                Err(Error::RpcError(e)) => {
                    warn!("Subscription RPC error, switching provider");
                    self.switch_to_fallback(e.into()).await?;
                }
            }
        }
    }

    /// Try to reconnect to the primary provider if enough time has elapsed.
    /// Returns true if reconnection was successful, false if it's not time yet or if it failed.
    async fn try_reconnect_to_primary(&mut self, force: bool) -> bool {
        // Check if we should attempt reconnection
        let should_reconnect = force ||
            match self.last_reconnect_attempt {
                None => false,
                Some(last_attempt) => {
                    last_attempt.elapsed() >= self.robust_provider.reconnect_interval
                }
            };

        if !should_reconnect {
            return false;
        }

        let primary = self.robust_provider.primary();
        let subscription_buffer_capacity = self.robust_provider.subscription_buffer_capacity;
        #[cfg(feature = "http-subscription")]
        let poll_interval = self.robust_provider.poll_interval;
        #[cfg(feature = "http-subscription")]
        let allow_http_subscriptions = self.robust_provider.allow_http_subscriptions;

        let operation = move |provider: RootProvider<N>| async move {
            // if HTTP subscriptions are enabled and the provider currently being tried is HTTP,
            // we will attempt to connect using it.
            // Otherwise try subscribing through a PubSub operation, and if the provider is HTTP
            // just let it fail; the error will be non-retriable, so the algorithm will
            // automatically switch to the next fallback provider (see
            // `try_provider_with_timeout`).
            #[cfg(feature = "http-subscription")]
            {
                let not_pubsub = provider.client().pubsub_frontend().is_none();
                if not_pubsub && allow_http_subscriptions {
                    return provider.watch_blocks().await.map(|builder| {
                        builder
                            .with_poll_interval(poll_interval)
                            .with_channel_size(subscription_buffer_capacity)
                            .into()
                    });
                }
            }
            provider
                .subscribe_blocks()
                .channel_size(subscription_buffer_capacity)
                .await
                .map(Into::<SubscriptionBackend<N>>::into)
        };

        let subscription =
            self.robust_provider.try_provider_with_timeout(primary, &operation).await;

        if let Ok(backend) = subscription {
            info!("Reconnected to primary provider");
            self.backend = backend;
            self.current_fallback_index = None;
            self.last_reconnect_attempt = None;
            return true;
        }

        self.last_reconnect_attempt = Some(Instant::now());
        false
    }

    async fn switch_to_fallback(&mut self, last_error: FailoverError) -> Result<(), Error> {
        // If we're on a fallback, try primary first before moving to next fallback
        if self.is_on_fallback() && self.try_reconnect_to_primary(true).await {
            return Ok(());
        }

        if self.last_reconnect_attempt.is_none() {
            self.last_reconnect_attempt = Some(Instant::now());
        }

        // Start searching from the next provider after the current one
        let start_index = self.current_fallback_index.map_or(0, |idx| idx + 1);
        let fallback_providers = self.robust_provider.fallback_providers();
        let subscription_buffer_capacity = self.robust_provider.subscription_buffer_capacity;
        #[cfg(feature = "http-subscription")]
        let poll_interval = self.robust_provider.poll_interval;
        #[cfg(feature = "http-subscription")]
        let allow_http_subscriptions = self.robust_provider.allow_http_subscriptions;

        // Try each fallback provider
        for (idx, provider) in fallback_providers.iter().enumerate().skip(start_index) {
            let operation = move |p: RootProvider<N>| async move {
                #[cfg(feature = "http-subscription")]
                {
                    let not_pubsub = p.client().pubsub_frontend().is_none();
                    if not_pubsub && allow_http_subscriptions {
                        return p.watch_blocks().await.map(|builder| {
                            builder
                                .with_poll_interval(poll_interval)
                                .with_channel_size(subscription_buffer_capacity)
                                .into()
                        });
                    }
                }
                p.subscribe_blocks()
                    .channel_size(subscription_buffer_capacity)
                    .await
                    .map(Into::<SubscriptionBackend<N>>::into)
            };

            if let Ok(backend) =
                self.robust_provider.try_provider_with_timeout(provider, &operation).await
            {
                info!(fallback_index = idx, "Subscription switched to fallback provider");
                self.backend = backend;
                self.current_fallback_index = Some(idx);
                return Ok(());
            }
        }

        // All fallbacks exhausted
        error!(
            attempted_providers = fallback_providers.len() + 1,
            "All providers exhausted for subscription"
        );
        Err(last_error.into())
    }

    /// Returns true if currently using a fallback provider
    fn is_on_fallback(&self) -> bool {
        self.current_fallback_index.is_some()
    }

    /// Check if the subscription channel is empty (no pending messages)
    #[must_use]
    pub fn is_empty(&self) -> bool {
        match &self.backend {
            SubscriptionBackend::WebSocket(sub) => sub.is_empty(),
            #[cfg(feature = "http-subscription")]
            SubscriptionBackend::HttpPolling(sub) => sub.is_empty(),
        }
    }

    /// Convert the subscription into a stream.
    #[must_use]
    pub fn into_stream(self) -> RobustSubscriptionStream<N> {
        RobustSubscriptionStream::from(self)
    }
}

type SubscriptionResult<N> = (Result<<N as Network>::HeaderResponse, Error>, RobustSubscription<N>);

pub struct RobustSubscriptionStream<N: Network> {
    inner: ReusableBoxFuture<'static, SubscriptionResult<N>>,
}

async fn make_future<N: Network>(mut rx: RobustSubscription<N>) -> SubscriptionResult<N> {
    let result = rx.recv().await;
    (result, rx)
}

impl<N: 'static + Clone + Send + Network> RobustSubscriptionStream<N> {
    /// Create a new `RobustSubscriptionStream`.
    #[must_use]
    pub fn new(rx: RobustSubscription<N>) -> Self {
        Self { inner: ReusableBoxFuture::new(make_future(rx)) }
    }
}

impl<N: 'static + Clone + Send + Network> Stream for RobustSubscriptionStream<N> {
    type Item = Result<N::HeaderResponse, Error>;

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        let (result, rx) = ready!(self.inner.poll(cx));
        self.inner.set(make_future(rx));
        match result {
            Ok(item) => Poll::Ready(Some(Ok(item))),
            Err(Error::Closed) => Poll::Ready(None),
            Err(e) => Poll::Ready(Some(Err(e))),
        }
    }
}

impl<N: 'static + Clone + Send + Network> From<RobustSubscription<N>>
    for RobustSubscriptionStream<N>
{
    fn from(recv: RobustSubscription<N>) -> Self {
        Self::new(recv)
    }
}
