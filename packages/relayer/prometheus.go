package relayer

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	EventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "events_processed_ops_total",
		Help: "The total number of processed events",
	})
	BlocksProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "blocks_processed_ops_total",
		Help: "The total number of processed blocks",
	})
	RetriableEvents = promauto.NewCounter(prometheus.CounterOpts{
		Name: "events_processed_retriable_status_ops_total",
		Help: "The total number of processed events that ended up in Retriable status",
	})
	DoneEvents = promauto.NewCounter(prometheus.CounterOpts{
		Name: "events_processed_done_status_ops_total",
		Help: "The total number of processed events that ended up in Done status",
	})
	ErrorEvents = promauto.NewCounter(prometheus.CounterOpts{
		Name: "events_processed_error_ops_total",
		Help: "The total number of processed events that failed due to an error",
	})
	MessagesNotReceivedOnDestChain = promauto.NewCounter(prometheus.CounterOpts{
		Name: "messages_not_received_on_dest_chain_opts_total",
		Help: "The total number of messages that were not received on the destination chain",
	})
	ErrorsEncounteredDuringSubscription = promauto.NewCounter(prometheus.CounterOpts{
		Name: "errors_encountered_during_subscription_opts_total",
		Help: "The total number of errors that occured during active subscription",
	})
)
