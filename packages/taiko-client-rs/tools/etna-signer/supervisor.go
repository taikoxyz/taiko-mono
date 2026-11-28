package main

import (
	"bufio"
	"bytes"
	"encoding/hex"
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

// supervisorClient is the signer's view of its supervisor (RECOV-8.2-2): which Comet process it
// started, on which store instance and with which startup replay check; what its log observer has
// seen of that process's replay; and the live WAL binding of a signing request.
type supervisorClient interface {
	comet(deadline time.Time) (*cometReport, error)
	observe(deadline time.Time) (*replayObservation, error)
	wal(height int64, deadline time.Time) (*replayBinding, error)
	// stopArmed reports whether the operator armed the stop on a precommit for a planned
	// ruleset upgrade (START-10.1-14b); stopped tells the supervisor that the signer's gate
	// closed after the precommit at height and round, its last signature.
	stopArmed(deadline time.Time) (bool, error)
	stopped(height int64, round int32, deadline time.Time) error
}

// cometReport is the supervisor's answer to the comet op: the Comet process and, when this
// start can replay the last signed height, the startup check of the saved replay binding.
type cometReport struct {
	Process cometProcess
	Replay  *replayReport
}

// replayReport is the supervisor's startup preflight of the signer's saved replay binding, made
// with Comet stopped: the stores hold exactly the bound predecessor of Height, the WAL holds its
// end-height marker and no marker for Height, and the bytes after the marker begin with the bound
// prefix. Startup is the pinned startup prefix, every complete record after the marker. Repair is
// a torn tail after all bound input: stock repairs it in this start, which therefore cannot
// replay, and the supervisor starts the pair again.
type replayReport struct {
	Height  int64
	Binding replayBinding
	Startup replayBinding
	Repair  bool
}

// replayObservation is the supervisor's log observer's view of the bound Comet process, after it
// consumed every record the process had written: the current replay attempt (numbered from 1 in
// that process), whether it is open and for which height, and whether a corruption, repair or
// replay error has tainted the process (Repaired: by a stock WAL repair).
type replayObservation struct {
	Attempt  uint64
	Open     bool
	Height   int64
	Tainted  bool
	Repaired bool
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

// wireBinding is a replay binding on the supervisor channel.
type wireBinding struct {
	Marker      *int64  `json:"marker"`
	Predecessor *string `json:"predecessor"`
	Length      *int64  `json:"wal_length"`
	Digest      *string `json:"wal_sha256"`
}

func (w wireBinding) binding() (replayBinding, error) {
	if w.Marker == nil || *w.Marker < 0 || w.Length == nil || *w.Length < 0 || w.Digest == nil || w.Predecessor == nil {
		return replayBinding{}, errors.New("incomplete replay binding")
	}
	digest, err := hex.DecodeString(*w.Digest)
	if err != nil || len(digest) != 32 {
		return replayBinding{}, errors.New("invalid replay binding digest")
	}
	predecessor, err := hex.DecodeString(*w.Predecessor)
	if err != nil || (len(predecessor) != 0 && len(predecessor) != 32) || (*w.Marker == 0) != (len(predecessor) == 0) {
		return replayBinding{}, errors.New("invalid replay binding predecessor")
	}
	return replayBinding{Marker: *w.Marker, Predecessor: predecessor, Length: *w.Length, Digest: digest}, nil
}

// comet asks which Comet process the supervisor runs for this signer: {"comet": null} before
// it started one or once it was stopped, else {"comet": {"pid": n, "start": "<ticks>" or null,
// "store_instance": "<32 hex>", "replay": null or {"height": H, "binding": {...}, "startup":
// {...}, "repair": bool}}}.
func (s *supervisorChannel) comet(deadline time.Time) (*cometReport, error) {
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
		Replay        *struct {
			Height  *int64      `json:"height"`
			Binding wireBinding `json:"binding"`
			Startup wireBinding `json:"startup"`
			Repair  *bool       `json:"repair"`
		} `json:"replay"`
	}
	if err = json.Unmarshal(raw, &report); err != nil {
		return nil, err
	}
	if report.PID == nil || *report.PID <= 0 || report.StoreInstance == nil || !validStoreInstance(*report.StoreInstance) {
		return nil, errors.New("invalid Comet report")
	}
	result := &cometReport{Process: cometProcess{PID: *report.PID, StoreInstance: *report.StoreInstance}}
	if report.Start != nil {
		if _, err = strconv.ParseUint(*report.Start, 10, 64); err != nil {
			return nil, errors.New("invalid Comet start time")
		}
		result.Process.Start = *report.Start
	}
	if r := report.Replay; r != nil {
		if r.Height == nil || *r.Height <= 0 || r.Repair == nil {
			return nil, errors.New("invalid replay report")
		}
		replay := &replayReport{Height: *r.Height, Repair: *r.Repair}
		if replay.Binding, err = r.Binding.binding(); err != nil {
			return nil, err
		}
		if replay.Startup, err = r.Startup.binding(); err != nil {
			return nil, err
		}
		result.Replay = replay
	}
	return result, nil
}

// observe asks the supervisor's log observer, after it consumed every record Comet had written,
// about the current replay attempt: {"attempt": n, "open": bool, "height": h, "tainted": bool,
// "repaired": bool}.
func (s *supervisorChannel) observe(deadline time.Time) (*replayObservation, error) {
	reply, err := s.query("observe", nil, deadline)
	if err != nil {
		return nil, err
	}
	var o struct {
		Attempt  *uint64 `json:"attempt"`
		Open     *bool   `json:"open"`
		Height   *int64  `json:"height"`
		Tainted  *bool   `json:"tainted"`
		Repaired *bool   `json:"repaired"`
	}
	raw, ok := reply["replay"]
	if !ok || json.Unmarshal(raw, &o) != nil || o.Attempt == nil || o.Open == nil || o.Height == nil || o.Tainted == nil || o.Repaired == nil {
		return nil, fmt.Errorf("%w: invalid replay observation", errSupervisorUnavailable)
	}
	return &replayObservation{Attempt: *o.Attempt, Open: *o.Open, Height: *o.Height, Tainted: *o.Tainted, Repaired: *o.Repaired}, nil
}

// wal asks for the live binding of a signing request at height: {"binding": null} when the
// predecessor marker or the predecessor block is unknown, so same-height replay is unavailable.
func (s *supervisorChannel) wal(height int64, deadline time.Time) (*replayBinding, error) {
	reply, err := s.query("wal", map[string]any{"height": height}, deadline)
	if err != nil {
		return nil, err
	}
	raw, ok := reply["binding"]
	if !ok {
		return nil, errors.New("supervisor reply has no binding field")
	}
	if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		return nil, nil
	}
	var w wireBinding
	if err = json.Unmarshal(raw, &w); err != nil {
		return nil, err
	}
	binding, err := w.binding()
	if err != nil {
		return nil, err
	}
	return &binding, nil
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

// stopArmed asks whether the stop on a precommit is armed: {"stop": bool}.
func (s *supervisorChannel) stopArmed(deadline time.Time) (bool, error) {
	reply, err := s.query("stop", nil, deadline)
	if err != nil {
		return false, err
	}
	var armed bool
	if raw, ok := reply["stop"]; !ok || json.Unmarshal(raw, &armed) != nil {
		return false, errors.New("supervisor reply has no stop flag")
	}
	return armed, nil
}

// stopped reports the precommit after which the gate closed: {"op": "stopped", "height": H,
// "round": R}, acknowledged with {"stopped": true}.
func (s *supervisorChannel) stopped(height int64, round int32, deadline time.Time) error {
	reply, err := s.query("stopped", map[string]any{"height": height, "round": round}, deadline)
	if err != nil {
		return err
	}
	var acknowledged bool
	if raw, ok := reply["stopped"]; !ok || json.Unmarshal(raw, &acknowledged) != nil || !acknowledged {
		return errors.New("the supervisor did not acknowledge the stop")
	}
	return nil
}

// continuitySigner is a PrivValidator that enforces RECOV-8.2-2 itself: the gate admits each
// session through it before any signature, tells it what the supervisor observed for the request
// it passes on, and reports its own refusals.
type continuitySigner interface {
	types.PrivValidator
	admit(cometReport) error
	replayHeight() (int64, bool)
	setRequest(requestContext)
	refusedAt(height int64)
	// armStop arms the stop on a precommit; it closes the gate at once, and returns the HRS of
	// that last precommit, when the last signature already is one.
	armStop() (closed bool, height int64, round int32)
	// stoppedAfter reports whether the request just answered closed the gate after its
	// precommit, once; the caller then tells the supervisor.
	stoppedAfter() (closed bool, height int64, round int32)
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
	report, err := g.supervisor.comet(deadline)
	if errors.Is(err, errSupervisorUnavailable) {
		return fmt.Errorf("%w: %w", errTrustPending, err)
	}
	if err != nil {
		return err
	}
	if report == nil {
		return fmt.Errorf("%w: the supervisor runs no Comet for this signer", errTrustPending)
	}
	proc := report.Process
	if err = conn.verify(proc); err != nil {
		return err
	}
	if admitted := conn.admitted.Load(); admitted != nil {
		if *admitted != proc {
			return errors.New("the supervisor's Comet report changed during this transport connection")
		}
		return nil
	}
	if err = pv.admit(*report); err != nil {
		return err
	}
	conn.admitted.Store(&proc)
	return nil
}

// requestFor prepares, for a signing request at height that passed trust and admission, what the
// signer needs from the supervisor: in replay mode at the saved height, the observer's view of the
// replay, which must be available; for a fresh live signature, the live WAL binding, fetched only
// then. Both are bounded by deadline.
func (g *gate) requestFor(pv continuitySigner, height int64, deadline time.Time) (requestContext, error) {
	request := requestContext{live: func(h int64) *replayBinding {
		binding, err := g.supervisor.wal(h, deadline)
		if err != nil {
			if g.unavailable != nil {
				g.unavailable(fmt.Errorf("live replay binding unavailable: %w", err))
			}
			return nil
		}
		return binding
	}}
	if saved, ok := pv.replayHeight(); ok && saved == height {
		observation, err := g.supervisor.observe(deadline)
		if err != nil {
			return requestContext{}, err
		}
		request.observation = observation
	}
	armed, err := g.supervisor.stopArmed(deadline)
	if err != nil {
		return requestContext{}, err
	}
	if armed {
		g.armStop(pv, deadline)
	}
	return request, nil
}

// armStop arms the signer's stop on a precommit and tells the supervisor at once if that closed
// the gate (START-10.1-14b).
func (g *gate) armStop(pv continuitySigner, deadline time.Time) {
	if closed, height, round := pv.armStop(); closed {
		g.reportStop(height, round, deadline)
	}
}

// reportStop tells the supervisor that the gate closed after the precommit at height and round;
// it stops Comet only after that.
func (g *gate) reportStop(height int64, round int32, deadline time.Time) {
	if err := g.supervisor.stopped(height, round, deadline); err != nil && g.unavailable != nil {
		g.unavailable(fmt.Errorf("stop after precommit not acknowledged: %w", err))
	}
}

// pollStop arms the stop on a precommit as soon as the operator asks, between requests too, so
// a gate whose last signature already is a precommit closes without waiting for the next request.
func (g *gate) pollStop(pv continuitySigner, every time.Duration) {
	for !g.isStopping() {
		deadline := time.Now().Add(time.Second)
		if armed, err := g.supervisor.stopArmed(deadline); err == nil && armed {
			g.armStop(pv, deadline)
		}
		time.Sleep(every)
	}
}
