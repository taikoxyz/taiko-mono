//! Manifest utilities for derivation pipelines.

pub mod fetcher;

pub use fetcher::{ManifestFetcher, ManifestFetcherError, ShastaSourceManifestFetcher};
