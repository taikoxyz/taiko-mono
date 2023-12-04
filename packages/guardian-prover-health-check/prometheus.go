package guardianproverhealthcheck

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	EventsProcessed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "events_processed_ops_total",
		Help: "The total number of processed events",
	})
)
