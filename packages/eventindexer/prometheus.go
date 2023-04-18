package eventindexer

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
	BlocksScannedError = promauto.NewCounter(prometheus.CounterOpts{
		Name: "blocks_scanned_error_ops_total",
		Help: "The total number of scanned block errors.",
	})
	ErrorsEncounteredDuringSubscription = promauto.NewCounter(prometheus.CounterOpts{
		Name: "errors_encountered_during_subscription_opts_total",
		Help: "The total number of errors that occurred during active subscription",
	})
)
