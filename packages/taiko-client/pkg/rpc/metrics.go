package rpc

import "github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/rpcmetrics"

// RPCMetrics is an alias for the rpcmetrics.RPCMetrics to avoid import cycles
type RPCMetrics = rpcmetrics.RPCMetrics

// NewRPCMetrics creates a new RPCMetrics instance for the specified client type
func NewRPCMetrics(clientType string) *RPCMetrics {
	return rpcmetrics.NewRPCMetrics(clientType)
}
