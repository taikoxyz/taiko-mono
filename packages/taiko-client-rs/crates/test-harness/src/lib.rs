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
//! and the network and deletes the temporary directories. Dropping it without a successful
//! [`Devnet::stop`] (a scenario that panics or returns an error) first prints each app's halt
//! reason and the tail of every container's log, as does a failed [`Devnet::wait_for_height`].

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
pub use l1::{anvil_request, block_number, finalized_number, mine_l1_blocks, set_interval_mining};
pub use l2::{DEV_KEY, anchor_of, dev_signer, extra_data_of, send_transfer};
pub use planter::{InboxValues, NextBlock, Planter, registry_entry};
pub use wait::{Fatal, wait_until};
