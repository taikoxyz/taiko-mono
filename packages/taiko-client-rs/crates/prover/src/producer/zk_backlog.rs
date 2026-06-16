//! raiko2 control-plane interface for draining the ZK (`zk_any`) task backlog
//! and reporting when the backend is idle (raiko2 #93). Mirrors Go's
//! `ZKBacklogController` interface (`prover/proof_producer/zk_backlog.go`).

use async_trait::async_trait;

use crate::raiko::RaikoError;

/// A proof backend whose host exposes the raiko2 ZK-backlog control plane.
#[async_trait]
pub trait ZkBacklogController: Send + Sync {
    /// Discard all non-terminal `zk_any` tasks (`POST /v3/prover/clear`).
    async fn clear_backlog(&self) -> Result<(), RaikoError>;
    /// Whether the ZK backend is fully idle (`data.clean` of
    /// `GET /v3/prover/status`).
    async fn status_clean(&self) -> Result<bool, RaikoError>;
}
