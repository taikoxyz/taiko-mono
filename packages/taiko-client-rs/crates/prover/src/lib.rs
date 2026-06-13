#![cfg_attr(not(test), deny(missing_docs, clippy::missing_docs_in_private_items))]
#![cfg_attr(test, allow(missing_docs, clippy::missing_docs_in_private_items))]
//! Taiko Alethia prover: watches Shasta inbox proposals, generates proofs via
//! raiko, aggregates them, and submits them to the inbox contract.

pub mod buffer;
pub mod cache;
pub mod error;
pub mod producer;
pub mod raiko;
pub mod submitter;
