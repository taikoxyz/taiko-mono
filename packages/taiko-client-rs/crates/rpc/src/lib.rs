//! RPC client utilities for connecting to Taiko nodes.

pub mod auth;
pub mod beacon;
pub mod blob;
pub mod client;
pub mod error;
pub mod l1_origin;

pub use auth::TxPoolContentParams;
pub use error::{Result, RpcClientError};
pub use protocol::subscription_source::{
    JoinedRecommendedFillersWithWallet, SubscriptionSource, SubscriptionSourceError,
};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_subscription_source_try_from_ipc() {
        let source = SubscriptionSource::try_from("/path/to/ipc").unwrap();
        assert!(source.is_ipc());
        assert!(!source.is_ws());
    }

    #[test]
    fn test_subscription_source_try_from_ws() {
        let source = SubscriptionSource::try_from("ws://localhost:8546").unwrap();
        assert!(source.is_ws());
        assert!(!source.is_ipc());

        let source = SubscriptionSource::try_from("wss://localhost:8546").unwrap();
        assert!(source.is_ws());
        assert!(!source.is_ipc());
    }

    #[test]
    fn test_subscription_source_try_from_invalid_ws() {
        let result = SubscriptionSource::try_from("ws://[invalid");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("invalid websocket url"));
    }
}
