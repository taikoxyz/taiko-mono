//! Router that dispatches production inputs to the appropriate path.

use super::{BlockProductionPath, ProductionError, ProductionInput, ProductionPathKind};
use crate::{error::DriverError, sync::engine::EngineBlockOutcome};
use std::sync::Arc;

/// Routes `ProductionInput` to a compatible `BlockProductionPath`.
#[derive(Clone)]
pub struct ProductionRouter {
    paths: Vec<Arc<dyn BlockProductionPath + Send + Sync>>,
}

impl ProductionRouter {
    /// Create a router with the provided production paths.
    pub fn new(paths: Vec<Arc<dyn BlockProductionPath + Send + Sync>>) -> Self {
        Self { paths }
    }

    /// Route input to the first compatible path based on the variant.
    pub async fn produce(
        &self,
        input: ProductionInput,
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        let target_kind = match &input {
            ProductionInput::L1ProposalLog(_) => ProductionPathKind::L1Events,
            ProductionInput::Preconfirmation(_) => ProductionPathKind::Preconfirmation,
        };

        if let Some(path) = self.paths.iter().find(|path| path.kind() == target_kind) {
            return path.produce(input).await;
        }

        Err(ProductionError::MissingPath { kind: target_kind }.into())
    }
}
