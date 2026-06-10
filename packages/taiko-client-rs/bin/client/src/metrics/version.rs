//! [`VersionInfo`] metrics for taiko-client

use once_cell::sync::Lazy;
use prometheus::{GaugeVec, Opts};

/// Application version gauge grouped by build metadata.
static VERSION_INFO: Lazy<GaugeVec> = Lazy::new(|| {
    let gauge = GaugeVec::new(
        Opts::new("taiko_client_info", "Taiko client build information"),
        &["version", "target_triple"],
    )
    .expect("valid taiko client version gauge");
    prometheus::register(Box::new(gauge.clone()))
        .expect("taiko client version gauge registration must succeed");
    gauge
});

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
        VERSION_INFO.with_label_values(&[self.version, self.target_triple]).set(1.0);
    }
}
