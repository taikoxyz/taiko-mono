//! The fake lander advances only the settled checkpoint behind the execution head.

use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Duration,
};

use alloy_eips::BlockNumberOrTag;
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result};
use tokio::{sync::Mutex, task::JoinHandle};

use crate::planter::{InboxValues, Planter};

/// How often the lander runs.
const TICK: Duration = Duration::from_millis(500);

/// How far `lastCheckpoint` trails the EL head, in L2 blocks.
const TRAIL: u64 = 2;

/// What the lander reads and writes.
#[derive(Clone, Debug)]
pub(crate) struct LanderCtx {
    /// Writes the Inbox.
    pub planter: Planter,
    /// The EL whose head is landed (node 0).
    pub l2: RootProvider,
}

/// The lander's switches, shared with its task.
#[derive(Debug)]
struct Switches {
    /// While set, ticks write nothing.
    paused: AtomicBool,
    /// Held by the task for the whole of a tick, from its pause check until its last write is
    /// mined, so that [`Lander::pause`] can wait out a tick in flight.
    tick: Mutex<()>,
}

/// The running lander task.
#[derive(Debug)]
pub(crate) struct Lander {
    /// The switches the task reads every tick.
    switches: Arc<Switches>,
    /// The task.
    task: JoinHandle<()>,
}

impl Lander {
    /// Spawns the checkpoint-only fake lander.
    pub(crate) fn spawn(ctx: LanderCtx) -> Self {
        let switches = Arc::new(Switches { paused: AtomicBool::new(false), tick: Mutex::new(()) });
        let task = tokio::spawn(run(ctx, switches.clone()));
        Self { switches, task }
    }

    /// Pauses landing and returns once a tick already in flight has finished (its writes
    /// mined), so no landing happens after it returns.
    pub(crate) async fn pause(&self) {
        self.switches.paused.store(true, Ordering::SeqCst);
        // A tick that read `paused` before the store holds the lock until it is done; one that
        // takes the lock after this point sees the pause.
        drop(self.switches.tick.lock().await);
    }

    /// Resumes landing.
    pub(crate) fn resume(&self) {
        self.switches.paused.store(false, Ordering::SeqCst);
    }

    /// Stops the task.
    pub(crate) fn stop(&self) {
        self.task.abort();
    }
}

impl Drop for Lander {
    /// Stops the task.
    fn drop(&mut self) {
        self.stop();
    }
}

/// What the lander has planted so far.
#[derive(Debug)]
struct Landed {
    /// The planted `lastCheckpoint.height`.
    height: Option<u64>,
}

/// The lander loop: one [`tick`] every [`TICK`] unless paused; errors are logged and retried.
async fn run(ctx: LanderCtx, switches: Arc<Switches>) {
    let mut landed = Landed { height: None };
    loop {
        tokio::time::sleep(TICK).await;
        let _tick = switches.tick.lock().await;
        if switches.paused.load(Ordering::SeqCst) {
            continue;
        }
        if let Err(e) = tick(&ctx, &mut landed).await {
            tracing::debug!(error = format!("{e:#}"), "fake lander tick failed");
        }
    }
}

/// Advances the checkpoint to `head-TRAIL`; no committee record is published.
async fn tick(ctx: &LanderCtx, landed: &mut Landed) -> Result<()> {
    let head = ctx.l2.get_block_number().await.context("L2 eth_blockNumber")?;
    let target = head.saturating_sub(TRAIL);
    if landed.height.is_none_or(|h| h < target) {
        let block = ctx
            .l2
            .get_block_by_number(BlockNumberOrTag::Number(target))
            .await?
            .with_context(|| format!("L2 block {target} missing"))?;
        let values = InboxValues {
            last_checkpoint: Some((target, block.header.hash)),
            ..Default::default()
        };
        ctx.planter.plant_inbox(&values).await?;
        tracing::debug!(height = target, "fake lander: lastCheckpoint planted");
        landed.height = Some(target);
    }
    Ok(())
}
