//! Abstractions for multiple block-production paths.
//!
//! Canonical flow: `ProductionInput::L1ProposalLog` is fed by the event scanner and routed to
//! `CanonicalL1ProductionPath`, which delegates to the derivation pipeline.
//!
//! Preconfirmation flow: external components can inject prebuilt payloads via the
//! `preconfirmation_sender` exposed on `EventSyncer` when `DriverConfig.preconfirmation_enabled` is
//! true. These payloads enter the `ProductionRouter` as `ProductionInput::Preconfirmation` and are
//! applied through `PreconfirmationPath`, which wraps `ExecutionPayloadInjector` to submit the
//! payload directly to the engine.

pub mod error;
pub mod kind;
pub mod path;
pub mod router;

pub use error::ProductionError;
pub use kind::{PreconfPayload, ProductionInput, ProductionPathKind};
pub use path::{BlockProductionPath, CanonicalL1ProductionPath, PreconfirmationPath};
pub use router::ProductionRouter;
