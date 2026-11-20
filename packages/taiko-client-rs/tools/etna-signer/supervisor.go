package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/cometbft/cometbft/types"
)

// supervisorSchema is the supervisor channel's one wire version.
const supervisorSchema = 1

// maxSupervisorFrame bounds one supervisor reply line.
const maxSupervisorFrame = 16 * 1024

// errSupervisorUnavailable marks a supervisor query that got no valid reply: no connection, a
// failed peer-credential check, a timeout or a malformed frame. The request stays pending until
// its deadline.
var errSupervisorUnavailable = errors.New("supervisor channel unavailable")

// cometReporter tells the signer which Comet process its supervisor started, and on which
// store instance (RECOV-8.2-2).
type cometReporter interface {
	comet(deadline time.Time) (*cometProcess, error)
}

// supervisorChannel is the signer's side of the authenticated supervisor channel: a Unix socket
// in the supervisor's private run directory, served by the supervisor that started this signer.
// Every connection checks the peer's credentials: its PID must be the parent PID this signer
// had when it started, and its UID root or the signer's own, so neither another process nor a
// later supervisor after this one died can answer. Requests are newline-delimited JSON objects
// {"schema": 1, "id": n, "op": ...}; each reply carries the same schema and id.
type supervisorChannel struct {
	path string
	// peer is the only PID allowed to serve the channel.
	peer   int
	mu     sync.Mutex
	conn   net.Conn
	reader *bufio.Reader
	next   uint64
}

func newSupervisorChannel(path string, peer int) *supervisorChannel {
	return &supervisorChannel{path: path, peer: peer}
}

// connect dials the socket and authenticates the listening peer.
func (s *supervisorChannel) connect(deadline time.Time) error {
	wait := time.Until(deadline)
	if wait <= 0 {
		return errors.New("deadline passed")
	}
	conn, err := net.DialTimeout("unix", s.path, wait)
	if err != nil {
		return err
	}
	pid, uid, err := peerCredentials(conn)
	if err == nil && pid != s.peer {
		err = fmt.Errorf("peer PID %d is not the supervisor %d", pid, s.peer)
	}
	if err == nil && uid != 0 && uid != os.Geteuid() {
		err = fmt.Errorf("peer UID %d is neither root nor the signer's", uid)
	}
	if err != nil {
		conn.Close()
		return fmt.Errorf("supervisor peer credentials: %w", err)
	}
	s.conn, s.reader = conn, bufio.NewReaderSize(conn, maxSupervisorFrame)
	return nil
}

// query sends one request and returns the reply's fields. Any failure drops the connection, so
// the next query reconnects and authenticates again.
func (s *supervisorChannel) query(op string, fields map[string]any, deadline time.Time) (map[string]json.RawMessage, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	reply, err := s.exchange(op, fields, deadline)
	if err != nil {
		if s.conn != nil {
			s.conn.Close()
			s.conn, s.reader = nil, nil
		}
		return nil, fmt.Errorf("%w: %w", errSupervisorUnavailable, err)
	}
	return reply, nil
}

func (s *supervisorChannel) exchange(op string, fields map[string]any, deadline time.Time) (map[string]json.RawMessage, error) {
	if s.conn == nil {
		if err := s.connect(deadline); err != nil {
			return nil, err
		}
	}
	if err := s.conn.SetDeadline(deadline); err != nil {
		return nil, err
	}
	s.next++
	request := map[string]any{"schema": supervisorSchema, "id": s.next, "op": op}
	for key, value := range fields {
		request[key] = value
	}
	line, err := json.Marshal(request)
	if err != nil {
		return nil, err
	}
	if _, err = s.conn.Write(append(line, '\n')); err != nil {
		return nil, err
	}
	raw, err := s.reader.ReadSlice('\n')
	if errors.Is(err, bufio.ErrBufferFull) || len(raw) > maxSupervisorFrame {
		return nil, errors.New("oversize supervisor reply")
	}
	if err != nil {
		return nil, err
	}
	if err = uniqueJSON(json.NewDecoder(bytes.NewReader(raw))); err != nil {
		return nil, err
	}
	var reply map[string]json.RawMessage
	if err = json.Unmarshal(raw, &reply); err != nil {
		return nil, err
	}
	var schema, id uint64
	if err = json.Unmarshal(reply["schema"], &schema); err != nil || schema != supervisorSchema {
		return nil, errors.New("supervisor reply has another schema")
	}
	if err = json.Unmarshal(reply["id"], &id); err != nil || id != s.next {
		return nil, errors.New("supervisor reply answers another request")
	}
	if raw, ok := reply["error"]; ok {
		return nil, fmt.Errorf("supervisor refused %s: %s", op, raw)
	}
	return reply, nil
}

