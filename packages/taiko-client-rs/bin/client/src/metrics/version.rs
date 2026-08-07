//! [`VersionInfo`] metrics for taiko-client

use once_cell::sync::Lazy;
use prometheus::{GaugeVec, Opts};

/// Application version gauge labelled by crate version.
static VERSION_INFO: Lazy<GaugeVec> = Lazy::new(|| {
    let gauge = GaugeVec::new(
        Opts::new("taiko_client_info", "Taiko client build information"),
        &["version"],
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
}

impl VersionInfo {
    /// Creates a new instance of [`VersionInfo`].
    pub const fn new(version: &'static str) -> Self {
        Self { version }
    }

    /// Exposes taiko-client's version information over prometheus.
    pub fn register_version_metrics(&self) {
        VERSION_INFO.with_label_values(&[self.version]).set(1.0);
    }
}
