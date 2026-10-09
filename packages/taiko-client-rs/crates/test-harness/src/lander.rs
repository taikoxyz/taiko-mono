//! The fake lander: keeps `lastCheckpoint` and the landed committee records moving behind the
//! chain (spec §9.2).

use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Duration,
};

use abci::{Schedule, committee::record_hash};
use alloy_eips::BlockNumberOrTag;
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result};
use tokio::task::JoinHandle;

use crate::{
    cometbft::CmtClient,
    planter::{InboxValues, Planter},
};

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
    /// The CometBFT RPC whose app serves `/committee/<epoch>` (node 0).
    pub cmt: CmtClient,
    /// The chain's schedule.
    pub schedule: Schedule,
    /// The L2 chain id (record hashes).
    pub l2_chain_id: u64,
}

/// The lander's switches, shared with its task.
#[derive(Debug)]
struct Switches {
    /// While set, ticks write nothing.
    paused: AtomicBool,
    /// While set, ticks plant committee records; while clear, only `lastCheckpoint` moves.
    land_committees: AtomicBool,
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
    /// Spawns the lander; it plants committee records iff `land_committees`.
    pub(crate) fn spawn(ctx: LanderCtx, land_committees: bool) -> Self {
        let switches = Arc::new(Switches {
            paused: AtomicBool::new(false),
            land_committees: AtomicBool::new(land_committees),
        });
        let task = tokio::spawn(run(ctx, switches.clone()));
        Self { switches, task }
    }

    /// Pauses (`true`) or resumes (`false`) landing.
    pub(crate) fn set_paused(&self, paused: bool) {
        self.switches.paused.store(paused, Ordering::SeqCst);
    }

    /// Enables (`true`) or disables (`false`) planting committee records; `lastCheckpoint` keeps
    /// moving either way (unless paused).
    pub(crate) fn set_land_committees(&self, land: bool) {
        self.switches.land_committees.store(land, Ordering::SeqCst);
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
    /// The next epoch whose committee record is still to be planted.
    next_epoch: u64,
}

/// The lander loop: one [`tick`] every [`TICK`] unless paused; errors are logged and retried.
async fn run(ctx: LanderCtx, switches: Arc<Switches>) {
    let mut landed = Landed { height: None, next_epoch: Schedule::E0 + 1 };
    loop {
        tokio::time::sleep(TICK).await;
        if switches.paused.load(Ordering::SeqCst) {
            continue;
        }
        let land_committees = switches.land_committees.load(Ordering::SeqCst);
        if let Err(e) = tick(&ctx, &mut landed, land_committees).await {
            tracing::debug!(error = format!("{e:#}"), "fake lander tick failed");
        }
    }
}

/// Plants `lastCheckpoint = (head − TRAIL, its hash)` and, when `land_committees`, every
/// committee record whose deriving block `h_first(t − 1)` is landed and that the app already
/// knows.
async fn tick(ctx: &LanderCtx, landed: &mut Landed, land_committees: bool) -> Result<()> {
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
    let Some(height) = landed.height else { return Ok(()) };
    if !land_committees {
        return Ok(());
    }
    loop {
        let t = landed.next_epoch;
        if ctx.schedule.h_first(t - 1) > height {
            return Ok(());
        }
        let Some(committee) = ctx.cmt.committee(t).await? else { return Ok(()) };
        let values = InboxValues {
            committee: vec![(t, record_hash(ctx.l2_chain_id, &committee.record))],
            ..Default::default()
        };
        ctx.planter.plant_inbox(&values).await?;
        tracing::info!(epoch = t, "fake lander: committee record planted");
        landed.next_epoch = t + 1;
    }
}
