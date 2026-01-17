package eventindexer

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	BlockProposedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_proposed_events_processed_ops_total",
		Help: "The total number of processed BlockProposed events",
	})
	BatchesProvedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "batches_proven_events_processed_ops_total",
		Help: "The total number of processed BatchesProven events",
	})
	BatchesVerifiedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "batches_verified_events_processed_ops_total",
		Help: "The total number of processed BatchesVerified events",
	})
	BatchProposedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "batch_proposed_events_processed_ops_total",
		Help: "The total number of processed BatchProposed events",
	})
	BlockAssignedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_assigned_events_processed_ops_total",
		Help: "The total number of processed BlockAssigned events",
	})
	BlockProposedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_proposed_events_processed_error_ops_total",
		Help: "The total number of processed BlockProposed event errors encountered",
	})
	BatchProposedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "batch_proposed_events_processed_error_ops_total",
		Help: "The total number of processed BatchProposed event errors encountered",
	})
	ProposedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "proposed_events_processed_error_ops_total",
		Help: "The total number of processed Proposed event errors encountered",
	})
	ProvedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "proved_events_processed_error_ops_total",
		Help: "The total number of processed Proved event errors encountered",
	})
	BatchesProvenEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "batches_proven_events_processed_error_ops_total",
		Help: "The total number of processed BatchesProven events errors",
	})
	BatchesVerifiedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "batches_verified_events_processed_error_ops_total",
		Help: "The total number of processed BatchesVerified events errors",
	})
	BlockAssignedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_assigned_events_processed_error_ops_total",
		Help: "The total number of processed BlockAssigned event errors encountered",
	})
	TransitionProvedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_proven_events_processed_ops_total",
		Help: "The total number of processed BlockProven events",
	})
	TransitionProvedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_proven_events_processed_error_ops_total",
		Help: "The total number of processed BlockProven event errors encountered",
	})
	TransitionContestedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_contested_events_processed_ops_total",
		Help: "The total number of processed BlockContested events",
	})
	TransitionContestedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_contested_events_processed_error_ops_total",
		Help: "The total number of processed BlockContested event errors encountered",
	})
	BlockVerifiedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_verified_events_processed_ops_total",
		Help: "The total number of processed BlockVerified events",
	})
	BlockVerifiedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_verified_events_processed_error_ops_total",
		Help: "The total number of processed BlockVerified event errors encountered",
	})
	SlashedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "slashed_events_processed_ops_total",
		Help: "The total number of processed Slashed events",
	})
	SlashedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "slashed_events_processed_error_ops_total",
		Help: "The total number of processed Slashed event errors encountered",
	})
	StakedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "staked_events_processed_ops_total",
		Help: "The total number of processed Staked events",
	})
	StakedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "staked_events_processed_error_ops_total",
		Help: "The total number of processed Staked event errors encountered",
	})
	ExitedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "exited_events_processed_ops_total",
		Help: "The total number of processed Exited events",
	})
	ExitedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "exited_events_processed_error_ops_total",
		Help: "The total number of processed Exited event errors encountered",
	})
	WithdrawnEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "withdrawn_events_processed_ops_total",
		Help: "The total number of processed Exited events",
	})
	WithdrawnEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "withdrawn_events_processed_error_ops_total",
		Help: "The total number of processed Exited event errors encountered",
	})
	MessageSentEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "message_sent_events_processed_ops_total",
		Help: "The total number of processed MessageSent events",
	})
	MessageSentEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "message_sent_events_processed_error_ops_total",
		Help: "The total number of processed MessageSent event errors encountered",
	})
	SwapEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "swap_events_processed_ops_total",
		Help: "The total number of processed Swap events",
	})
	SwapEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "swap_events_processed_error_ops_total",
		Help: "The total number of processed Swap event errors encountered",
	})
	LiquidityAddedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "liquidity_added_events_processed_ops_total",
		Help: "The total number of processed LiquidityAdded events",
	})
	LiquidityAddedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "liquidity_added_events_processed_error_ops_total",
		Help: "The total number of processed LiquidityAdded event errors encountered",
	})
	BlocksProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "blocks_processed_ops_total",
		Help: "The total number of processed blocks",
	})
	ErrorsEncounteredDuringSubscription = promauto.NewCounter(prometheus.CounterOpts{
		Name: "errors_encountered_during_subscription_opts_total",
		Help: "The total number of errors that occurred during active subscription",
	})
)
