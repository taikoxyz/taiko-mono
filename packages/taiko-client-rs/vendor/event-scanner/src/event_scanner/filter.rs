//! Event filtering for blockchain log queries.
//!
//! This module provides [`EventFilter`] which allows specifying contract addresses and event
//! signatures to filter logs when scanning the blockchain.

use std::fmt::{Debug, Display};

use alloy::{
    primitives::{Address, keccak256},
    rpc::types::{Filter, Topic, ValueOrArray},
};

/// Type representing filters to apply when fetching events from the chain.
///
/// # Examples
///
/// ```rust
/// use alloy::primitives::address;
/// use event_scanner::EventFilter;
///
/// pub async fn create_event_filter() -> EventFilter {
///     let contract_address = address!("0xd8dA6BF26964af9d7eed9e03e53415d37aa96045");
///     let filter = EventFilter::new()
///         .contract_address(contract_address)
///         .event("Transfer(address,address,uint256)");
///
///     filter
/// }
/// ```

#[derive(Clone, Default)]
pub struct EventFilter {
    /// Contract addresses to filter events from. If empty, events from all contracts will be
    /// tracked.
    pub(crate) contract_addresses: Vec<Address>,
    /// Human-readable event signatures, e.g. "Transfer(address,address,uint256)".
    pub(crate) events: Vec<String>,
    /// Event signature hashes, e.g. `0x123...`.
    pub(crate) event_signatures: Topic,
}

impl Display for EventFilter {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let mut content = vec![];
        if !self.contract_addresses.is_empty() {
            let contracts = self
                .contract_addresses
                .iter()
                .map(|addr| format!("{addr}"))
                .collect::<Vec<_>>()
                .join(", ");
            content.push(format!("contracts: [{contracts}]",));
        }
        if !self.events.is_empty() {
            content.push(format!("events: [{}]", self.events.join(", ")));
        }
        if let Some(value_or_array) = self.event_signatures.to_value_or_array() {
            // No guarantee the order of values returned by `Topic`
            let event_signatures = match value_or_array {
                ValueOrArray::Value(value) => format!("{value}"),
                ValueOrArray::Array(arr) => {
                    arr.iter().map(|t| format!("{t}")).collect::<Vec<_>>().join(", ")
                }
            };
            content.push(format!("event_signatures: [{event_signatures}]"));
        }

        write!(f, "EventFilter({})", content.join(", "))
    }
}

impl Debug for EventFilter {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self}")
    }
}

impl EventFilter {
    /// Creates a new [`EventFilter`].
    #[must_use]
    pub fn new() -> Self {
        EventFilter::default()
    }

    /// Sets the contract address to filter events from.
    /// If not set, events from all contracts will be tracked.
    #[must_use]
    pub fn contract_address(mut self, contract_address: impl Into<Address>) -> Self {
        self.contract_addresses.push(contract_address.into());
        self
    }

    /// Sets the contract address to filter events from.
    /// If not set, events from all contracts will be tracked.
    #[must_use]
    pub fn contract_addresses(
        mut self,
        contract_addresses: impl IntoIterator<Item = impl Into<Address>>,
    ) -> Self {
        self.contract_addresses.extend(contract_addresses.into_iter().map(Into::into));
        self
    }

    /// Sets the event signature to filter specific events.
    /// If neither events nor event signature hashes are set, all events from the specified
    /// contract(s) will be tracked.
    #[must_use]
    pub fn event(mut self, event: impl Into<String>) -> Self {
        let event = event.into();
        if !event.is_empty() {
            self.events.push(event);
        }
        self
    }

    /// Sets the event signatures to filter specific events.
    /// If neither events nor event signature hashes are set, all events from the specified
    /// contract(s) will be tracked.
    #[must_use]
    pub fn events(mut self, events: impl IntoIterator<Item = impl Into<String>>) -> Self {
        self.events.extend(events.into_iter().map(Into::into));
        self
    }

    /// Sets the event signature hash to filter specific events.
    /// If neither event signature hashes nor events are set, all events from the specified
    /// contract(s) will be tracked.
    #[must_use]
    pub fn event_signature(mut self, event_signature: impl Into<Topic>) -> Self {
        self.event_signatures = self.event_signatures.extend(event_signature.into());
        self
    }

    /// Sets the event signature hashes to filter specific events.
    /// If neither event signature hashes nor events are set, all events from the specified
    /// contract(s) will be tracked.
    #[must_use]
    pub fn event_signatures(
        mut self,
        event_signatures: impl IntoIterator<Item = impl Into<Topic>>,
    ) -> Self {
        for event_signature in event_signatures {
            self.event_signatures = self.event_signatures.extend(event_signature);
        }
        self
    }

    /// Returns a [`Topic`] containing all event signature hashes.
    /// If neither events nor event signature hashes are set, an empty [`Topic`] is returned.
    #[must_use]
    fn all_events(&self) -> Topic {
        let events = self.events.iter().map(|e| keccak256(e.as_bytes())).collect::<Vec<_>>();
        let sigs = self.event_signatures.clone();
        sigs.extend(events)
    }
}

impl From<EventFilter> for Filter {
    fn from(value: EventFilter) -> Self {
        let mut filter = Filter::new();
        let events = value.all_events();
        if !events.is_empty() {
            filter = filter.event_signature(events);
        }
        if !value.contract_addresses.is_empty() {
            filter = filter.address(value.contract_addresses);
        }
        filter
    }
}

impl From<&EventFilter> for Filter {
    fn from(value: &EventFilter) -> Self {
        let mut filter = Filter::new();
        let events = value.all_events();
        if !events.is_empty() {
            filter = filter.event_signature(events);
        }
        if !value.contract_addresses.is_empty() {
            filter = filter.address(value.contract_addresses.clone());
        }
        filter
    }
}
