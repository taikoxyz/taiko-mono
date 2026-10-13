//! Etna forced inclusion: protocol constants. No I/O.
//!
//! The Inbox keeps a queue of forced inclusion entries (layout in
//! [`l1::layout::inbox`](crate::l1::layout::inbox)); the genesis record carries the delay after
//! which an entry is due and every anchor proves the queue's head and tail.

/// Expiry `E`, in seconds (14 days): an entry whose timestamp plus `E` an anchor has reached is
/// expired. The genesis forced inclusion delay must be below it.
pub const FORCED_INCLUSION_EXPIRY_SECS: u64 = 1_209_600;
