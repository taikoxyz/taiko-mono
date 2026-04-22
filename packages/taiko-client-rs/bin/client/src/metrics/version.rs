//! [`VersionInfo`] metrics for taiko-client

use metrics::gauge;

/// Contains version information for the application.
#[derive(Debug, Clone)]
pub struct VersionInfo {
    /// The version of the application.
    pub version: &'static str,
    /// The target triple for the build.
    pub target_triple: &'static str,
}

impl VersionInfo {
    /// Creates a new instance of [`VersionInfo`].
    pub const fn new(version: &'static str, target_triple: &'static str) -> Self {
        Self { version, target_triple }
    }

    /// Exposes taiko-client's version information over prometheus.
    pub fn register_version_metrics(&self) {
        let labels: [(&str, &str); 2] =
            [("version", self.version), ("target_triple", self.target_triple)];

        let gauge = gauge!("taiko_client_info", &labels);
        gauge.set(1);
    }
}
