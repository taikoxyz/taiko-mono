//! Docker devnet harness for the Etna PoS `abci` app.
//!
//! [`Devnet::start`] boots one throw-away devnet per test: an anvil L1, one alethia-reth EL and
//! one CometBFT node per validator (docker containers on a private network, host ports chosen by
//! docker), and one in-process `abci` app per validator that its CometBFT node reaches through
//! `host.docker.internal`; each app runs on its own OS thread and tokio runtime, so a test can
//! stop it completely and start it again ([`Devnet::app_stop`], [`Devnet::app_start`]). Controlled
//! shutdown uses [`Devnet::node_stop`]: Comet first, then the app, with bounded forced reaping.
//! An app-only crash does not guarantee that CometBFT's shutdown finishes. Before
//! the apps start it plants an initialized Inbox and a staking registry into anvil with
//! [`Planter`] and builds the CometBFT genesis from that L1 state with `abci::build_genesis`. A
//! background fake lander advances only `lastCheckpoint` behind the chain; autonomous committee
//! activation needs no publication, while paused settlement still exercises back-pressure.
//! Scenarios plant calldata forced inclusion entries with their admission events
//! ([`Planter::plant_forced_transaction`]).
//!
//! Awaiting [`Devnet::stop`] stops each Comet/app pair before removing every container. Dropping
//! a [`Devnet`] force-cleans the owned resources. Both remove the containers and network and
//! delete the temporary directories. Dropping it without a successful
//! [`Devnet::stop`] (a scenario that panics or returns an error) first prints each app's halt
//! reason and the tail of every container's log, as does a failed [`Devnet::wait_for_height`].

mod anvil;
mod app;
mod boot;
mod cleanup;
mod cometbft;
mod consensus;
mod devnet;
mod docker;
pub mod genesis;
mod keys;
mod l1;
mod l2;
mod lander;
mod planter;
mod signer;
mod wait;

pub use anvil::StandaloneAnvil;
pub use cometbft::{CmtClient, CmtStatus, CmtValidator};
pub use consensus::ContractConsensus;
pub use devnet::{Devnet, DevnetSpec, init_tracing};
pub use genesis::{EtnaGenesis, StandaloneReth};
pub use keys::{NodeKey, ValidatorKey, node_keys, validator_keys};
pub use l1::{anvil_request, block_number, finalized_number, mine_l1_blocks, set_interval_mining};
pub use l2::{DEV_KEY, anchor_of, dev_signer, extra_data_of, send_transfer, sign_transfer};
pub use planter::{InboxValues, NextBlock, PlantedEntry, Planter, registry_entry};
pub use wait::{Fatal, wait_until};

/// Explicitly unavailable EL for tests that must never require execution evidence.
pub mod unavailable_engine;
