//! Internal logging macros that wrap `tracing` when the feature is enabled.
//!
//! When the `tracing` feature is disabled, all logging calls compile to no-ops,
//! ensuring zero runtime cost for users who don't need observability.

#[allow(unused_macros)]
macro_rules! error {
    ($($arg:tt)*) => {
        #[cfg(feature = "tracing")]
        tracing::error!(target: "event_scanner", $($arg)*)
    };
}

#[allow(unused_macros)]
macro_rules! warn {
    ($($arg:tt)*) => {
        #[cfg(feature = "tracing")]
        tracing::warn!(target: "event_scanner", $($arg)*)
    };
}

#[allow(unused_macros)]
macro_rules! info {
    ($($arg:tt)*) => {
        #[cfg(feature = "tracing")]
        tracing::info!(target: "event_scanner", $($arg)*)
    };
}

#[allow(unused_macros)]
macro_rules! debug {
    ($($arg:tt)*) => {
        #[cfg(feature = "tracing")]
        tracing::debug!(target: "event_scanner", $($arg)*)
    };
}

#[allow(unused_macros)]
macro_rules! trace {
    ($($arg:tt)*) => {
        #[cfg(feature = "tracing")]
        tracing::trace!(target: "event_scanner", $($arg)*)
    };
}
