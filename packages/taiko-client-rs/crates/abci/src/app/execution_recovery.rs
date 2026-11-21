//! Re-feeding locally committed payloads without trusting a peer or an uncommitted proposal.

use std::{
    sync::{Arc, MutexGuard, PoisonError},
    time::Duration,
};
use tokio::{sync::oneshot, task::JoinHandle};

use super::{AbciError, App, within};
use crate::{
    engine::{Engine, PayloadVerdict},
    envelope::ExecutionBlock,
    l1::L1Source,
    store::{AppState, ExecutionFloor, Record, Store},
    types::ParentInfo,
};

/// Complete committed context authorizing one owned execution replay.
#[derive(Clone, Debug, PartialEq, Eq)]
struct ExecutionRepairKey {
    /// Full deployment and recovery signing domain.
    chain_id: String,
    /// Authenticated recovery generation.
    generation: u64,
    /// Exact committed execution parent.
    parent: ParentInfo,
    /// First height whose predecessor's state is external to this generation.
    origin_height: u64,
    /// Optional imported state that may never be rebuilt from older sidecars.
    execution_floor: Option<ExecutionFloor>,
}

impl ExecutionRepairKey {
    /// Binds every repair result to the committed history and its state boundary.
    fn from_state(state: &AppState) -> Self {
        Self {
            chain_id: state.chain_id.clone(),
            generation: state.generation,
            parent: state.parent.clone(),
            origin_height: state.origin_height(),
            execution_floor: state.execution_floor,
        }
    }
}

/// What one attempt to restore the committed execution suffix achieved
/// ([`App::restore_committed_execution`]).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum SuffixRestore {
    /// The EL serves the committed head again, or already did.
    Restored,
    /// Re-executing needs material at this height that is unavailable: the retained execution
    /// body of a committed block above the generation origin or import floor, or the EL's own
    /// block and state at that origin or floor, which no retained body recreates.
    Missing(u64),
    /// The EL answered `SYNCING` to the committed payload at this height.
    Syncing(u64),
}

impl SuffixRestore {
    /// Whether the EL serves the committed head again.
    pub(super) fn restored(self) -> bool {
        self == Self::Restored
    }
}

/// A Prepare-only payload replay; its task never sends forkchoice updates.
#[derive(Debug)]
pub(super) struct OwnedExecutionRepair {
    /// Immutable authority and availability boundary of this flight.
    key: ExecutionRepairKey,
    /// Original typed completion, retained when a preparation waiter is cancelled.
    result: oneshot::Receiver<Result<bool, AbciError>>,
    /// A successful completion stays reusable if a later handler FCU hits its deadline.
    ready: Option<bool>,
    /// A foreground FCU completed; a later waiter first confirms its canonical parent.
    pointed: bool,
    /// Fatal evidence destination if the app drops after a failure was delivered.
    store: Store,
    /// Owned work, aborted when its app or committed context is retired.
    task: JoinHandle<()>,
}

impl OwnedExecutionRepair {
    /// Harvests an already-delivered typed error before retirement; incomplete work remains
    /// safe to abort. Successful completion is retained without polling its receiver again.
    fn delivered_error(&mut self) -> Option<AbciError> {
        if self.ready.is_some() {
            return None
        }
        match self.result.try_recv() {
            Ok(Err(error)) => Some(error),
            Ok(Ok(ready)) => {
                self.ready = Some(ready);
                None
            }
            Err(_) => None,
        }
    }
}

impl Drop for OwnedExecutionRepair {
    /// Aborts incomplete work and preserves a delivered fatal failure even on App drop,
    /// where no request remains to carry it through the ordinary handler error barrier.
    fn drop(&mut self) {
        self.result.close();
        self.task.abort();
        if let Some(error) = self.delivered_error() &&
            (matches!(error, AbciError::SafetyHalt(_) | AbciError::Store(_)) ||
                super::classify(&error) == super::ErrorClass::Contradiction) &&
            let Err(persist) = self.store.record_fatal(&error.to_string())
        {
            tracing::error!(%error, persist_error = %persist,
                    "could not preserve a delivered execution repair failure on drop");
        }
    }
}

impl<L: L1Source, E: Engine> App<L, E> {
    /// Locks the owned flight without carrying the guard across an await.
    fn execution_repair(&self) -> MutexGuard<'_, Option<OwnedExecutionRepair>> {
        self.execution_repair.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// Retires preparation work before another handler changes context, returning any
    /// already-delivered original error instead of dropping its completion channel.
    pub(super) fn clear_execution_repair(&self) -> Result<(), AbciError> {
        let Some(mut flight) = self.execution_repair().take() else { return Ok(()) };
        flight.result.close();
        flight.task.abort();
        match flight.delivered_error() {
            Some(error) => Err(error),
            None => Ok(()),
        }
    }

