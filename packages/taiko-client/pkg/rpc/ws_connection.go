package rpc

import (
	"context"
	"net"
	"sync"
	"time"
)

// wsConnectionTracker keeps track of the TCP connection used by a WebSocket
// RPC client so an unresponsive connection can be closed without replacing the
// rpc.Client. Callers can keep using the same client while go-ethereum reconnects.
type wsConnectionTracker struct {
	mu          sync.Mutex
	conn        net.Conn
	connectedAt time.Time
}

func (t *wsConnectionTracker) dialContext(
	ctx context.Context,
	network string,
	address string,
) (net.Conn, error) {
	conn, err := new(net.Dialer).DialContext(ctx, network, address)
	if err != nil {
		return nil, err
	}

	t.mu.Lock()
	t.conn = conn
	t.connectedAt = time.Now()
	t.mu.Unlock()

	return conn, nil
}

// closeIfOpenBefore closes the currently tracked connection only when it was
// already open when the failed RPC call started. This prevents concurrent
// timed-out calls from closing a newer connection established in the meantime.
func (t *wsConnectionTracker) closeIfOpenBefore(callStartedAt time.Time) bool {
	t.mu.Lock()
	defer t.mu.Unlock()

	if t.conn == nil || t.connectedAt.After(callStartedAt) {
		return false
	}

	conn := t.conn
	t.conn = nil
	return conn.Close() == nil
}
