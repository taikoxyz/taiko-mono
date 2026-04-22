//! Manifest utilities for derivation pipelines.

/// Manifest fetchers and decoding helpers per fork.
pub mod fetcher;

pub use fetcher::{ManifestFetcher, ManifestFetcherError, ShastaSourceManifestFetcher};