    /// Checks or repairs an execution parent synchronously for Process/Finalize retries.
    /// Transient evidence remains unavailable; contradictory evidence halts without building.
    pub(super) async fn execution_parent_ready(&self, state: &AppState) -> Result<bool, AbciError> {
        let repair = async {
            self.clear_execution_repair()?;
            self.check_or_repair_execution_parent(state).await
        };
        parent_repair_result(repair.await, state.last_height)
    }

    /// Lets an owned, context-bound payload replay survive this Prepare request's deadline.
    /// The waiting handler alone sends FCU after replay completes; the task imports no candidate.
    pub(super) async fn preparation_execution_parent_ready(
        &self,
        state: &AppState,
    ) -> Result<bool, AbciError> {
        parent_repair_result(self.prepare_execution_parent(state).await, state.last_height)
    }

    /// Checks the ordinary parent directly, or waits for exactly one retained repair flight.
    async fn prepare_execution_parent(&self, state: &AppState) -> Result<bool, AbciError> {
        let key = ExecutionRepairKey::from_state(state);
        let obsolete = self.execution_repair().as_ref().is_some_and(|active| active.key != key);
        if obsolete {
            self.clear_execution_repair()?;
        }
        let active = self.execution_repair().is_some();
        if !active {
            if committed_parent_present(self.engine(), state, self.opts.engine_timeout).await? {
                return Ok(true);
            }
            let engine = Arc::clone(&self.engine);
            let store = self.store.clone();
            let parent = state.clone();
            let timeout = self.opts.engine_timeout;
            let (sender, result) = oneshot::channel();
            let task = tokio::spawn(async move {
                let result = restore_execution_suffix(engine.as_ref(), &store, &parent, timeout)
                    .await
                    .map(SuffixRestore::restored);
                let _ = sender.send(result);
            });
            *self.execution_repair() = Some(OwnedExecutionRepair {
                key: key.clone(),
                result,
                ready: None,
                pointed: false,
                store: self.store.clone(),
                task,
            });
        }
        loop {
            let completed = {
                let mut flight = self.execution_repair();
                let Some(active) = flight.as_mut().filter(|active| active.key == key) else {
                    return Ok(false)
                };
                match active.ready {
                    Some(ready) => Some(Ok(ready)),
                    None => match active.result.try_recv() {
                        Ok(Ok(ready)) => {
                            active.ready = Some(ready);
                            Some(Ok(ready))
                        }
                        Ok(Err(error)) => {
                            flight.take();
                            Some(Err(error))
                        }
                        Err(oneshot::error::TryRecvError::Empty) => None,
                        Err(oneshot::error::TryRecvError::Closed) => {
                            flight.take();
                            Some(Err(AbciError::SafetyHalt(
                                "owned execution repair stopped without a result".into(),
                            )))
                        }
                    },
                }
            };
            if let Some(completed) = completed {
                completed?;
                // A prior waiter may have completed FCU but timed out on its confirming read.
                // Check that completion first so the same FCU/read pair cannot starve forever.
                let pointed = self
                    .execution_repair()
                    .as_ref()
                    .is_some_and(|active| active.key == key && active.pointed);
                if !pointed {
                    self.point_committed_head(state.last_height, state).await?;
                    if let Some(active) =
                        self.execution_repair().as_mut().filter(|active| active.key == key)
                    {
                        active.pointed = true;
                    }
                }
                let ready =
                    committed_parent_present(self.engine(), state, self.opts.engine_timeout)
                        .await?;
                self.clear_execution_repair()?;
                return Ok(ready);
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    }

    /// Repairs only a proven missing parent and checks its canonical identity again afterward.
    async fn check_or_repair_execution_parent(&self, state: &AppState) -> Result<bool, AbciError> {
        if committed_parent_present(self.engine(), state, self.opts.engine_timeout).await? {
            return Ok(true);
        }
        self.nudge_committed_head(state.last_height, state).await?;
        committed_parent_present(self.engine(), state, self.opts.engine_timeout).await
    }

    /// Authenticates and re-feeds the committed suffix without changing forkchoice. Other
    /// handlers supersede any Prepare-only flight before doing their own synchronous repair.
    pub(super) async fn restore_committed_execution(
        &self,
        state: &AppState,
    ) -> Result<SuffixRestore, AbciError> {
        self.clear_execution_repair()?;
        restore_execution_suffix(self.engine(), &self.store, state, self.opts.engine_timeout).await
    }
}

/// Preserves typed repair failures while mapping transient acquisition to unavailable state.
fn parent_repair_result(result: Result<bool, AbciError>, height: u64) -> Result<bool, AbciError> {
    match result {
        Ok(ready) => Ok(ready),
        Err(error) if super::classify(&error) == super::ErrorClass::MissingData => {
            tracing::warn!(height, %error, "committed execution parent unavailable");
            Ok(false)
        }
        Err(error) if super::classify(&error) == super::ErrorClass::Contradiction => {
            Err(super::contradiction_halt(error))
        }
        Err(error) => Err(error),
    }
}

/// Reads the exact canonical parent; an alternate served hash is a contradiction.
async fn committed_parent_present<E: Engine>(
    engine: &E,
    state: &AppState,
    timeout: Duration,
) -> Result<bool, AbciError> {
    match within("EL proposal parent", timeout, engine.header_by_number(state.last_height)).await? {
        Some(header) if header.hash_slow() == state.parent.hash => Ok(true),
        Some(_) => Err(AbciError::SafetyHalt(format!(
            "execution parent at {} contradicts committed hash {}",
            state.last_height, state.parent.hash
        ))),
        None => Ok(false),
    }
}

/// Authenticates backward from the committed head to an existing stateful origin/import
/// ancestor, then re-reads one body at a time forward. No payload at/below the floor is replayed;
/// absent/corrupt auxiliary data is unavailable, reported with the first height that lacks it.
/// This function never changes forkchoice.
async fn restore_execution_suffix<E: Engine>(
    engine: &E,
    store: &Store,
    state: &AppState,
    timeout: Duration,
) -> Result<SuffixRestore, AbciError> {
    let floor = state.execution_floor.map_or(state.origin_height(), |floor| floor.number);
    let mut number = state.last_height;
    let mut expected = state.parent.hash;
    loop {
        let header =
            within("EL recovery ancestor", timeout, engine.header_by_number(number)).await?;
        if let Some(header) = header {
            if header.hash_slow() != expected {
                return Err(AbciError::SafetyHalt(format!(
                    "execution recovery ancestor at {number} contradicts committed hash {expected}"
                )));
            }
            if within(
                "EL recovery ancestor state",
                timeout,
                engine.historical_state_available(expected),
            )
            .await?
            {
                break;
            }
        }
        if number <= floor {
            return Ok(SuffixRestore::Missing(number));
        }
        let Some(block) = execution_recovery_body(store, number)? else {
            return Ok(SuffixRestore::Missing(number));
        };
        if block.header.hash_slow() != expected {
            return Err(AbciError::SafetyHalt(format!(
                "durable execution block at {number} contradicts committed hash {expected}"
            )));
        }
        expected = block.header.parent_hash;
        number -= 1;
    }
    if number == state.last_height {
        return Ok(SuffixRestore::Restored);
    }
    tracing::info!(
        from = number + 1,
        to = state.last_height,
        "restoring committed execution suffix from durable local payloads"
    );
    // Reread one body at a time after authenticating the whole backward chain. This keeps
    // recovery memory bounded even when a long generation has lost its execution history.
    let mut parent = expected;
    for height in number + 1..=state.last_height {
        let Some(block) = execution_recovery_body(store, height)? else {
            return Ok(SuffixRestore::Missing(height));
        };
        if block.header.parent_hash != parent {
            return Err(AbciError::SafetyHalt(format!(
                "durable execution parent changed during recovery at {height}"
            )));
        }
        parent = block.header.hash_slow();
        match within("EL recovery newPayload", timeout, engine.new_payload(&block)).await? {
            PayloadVerdict::Valid => {}
            PayloadVerdict::Syncing => return Ok(SuffixRestore::Syncing(height)),
            PayloadVerdict::Invalid(reason) => {
                return Err(AbciError::SafetyHalt(format!(
                    "execution engine rejected committed recovery payload {}: {reason}",
                    block.header.number
                )))
            }
        }
    }
    if parent != state.parent.hash {
        return Err(AbciError::SafetyHalt(
            "durable execution suffix changed its committed head during recovery".into(),
        ));
    }
    Ok(SuffixRestore::Restored)
}

/// Checks one checksum-framed execution body in either traversal before any EL use.
/// Coherent invalid commitments halt; checksum/decode failures remain unavailable data.
fn execution_recovery_body(
    store: &Store,
    height: u64,
) -> Result<Option<ExecutionBlock>, AbciError> {
    let block = match store.load_execution_block(height)? {
        Record::Valid(block) => block,
        missing => {
            tracing::warn!(
                height,
                ?missing,
                "committed execution body unavailable for EL recovery"
            );
            return Ok(None);
        }
    };
    super::check_execution_size(&block).map_err(|error| {
        AbciError::SafetyHalt(format!("invalid durable execution block: {error}"))
    })?;
    crate::engine::convert::payload_from_block(&block).map_err(|error| {
        AbciError::SafetyHalt(format!("invalid durable execution body: {error}"))
    })?;
    Ok(Some(block))
}
