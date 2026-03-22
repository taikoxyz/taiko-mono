//! Proposer-specific CLI flags.

use alloy_primitives::{Address, B256};
use clap::Parser;

#[derive(Parser, Clone, Debug, PartialEq, Eq)]
/// CLI flags specific to proposer operation.
pub struct ProposerArgs {
    /// Private key of the L1 proposer, who will send transactions to propose L2 batches to inbox.
    #[clap(
        long = "l1.proposerPrivKey",
        env = "L1_PROPOSER_PRIV_KEY",
        required = true,
        help = "Private key of the L1 proposer, who will send transactions to propose L2 batches to inbox"
    )]
    pub l1_proposer_private_key: B256,
    /// Address of the proposed block's suggested L2 fee recipient.
    #[clap(
        long = "l2.suggestedFeeRecipient",
        env = "L2_SUGGESTED_FEE_RECIPIENT",
        required = true,
        help = "Address of the proposed block's suggested L2 fee recipient"
    )]
    pub l2_suggested_fee_recipient: Address,
    /// Interval (in seconds) between proposing L2 blocks.
    #[clap(
        long = "propose.interval",
        env = "PROPOSE_INTERVAL",
        default_value = "12",
        help = "Interval (in seconds) between proposing L2 blocks"
    )]
    pub propose_interval: u64,
    /// Optional gas limit for proposal transactions. If not set, uses provider's estimation.
    #[clap(
        long = "propose.gasLimit",
        env = "PROPOSE_GAS_LIMIT",
        help = "Optional gas limit for proposal transactions. If not set, uses provider's estimation"
    )]
    pub gas_limit: Option<u64>,
    /// Whether to use Engine API mode for payload building (FCU + get_payload).
    #[clap(
        long = "propose.useEngineMode",
        env = "PROPOSE_USE_ENGINE_MODE",
        default_value = "false",
        help = "Use Engine API mode for payload building (FCU + get_payload)"
    )]
    pub use_engine_mode: bool,
    /// Timeout in seconds for waiting for a proposal transaction receipt before retrying.
    #[clap(
        long = "propose.receiptTimeout",
        env = "PROPOSE_RECEIPT_TIMEOUT",
        default_value = "180",
        help = "Timeout in seconds for waiting for a proposal tx receipt before retrying with bumped tip"
    )]
    pub receipt_timeout: u64,
    /// Maximum number of tip bump retries before giving up on a proposal transaction.
    #[clap(
        long = "propose.maxTipBumpRetries",
        env = "PROPOSE_MAX_TIP_BUMP_RETRIES",
        default_value = "3",
        help = "Maximum number of tip bump retries before giving up"
    )]
    pub max_tip_bump_retries: u32,
    /// Percentage to increase the priority fee by on each retry (e.g. 20 means +20%).
    #[clap(
        long = "propose.tipBumpPercentage",
        env = "PROPOSE_TIP_BUMP_PERCENTAGE",
        default_value = "20",
        help = "Percentage to increase priority fee on each retry"
    )]
    pub tip_bump_percentage: u64,
}
