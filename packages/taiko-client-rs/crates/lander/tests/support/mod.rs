#![allow(dead_code)]
//! Shared actual-contract integration support, also imported by the real CLI tests.

pub mod contracts;
pub mod fixtures;
pub use contracts::ContractFixture;
