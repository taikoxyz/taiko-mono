use alloy::{
    network::{Ethereum, Network},
    providers::{
        DynProvider, Provider, RootProvider,
        fillers::{FillProvider, TxFiller},
        layers::{CacheProvider, CallBatchProvider},
    },
    transports::http::reqwest::Url,
};

use crate::robust_provider::{Error, RobustProvider, RobustProviderBuilder};

/// Conversion trait for types that can be turned into an Alloy [`RootProvider`].
///
/// This is primarily used by [`RobustProviderBuilder`] to accept different provider types and
/// connection strings.
pub trait IntoRootProvider<N: Network = Ethereum> {
    /// Convert `self` into a [`RootProvider`].
    ///
    /// # Errors
    ///
    /// Returns an error if the underlying provider cannot be constructed or connected.
    fn into_root_provider(self) -> impl Future<Output = Result<RootProvider<N>, Error>> + Send;
}

impl<N: Network> IntoRootProvider<N> for RootProvider<N> {
    async fn into_root_provider(self) -> Result<RootProvider<N>, Error> {
        Ok(self)
    }
}

impl<N: Network> IntoRootProvider<N> for &str {
    async fn into_root_provider(self) -> Result<RootProvider<N>, Error> {
        Ok(RootProvider::connect(self).await?)
    }
}

impl<N: Network> IntoRootProvider<N> for Url {
    async fn into_root_provider(self) -> Result<RootProvider<N>, Error> {
        Ok(RootProvider::connect(self.as_str()).await?)
    }
}

impl<F, P, N> IntoRootProvider<N> for FillProvider<F, P, N>
where
    F: TxFiller<N>,
    P: Provider<N>,
    N: Network,
{
    async fn into_root_provider(self) -> Result<RootProvider<N>, Error> {
        Ok(self.root().to_owned())
    }
}

impl<P, N> IntoRootProvider<N> for CacheProvider<P, N>
where
    P: Provider<N>,
    N: Network,
{
    async fn into_root_provider(self) -> Result<RootProvider<N>, Error> {
        Ok(self.root().to_owned())
    }
}

impl<N> IntoRootProvider<N> for DynProvider<N>
where
    N: Network,
{
    async fn into_root_provider(self) -> Result<RootProvider<N>, Error> {
        Ok(self.root().to_owned())
    }
}

impl<P, N> IntoRootProvider<N> for CallBatchProvider<P, N>
where
    P: Provider<N> + 'static,
    N: Network,
{
    async fn into_root_provider(self) -> Result<RootProvider<N>, Error> {
        Ok(self.root().to_owned())
    }
}

/// Conversion trait for types that can be turned into a [`RobustProvider`].
pub trait IntoRobustProvider<N: Network = Ethereum> {
    /// Convert `self` into a [`RobustProvider`].
    ///
    /// # Errors
    ///
    /// Returns an error if the primary or any fallback provider fails to connect.
    fn into_robust_provider(self) -> impl Future<Output = Result<RobustProvider<N>, Error>> + Send;
}

impl<N: Network> IntoRobustProvider<N> for RobustProvider<N> {
    async fn into_robust_provider(self) -> Result<RobustProvider<N>, Error> {
        Ok(self)
    }
}

impl<N: Network> IntoRobustProvider<N> for RootProvider<N> {
    async fn into_robust_provider(self) -> Result<RobustProvider<N>, Error> {
        RobustProviderBuilder::new(self).build().await
    }
}

impl<N: Network> IntoRobustProvider<N> for &str {
    async fn into_robust_provider(self) -> Result<RobustProvider<N>, Error> {
        RobustProviderBuilder::new(self).build().await
    }
}

impl<N: Network> IntoRobustProvider<N> for Url {
    async fn into_robust_provider(self) -> Result<RobustProvider<N>, Error> {
        RobustProviderBuilder::new(self).build().await
    }
}

impl<F, P, N> IntoRobustProvider<N> for FillProvider<F, P, N>
where
    F: TxFiller<N> + Send + 'static,
    P: Provider<N> + Send + 'static,
    N: Network,
{
    async fn into_robust_provider(self) -> Result<RobustProvider<N>, Error> {
        RobustProviderBuilder::new(self).build().await
    }
}

impl<P, N> IntoRobustProvider<N> for CacheProvider<P, N>
where
    P: Provider<N> + Send + 'static,
    N: Network,
{
    async fn into_robust_provider(self) -> Result<RobustProvider<N>, Error> {
        RobustProviderBuilder::new(self).build().await
    }
}

impl<N> IntoRobustProvider<N> for DynProvider<N>
where
    N: Network,
{
    async fn into_robust_provider(self) -> Result<RobustProvider<N>, Error> {
        RobustProviderBuilder::new(self).build().await
    }
}

impl<P, N> IntoRobustProvider<N> for CallBatchProvider<P, N>
where
    P: Provider<N> + Send + 'static,
    N: Network,
{
    async fn into_robust_provider(self) -> Result<RobustProvider<N>, Error> {
        RobustProviderBuilder::new(self).build().await
    }
}
