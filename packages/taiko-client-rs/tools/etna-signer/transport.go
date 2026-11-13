package main

import (
	"errors"
	"net"
	"sync"
)

// trackedConn lets shutdown interrupt stock ReadMessage without acquiring the
// endpoint connection mutex that ReadMessage holds during its blocking read.
type trackedConn struct {
	net.Conn
	gate *gate
	once sync.Once
}

func (c *trackedConn) Close() error {
	var err error
	c.once.Do(func() {
		err = c.Conn.Close()
		c.gate.transportMu.Lock()
		delete(c.gate.transports, c)
		c.gate.transportMu.Unlock()
	})
	return err
}

func (g *gate) isStopping() bool {
	g.transportMu.Lock()
	defer g.transportMu.Unlock()
	return g.stopping
}

// trackTransport also closes a dial that completed concurrently with shutdown.
func (g *gate) trackTransport(conn net.Conn) (net.Conn, error) {
	g.transportMu.Lock()
	if g.stopping {
		g.transportMu.Unlock()
		conn.Close()
		return nil, errors.New("signer stopped")
	}
	defer g.transportMu.Unlock()
	if g.transports == nil {
		g.transports = make(map[*trackedConn]struct{})
	}
	tracked := &trackedConn{Conn: conn, gate: g}
	g.transports[tracked] = struct{}{}
	return tracked, nil
}

// closeTransports permanently closes this gate before stopping the stock server;
// no reconnect or delayed begin_session can publish a replacement live session.
func (g *gate) closeTransports() {
	g.transportMu.Lock()
	g.stopping = true
	g.session.Store(nil)
	connections := make([]*trackedConn, 0, len(g.transports))
	for conn := range g.transports {
		connections = append(connections, conn)
	}
	g.transportMu.Unlock()
	for _, conn := range connections {
		conn.Close()
	}
}

// reconnectingConn retains the official Unix/SecretConnection transport and
// normalizes terminal I/O errors for the pinned v0.40.0 signer endpoint. That
// endpoint drops only errors implementing Timeout(), without checking its value;
// plain io.EOF otherwise leaves a dead connection installed forever. net.OpError
// preserves the cause and truthful timeout classification while using the stock
// endpoint's own drop/reconnect path without reentering its connection mutex.
type reconnectingConn struct{ net.Conn }

func (c *reconnectingConn) Read(p []byte) (int, error) {
	n, err := c.Conn.Read(p)
	return n, transportError("read", err)
}
func (c *reconnectingConn) Write(p []byte) (int, error) {
	n, err := c.Conn.Write(p)
	return n, transportError("write", err)
}
func transportError(op string, err error) error {
	if err == nil {
		return nil
	}
	if _, ok := err.(net.Error); ok {
		return err
	}
	return &net.OpError{Op: op, Net: "comet-privval", Err: reconnectCause{err}}
}

// Preserve a wrapped network error's real timeout/temporary classification as well
// as its entire causal chain when net.OpError delegates to its direct cause.
type reconnectCause struct{ error }

func (e reconnectCause) Unwrap() error { return e.error }
func (e reconnectCause) Timeout() bool {
	var network net.Error
	return errors.As(e.error, &network) && network.Timeout()
}
func (e reconnectCause) Temporary() bool {
	var network net.Error
	return errors.As(e.error, &network) && network.Temporary()
}
