//! Docker devnet harness for the Etna PoS `abci` app (spec §9.2).
//!
//! [`Devnet::start`] boots one throw-away devnet per test: an anvil L1, one alethia-reth EL and
//! one CometBFT node per validator (docker containers on a private network, host ports chosen by
//! docker), and one in-process `abci` app per validator that its CometBFT node reaches through
//! `host.docker.internal`; each app runs on its own OS thread and tokio runtime, so a test can
//! stop it completely and start it again ([`Devnet::app_stop`], [`Devnet::app_start`]). Before
//! the apps start it plants an activated Inbox and a staking registry into anvil with
//! [`Planter`] and builds the CometBFT genesis from that L1 state with `abci::build_genesis`. A
//! background fake lander keeps `lastCheckpoint` and the landed committee records moving behind the
//! chain, so back-pressure and the epoch switch never stall a scenario unless the test pauses it.
//!
//! Dropping a [`Devnet`] (or awaiting [`Devnet::stop`]) stops the apps, removes every container
//! and the network and deletes the temporary directories; on a panic it first prints the tail of
//! every container's log.

mod app;
mod boot;
mod cometbft;
mod devnet;
mod docker;
mod keys;
mod l1;
mod l2;
mod lander;
mod planter;
mod wait;

pub use cometbft::{CmtClient, CmtStatus, CmtValidator};
pub use devnet::{Devnet, DevnetSpec, init_tracing};
pub use keys::{ValidatorKey, node_keys, validator_keys};
pub use l1::{
    advance_l1_time, anvil_request, block_number, finalized_number, mine_l1_blocks,
    set_interval_mining, set_storage,
};
pub use l2::{DEV_KEY, dev_signer, send_transfer};
pub use planter::{InboxValues, NextBlock, Planter, registry_entry};
pub use wait::wait_until;
