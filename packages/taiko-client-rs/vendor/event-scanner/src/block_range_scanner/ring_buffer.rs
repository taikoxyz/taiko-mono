use std::collections::VecDeque;

/// Configuration for how many past block hashes to retain for reorg detection.
///
/// This type is re-exported as `PastBlocksStorageCapacity` from the crate root.
#[derive(Copy, Clone, Debug)]
pub enum RingBufferCapacity {
    /// Keep at most `n` items.
    ///
    /// A value of `0` disables storing past block hashes and effectively disables reorg
    /// detection.
    Limited(usize),
    /// Keep an unbounded number of items.
    ///
    /// WARNING: This can lead to unbounded memory growth over long-running processes.
    /// Avoid using this in production deployments without an external bound.
    Infinite,
}

macro_rules! impl_from_unsigned {
    ($target:ty; $($source:ty),+ $(,)?) => {
        $(
            impl From<$source> for $target {
                fn from(value: $source) -> Self {
                    RingBufferCapacity::Limited(value as usize)
                }
            }
        )+
    };
}

impl_from_unsigned!(RingBufferCapacity; u8, u16, u32, usize);

#[derive(Clone, Debug)]
pub(crate) struct RingBuffer<T> {
    inner: VecDeque<T>,
    capacity: RingBufferCapacity,
}

impl<T> RingBuffer<T> {
    /// Creates an empty [`RingBuffer`] with a specific capacity.
    pub fn new(capacity: RingBufferCapacity) -> Self {
        if let RingBufferCapacity::Limited(limit) = capacity {
            Self { inner: VecDeque::with_capacity(limit), capacity }
        } else {
            Self { inner: VecDeque::new(), capacity }
        }
    }

    /// Adds a new element to the buffer.
    ///
    /// If limited capacity and the buffer is full, the oldest element is removed to make space.
    pub fn push(&mut self, item: T) {
        match self.capacity {
            RingBufferCapacity::Infinite => {
                self.inner.push_back(item); // Add the new element
            }
            RingBufferCapacity::Limited(0) => {
                // Do nothing, reorg handling disabled
            }
            RingBufferCapacity::Limited(limit) => {
                if self.inner.len() == limit {
                    self.inner.pop_front(); // Remove the oldest element
                }
                self.inner.push_back(item); // Add the new element
            }
        }
    }

    /// Removes and returns the newest element from the buffer.
    pub fn pop_back(&mut self) -> Option<T> {
        self.inner.pop_back()
    }

    /// Returns a reference to the newest element in the buffer.
    pub fn back(&self) -> Option<&T> {
        self.inner.back()
    }

    /// Clears all elements currently stored in the buffer.
    pub fn clear(&mut self) {
        self.inner.clear();
    }
}
