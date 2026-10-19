package main

import (
	"errors"
	"net"
)

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
