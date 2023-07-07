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
	BlockProposedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_proposed_events_processed_error_ops_total",
		Help: "The total number of processed BlockProposed event errors encountered",
	})
	BlockProvenEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_proven_events_processed_ops_total",
		Help: "The total number of processed BlockProven events",
	})
	BlockProvenEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_proven_events_processed_error_ops_total",
		Help: "The total number of processed BlockProven event errors encountered",
	})
	BlockVerifiedEventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_verified_events_processed_ops_total",
		Help: "The total number of processed BlockVerified events",
	})
	BlockVerifiedEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "block_verified_events_processed_error_ops_total",
		Help: "The total number of processed BlockVerified event errors encountered",
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
		Help: "The total number of processed MessageSent events",
	})
	SwapEventsProcessedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "swap_events_processed_error_ops_total",
		Help: "The total number of processed Swap event errors encountered",
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
