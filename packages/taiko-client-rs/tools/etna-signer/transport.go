package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/cometbft/cometbft/crypto"
	"github.com/cometbft/cometbft/crypto/ed25519"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	"github.com/cometbft/cometbft/privval"
	libp2pcrypto "github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/peer"
	libp2pnoise "github.com/libp2p/go-libp2p/p2p/security/noise"
)

// noiseHandshakeTimeout bounds the TCP connect and the Noise handshake of one dial. It is
// stock CometBFT v0.40.0's privval read/write timeout, which also bounds Comet's own side of
// the handshake.
const noiseHandshakeTimeout = 5 * time.Second

// cometDialer is the signer's side of the only two transports START-10-6 allows:
//   - unix://<path>: the socket the supervisor names in its private Comet run/ directory;
//   - noise://<comet-peer-id>@<ip>:<port>: stock v0.40.0 Noise. Comet's listener is
//     noise://<signer-peer-id>@<ip>:<port>, which pins this signer's transport key, and the
//     signer pins <comet-peer-id>, the libp2p ID of Comet's persistent node key.
//
// Bare tcp://, whose stock listener generates a fresh identity at every start, and every other
// scheme are refused, and so is a transport key without Noise or Noise without one.
func cometDialer(address, transportKey string) (privval.SocketDialer, error) {
	switch {
	case strings.HasPrefix(address, "unix://"):
		if transportKey != "" {
			return nil, errors.New("--transport-key is only for a noise:// signer transport")
		}
		path := strings.TrimPrefix(address, "unix://")
		if path == "" {
			return nil, errors.New("unix:// signer transport names no socket")
		}
		return privval.DialUnixFn(path), nil
	case strings.HasPrefix(address, "noise://"):
		if transportKey == "" {
			return nil, errors.New("a noise:// signer transport needs --transport-key")
		}
		key, err := loadTransportKey(transportKey)
		if err != nil {
			return nil, err
		}
		return noiseDialer(address, key)
	default:
		return nil, errors.New("unsupported Comet signer transport: use unix:// or noise://<comet-peer-id>@<ip>:<port>; bare tcp:// is refused (START-10-6)")
	}
}

// noiseDialer dials address, noise://<comet-peer-id>@<ip>:<port> as stock ParseNoiseAddr reads
// it, and completes the Noise handshake as initiator with key. The handshake fails unless the
// listener proves the pinned Comet peer ID.
func noiseDialer(address string, key ed25519.PrivKey) (privval.SocketDialer, error) {
	comet, hostport, err := privval.ParseNoiseAddr(address)
	if err != nil {
		return nil, err
	}
	identity, err := libp2pcrypto.UnmarshalEd25519PrivateKey(key.Bytes())
	if err != nil {
		return nil, fmt.Errorf("noise transport identity: %w", err)
	}
	transport, err := libp2pnoise.New(libp2pnoise.ID, identity, nil)
	if err != nil {
		return nil, fmt.Errorf("noise transport: %w", err)
	}
	return func() (net.Conn, error) {
		raw, err := net.DialTimeout("tcp", hostport, noiseHandshakeTimeout)
		if err != nil {
			return nil, err
		}
		ctx, cancel := context.WithTimeout(context.Background(), noiseHandshakeTimeout)
		defer cancel()
		secured, err := transport.SecureOutbound(ctx, raw, comet)
		if err != nil {
			raw.Close()
			return nil, fmt.Errorf("noise handshake with Comet %s: %w", comet, err)
		}
		return secured, nil
	}, nil
}

// transportKeyFile is the stock CometBFT node-key JSON layout, which the signer's transport
// key reuses: {"priv_key": {"type": "tendermint/PrivKeyEd25519", "value": "<base64>"}}.
type transportKeyFile struct {
	PrivKey crypto.PrivKey `json:"priv_key"`
}

// loadTransportKey reads the signer's persistent Ed25519 Noise key. It is a transport
// identity only, never the consensus key.
func loadTransportKey(path string) (ed25519.PrivKey, error) {
	f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return nil, fmt.Errorf("signer transport key: %w", err)
	}
	defer f.Close()
	raw, err := io.ReadAll(io.LimitReader(f, 4096))
	if err != nil {
		return nil, fmt.Errorf("signer transport key: %w", err)
	}
	var fields map[string]json.RawMessage
	if err = json.Unmarshal(raw, &fields); err != nil || len(fields) != 1 || fields["priv_key"] == nil {
		return nil, errors.New("signer transport key must hold exactly one Ed25519 priv_key")
	}
	var file transportKeyFile
	if err = cmtjson.Unmarshal(raw, &file); err != nil {
		return nil, fmt.Errorf("signer transport key must hold exactly one Ed25519 priv_key: %w", err)
	}
	key, ok := file.PrivKey.(ed25519.PrivKey)
	if !ok || len(key) != ed25519.PrivateKeySize {
		return nil, errors.New("signer transport key must hold exactly one Ed25519 priv_key")
	}
	return key, nil
}

// transportPeerID is key's libp2p peer ID, the ID Comet's noise:// listener pins.
func transportPeerID(key ed25519.PrivKey) (peer.ID, error) {
	identity, err := libp2pcrypto.UnmarshalEd25519PrivateKey(key.Bytes())
	if err != nil {
		return "", err
	}
	return peer.IDFromPrivateKey(identity)
}

// transportKeygen is `etna-signer transport-keygen --transport-key P`: it exclusively writes a
// fresh mode-0600 Ed25519 transport key in the stock node-key layout and prints its peer ID,
// for Comet's noise://<signer-peer-id>@<ip>:<port> listener. An existing path is refused.
func transportKeygen(args []string, out io.Writer) error {
	flags := flag.NewFlagSet("transport-keygen", flag.ContinueOnError)
	path := flags.String("transport-key", "", "new signer transport key path (must not exist)")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *path == "" || flags.NArg() != 0 {
		return errors.New("transport-keygen requires --transport-key only")
	}
	key := ed25519.GenPrivKey()
	id, err := transportPeerID(key)
	if err != nil {
		return err
	}
	raw, err := cmtjson.Marshal(transportKeyFile{PrivKey: key})
	if err != nil {
		return err
	}
	f, err := os.OpenFile(*path, os.O_WRONLY|os.O_CREATE|os.O_EXCL|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		return err
	}
	if _, err = f.Write(raw); err == nil {
		err = f.Sync()
	}
	if err = errors.Join(err, f.Close()); err != nil {
		os.Remove(*path)
		return err
	}
	return json.NewEncoder(out).Encode(map[string]string{"peerId": id.String()})
}

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
	g.conn.Store(nil)
	connections := make([]*trackedConn, 0, len(g.transports))
	for conn := range g.transports {
		connections = append(connections, conn)
	}
	g.transportMu.Unlock()
	for _, conn := range connections {
		conn.Close()
	}
}

// reconnectingConn retains the official Unix or Noise transport and
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
