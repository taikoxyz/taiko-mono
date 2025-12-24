use anyhow::Result;
use futures::future::poll_fn;

use crate::{
    config::{NetworkConfig, P2pConfig},
    driver::NetworkDriver,
    handle::P2pHandle,
    validation::ValidationAdapter,
};

/// Minimal node wrapper around the network driver.
pub struct P2pNode {
    driver: NetworkDriver,
}

impl P2pNode {
    pub fn new(cfg: P2pConfig, validator: Box<dyn ValidationAdapter>) -> Result<(P2pHandle, Self)> {
        let net_cfg: NetworkConfig = cfg.into();
        let (driver, handle) = NetworkDriver::new_with_validator(net_cfg, validator)?;
        Ok((P2pHandle::new(handle), Self { driver }))
    }

    pub async fn run(mut self) -> Result<()> {
        loop {
            poll_fn(|cx| self.driver.poll(cx)).await;
        }
    }
}
