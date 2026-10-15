//! Fail-closed no-network engine for ordinary/included fixture paths.
use abci::{
    Engine, EngineError, ExecutionBlock,
    engine::{PayloadVerdict, PoolSelection},
};
use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::consensus::{Header, TxEnvelope};
use alloy_primitives::B256;
#[derive(Debug)]
pub struct UnavailableEngine;
fn unavailable() -> EngineError {
    EngineError::Setup("test engine has no execution state".into())
}
#[async_trait::async_trait]
impl Engine for UnavailableEngine {
    async fn check_capabilities(&self) -> Result<(), EngineError> {
        Err(unavailable())
    }
    async fn pool_transactions(
        &self,
        _selection: PoolSelection,
    ) -> Result<Vec<TxEnvelope>, EngineError> {
        Err(unavailable())
    }
    async fn build_block(
        &self,
        _parent: B256,
        _attrs: TaikoPayloadAttributes,
    ) -> Result<ExecutionBlock, EngineError> {
        Err(unavailable())
    }
    async fn new_payload(&self, _block: &ExecutionBlock) -> Result<PayloadVerdict, EngineError> {
        Err(unavailable())
    }
    async fn forkchoice(
        &self,
        _head: B256,
        _safe: B256,
        _finalized: B256,
    ) -> Result<PayloadVerdict, EngineError> {
        Err(unavailable())
    }
    async fn header_by_number(&self, _number: u64) -> Result<Option<Header>, EngineError> {
        Err(unavailable())
    }
}

/// Scripted singleton evidence for tests of callers' completed-decision handling.
pub struct ProbeEngine {
    pub parent: Header,
    pub result: Result<ExecutionBlock, EngineError>,
    pub delay: std::time::Duration,
}
#[async_trait::async_trait]
impl Engine for ProbeEngine {
    async fn check_capabilities(&self) -> Result<(), EngineError> {
        Err(unavailable())
    }
    async fn pool_transactions(&self, _: PoolSelection) -> Result<Vec<TxEnvelope>, EngineError> {
        Err(unavailable())
    }
    async fn build_block(
        &self,
        parent: B256,
        _attrs: TaikoPayloadAttributes,
    ) -> Result<ExecutionBlock, EngineError> {
        if parent != self.parent.hash_slow() {
            return Err(unavailable());
        }
        tokio::time::sleep(self.delay).await;
        self.result.clone()
    }
    async fn new_payload(&self, _: &ExecutionBlock) -> Result<PayloadVerdict, EngineError> {
        Err(unavailable())
    }
    async fn forkchoice(&self, _: B256, _: B256, _: B256) -> Result<PayloadVerdict, EngineError> {
        Err(unavailable())
    }
    async fn header_by_number(&self, number: u64) -> Result<Option<Header>, EngineError> {
        Ok((number == self.parent.number).then(|| self.parent.clone()))
    }
}
