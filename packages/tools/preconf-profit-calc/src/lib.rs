//! Taiko L1 Event Monitor Library
//! 
//! This library provides functionality for monitoring Taiko L1 events
//! and calculating associated costs. It's designed to help operators
//! track their L1 gas expenses for batch proposals and proofs.
//! 
//! # Architecture
//! 
//! The library is organized into several modules:
//! - `config`: Command-line argument parsing
//! - `cost`: Cost tracking and calculations
//! - `decoder`: Event data decoding
//! - `events`: Event signature definitions
//! - `monitor`: Core monitoring logic
//! - `rpc`: Ethereum RPC client
//! - `types`: Common data structures

/// Configuration and command-line argument parsing
pub mod config;

/// Cost tracking and calculation module
pub mod cost;

/// Event decoding utilities
pub mod decoder;

/// Event signature definitions
pub mod events;

/// Core event monitoring functionality
pub mod monitor;

/// Ethereum RPC client
pub mod rpc;

/// Common type definitions
pub mod types;