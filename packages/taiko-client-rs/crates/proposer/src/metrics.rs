//! Prometheus metrics for tracking proposer.

#[derive(Debug, Clone)]
pub struct ProposerMetrics;

impl ProposerMetrics {
    /// Gauge tracking the size of the transaction pool fetched from L2.
    pub const TX_POOL_SIZE: &'static str = "taiko_proposer_tx_pool_size";

    /// Counter for the total number of proposals sent to L1.
    pub const PROPOSALS_SENT: &'static str = "taiko_proposer_proposals_sent";

    /// Counter for the number of successfully mined proposals.
    pub const PROPOSALS_SUCCESS: &'static str = "taiko_proposer_proposals_success";

    /// Counter for the number of failed proposals.
    pub const PROPOSALS_FAILED: &'static str = "taiko_proposer_proposals_failed";

    /// Histogram tracking the gas used by successful proposals.
    pub const GAS_USED: &'static str = "taiko_proposer_gas_used";

    /// Describes metrics used in the proposer.
    pub fn describe() {
        metrics::describe_gauge!(
            Self::TX_POOL_SIZE,
            "Size of the transaction pool fetched from L2 execution engine"
        );

        metrics::describe_counter!(Self::PROPOSALS_SENT, "Total number of proposals sent to L1");

        metrics::describe_counter!(
            Self::PROPOSALS_SUCCESS,
            "Number of successfully mined proposals"
        );

        metrics::describe_counter!(Self::PROPOSALS_FAILED, "Number of failed proposals");

        metrics::describe_histogram!(
            Self::GAS_USED,
            metrics::Unit::Count,
            "Gas used by successful proposals"
        );
    }

    /// Initializes metrics to 0 so they can be queried immediately.
    pub fn init() {
        Self::describe();
        Self::zero();
    }

    /// Initializes all counters to 0.
    fn zero() {
        metrics::counter!(Self::PROPOSALS_SENT).absolute(0);
        metrics::counter!(Self::PROPOSALS_SUCCESS).absolute(0);
        metrics::counter!(Self::PROPOSALS_FAILED).absolute(0);
    }
}