// comet asks which Comet process the supervisor runs for this signer: {"comet": null} before
// it started one or once it was stopped, else {"comet": {"pid": n, "start": "<ticks>" or null,
// "store_instance": "<32 hex>"}}.
func (s *supervisorChannel) comet(deadline time.Time) (*cometProcess, error) {
	reply, err := s.query("comet", nil, deadline)
	if err != nil {
		return nil, err
	}
	raw, ok := reply["comet"]
	if !ok {
		return nil, errors.New("supervisor reply has no comet field")
	}
	if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return nil, nil
	}
	var report struct {
		PID           *int    `json:"pid"`
		Start         *string `json:"start"`
		StoreInstance *string `json:"store_instance"`
	}
	if err = json.Unmarshal(raw, &report); err != nil {
		return nil, err
	}
	if report.PID == nil || *report.PID <= 0 || report.StoreInstance == nil || !validStoreInstance(*report.StoreInstance) {
		return nil, errors.New("invalid Comet report")
	}
	proc := &cometProcess{PID: *report.PID, StoreInstance: *report.StoreInstance}
	if report.Start != nil {
		if _, err = strconv.ParseUint(*report.Start, 10, 64); err != nil {
			return nil, errors.New("invalid Comet start time")
		}
		proc.Start = *report.Start
	}
	return proc, nil
}

// cometConn is one signer-to-Comet transport connection and the Comet process its session was
// admitted for. A Unix transport carries the listener's PID (SO_PEERCRED); Noise authenticates
// Comet's node key instead, which only the supervisor's home holds.
type cometConn struct {
	unix     bool
	pid      int
	admitted atomic.Pointer[cometProcess]
}

// newCometConn records the peer of a freshly dialed transport.
func newCometConn(conn net.Conn) *cometConn {
	c := &cometConn{}
	if _, ok := conn.(*net.UnixConn); ok {
		c.unix = true
		if pid, _, err := peerCredentials(conn); err == nil {
			c.pid = pid
		}
	}
	return c
}

// verify checks that the supervisor's report names this transport's Comet: on a Unix transport
// the listener's PID and, where the kernel records it, its start time, so a reused PID cannot
// pass.
func (c *cometConn) verify(proc cometProcess) error {
	if !c.unix {
		return nil
	}
	if c.pid <= 0 {
		return errors.New("the Comet transport's peer credentials are unknown")
	}
	if c.pid != proc.PID {
		return fmt.Errorf("the Comet transport's peer PID %d is not the supervisor's Comet %d", c.pid, proc.PID)
	}
	start, err := processStart(c.pid)
	if err != nil {
		return fmt.Errorf("start time of Comet %d: %w", c.pid, err)
	}
	if start != proc.Start {
		return fmt.Errorf("Comet %d started at %q, not at the reported %q", c.pid, start, proc.Start)
	}
	return nil
}

// continuitySigner is a PrivValidator that enforces RECOV-8.2-2 itself: the gate admits each
// session through it before any signature.
type continuitySigner interface {
	types.PrivValidator
	admit(cometProcess) error
}

// admitSession verifies, for one signing request, that this transport's Comet is the process the
// supervisor reports, and binds or fences the signer state for the transport's session before
// its first signature (RECOV-8.2-2, SYNC-9-4). An unavailable channel or a missing report is
// pending; a mismatch is final.
func (g *gate) admitSession(signer types.PrivValidator, deadline time.Time) error {
	pv, ok := signer.(continuitySigner)
	if !ok {
		return errors.New("signer has no continuity state")
	}
	conn := g.conn.Load()
	if conn == nil {
		return errors.New("no Comet transport")
	}
	if g.supervisor == nil {
		return errors.New("no supervisor channel")
	}
	proc, err := g.supervisor.comet(deadline)
	if errors.Is(err, errSupervisorUnavailable) {
		return fmt.Errorf("%w: %w", errTrustPending, err)
	}
	if err != nil {
		return err
	}
	if proc == nil {
		return fmt.Errorf("%w: the supervisor runs no Comet for this signer", errTrustPending)
	}
	if err = conn.verify(*proc); err != nil {
		return err
	}
	if admitted := conn.admitted.Load(); admitted != nil {
		if *admitted != *proc {
			return errors.New("the supervisor's Comet report changed during this transport connection")
		}
		return nil
	}
	if err = pv.admit(*proc); err != nil {
		return err
	}
	conn.admitted.Store(proc)
	return nil
}
