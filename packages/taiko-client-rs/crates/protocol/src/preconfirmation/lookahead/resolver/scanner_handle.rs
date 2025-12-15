use std::mem::ManuallyDrop;
use tokio::task::JoinHandle;

/// RAII guard for the lookahead scanner task.
///
/// - Drop: aborts the underlying task to avoid leaking background work when the resolver goes out
///   of scope.
/// - `join()`: optional explicit await if the caller wants to observe completion errors instead of
///   aborting.
pub struct LookaheadScannerHandle {
    /// The join handle for the scanner task.
    handle: JoinHandle<()>,
}

impl LookaheadScannerHandle {
    /// Create a new scanner handle wrapping a spawned join handle.
    pub fn new(handle: JoinHandle<()>) -> Self {
        Self { handle }
    }

    /// Await the scanner task to finish. If the task panics or was aborted, the JoinError is
    /// returned to the caller.
    pub async fn join(self) -> Result<(), tokio::task::JoinError> {
        let this = ManuallyDrop::new(self);
        let handle = unsafe { std::ptr::read(&this.handle) };
        handle.await
    }
}

impl Drop for LookaheadScannerHandle {
    /// Abort the scanner task when the handle is dropped.
    fn drop(&mut self) {
        self.handle.abort();
    }
}

impl From<JoinHandle<()>> for LookaheadScannerHandle {
    /// Convert a JoinHandle into a LookaheadScannerHandle.
    fn from(handle: JoinHandle<()>) -> Self {
        Self::new(handle)
    }
}
