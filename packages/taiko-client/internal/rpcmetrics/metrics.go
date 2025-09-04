package rpcmetrics

import (
	"context"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	// RPC request counters by method and client type
	RPCRequestsTotal = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "rpc_requests_total",
		Help: "Total number of RPC requests made",
	}, []string{"client_type", "method", "status"})

	// RPC request duration histograms
	RPCRequestDuration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "rpc_request_duration_seconds",
		Help:    "Duration of RPC requests in seconds",
		Buckets: []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
	}, []string{"client_type", "method"})

	// Active RPC requests gauge
	RPCActiveRequests = prometheus.NewGaugeVec(prometheus.GaugeOpts{
		Name: "rpc_active_requests",
		Help: "Number of active RPC requests",
	}, []string{"client_type", "method"})

	// RPC timeout counter
	RPCTimeouts = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "rpc_timeouts_total",
		Help: "Total number of RPC requests that timed out",
	}, []string{"client_type", "method"})
)

func init() {
	// Register all metrics with the default prometheus registry
	prometheus.MustRegister(RPCRequestsTotal)
	prometheus.MustRegister(RPCRequestDuration)
	prometheus.MustRegister(RPCActiveRequests)
	prometheus.MustRegister(RPCTimeouts)
}

// RPCMetrics provides instrumentation for RPC calls
type RPCMetrics struct {
	clientType string
}

// NewRPCMetrics creates a new RPCMetrics instance for the specified client type
func NewRPCMetrics(clientType string) *RPCMetrics {
	return &RPCMetrics{
		clientType: clientType,
	}
}

// TrackRequest instruments an RPC call with metrics
func (m *RPCMetrics) TrackRequest(ctx context.Context, method string, fn func() error) error {
	start := time.Now()

	RPCActiveRequests.WithLabelValues(m.clientType, method).Inc()
	defer RPCActiveRequests.WithLabelValues(m.clientType, method).Dec()

	err := fn()
	duration := time.Since(start)

	status := "success"
	if err != nil {
		status = "error"
		if ctx.Err() == context.DeadlineExceeded {
			RPCTimeouts.WithLabelValues(m.clientType, method).Inc()
			status = "timeout"
		}
	}

	RPCRequestsTotal.WithLabelValues(m.clientType, method, status).Inc()
	RPCRequestDuration.WithLabelValues(m.clientType, method).Observe(duration.Seconds())

	return err
}

// GetClientType returns the client type for this metrics instance
func (m *RPCMetrics) GetClientType() string {
	return m.clientType
}
