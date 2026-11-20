package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/libs/log"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/libp2p/go-libp2p/core/peer"
)

const chain = "etna-test"

type recordingPV struct {
	*privval.FilePV
	calls atomic.Int64
}

func (p *recordingPV) SignVote(chain string, vote *tm.Vote) error {
	p.calls.Add(1)
	return p.FilePV.SignVote(chain, vote)
}
func (p *recordingPV) SignProposal(chain string, proposal *tm.Proposal) error {
	p.calls.Add(1)
	return p.FilePV.SignProposal(chain, proposal)
}

func shortTemp(t *testing.T) string {
	t.Helper()
	d, e := os.MkdirTemp("/tmp", "etna-signer-")
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() { os.RemoveAll(d) })
	return d
}

func control(t *testing.T, reply func(map[string]any) any) string {
	t.Helper()
	path := filepath.Join(shortTemp(t), "trust.sock")
	l, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	go func() {
		for {
			c, e := l.Accept()
			if e != nil {
				return
			}
			go func() {
				defer c.Close()
				var req map[string]any
				if json.NewDecoder(c).Decode(&req) == nil {
					json.NewEncoder(c).Encode(reply(req))
				}
			}()
		}
	}()
	return path
}

// snapshot is a trust reply for chain's session "test:7" at eligible height 1: the gate's five
// fields, plus the nullable reason and recovery_origin keys every app snapshot carries (the
// supervisor's observe requires recovery_origin).
func snapshot(ready bool) map[string]any {
	return snapshotAt(ready, 1)
}

// snapshotAt is snapshot with the eligible height the app reports.
func snapshotAt(ready bool, eligible uint64) map[string]any {
	return map[string]any{"schema_version": 1, "session_id": "test:7", "chain_id": chain, "phase": map[bool]string{true: "ready", false: "catching_up"}[ready], "eligible_height": eligible, "reason": nil, "recovery_origin": nil}
}

// filePV is one validator initialized as an operator does: a stock native key, then
// init-domains-log and init-state for chain, with <d>/key.json, <d>/hrs/<chain>.json and
// <d>/domains/domains.log (domainsLogOf).
func filePV(t *testing.T) (*privval.FilePV, string, string) {
	t.Helper()
	d := t.TempDir()
	key, state := filepath.Join(d, "key.json"), filepath.Join(d, "hrs", chain+".json")
	for _, dir := range []string{filepath.Dir(state), filepath.Dir(domainsLogOf(state))} {
		if err := os.Mkdir(dir, 0700); err != nil {
			t.Fatal(err)
		}
	}
	privval.NewFilePV(secp256k1eth.GenPrivKey(), key, state).Key.Save()
	if err := initDomainsLog(domainsLogOf(state)); err != nil {
		t.Fatal(err)
	}
	if err := initState(chain, key, state, domainsLogOf(state)); err != nil {
		t.Fatal(err)
	}
	return privval.LoadFilePV(key, state), key, state
}

// domainsLogOf is filePV's domains log for its state path.
func domainsLogOf(state string) string {
	return filepath.Join(filepath.Dir(filepath.Dir(state)), "domains", "domains.log")
}

// recoveredSnapshot is the app's full Ready snapshot for chain at recovered generation g > 0,
// recovered at c = 6, so its first eligible height is 7. The gate reads only its
// schema_version, session_id, chain_id, phase and eligible_height.
func recoveredSnapshot(g uint64) map[string]any {
	hash, comet := "0x"+strings.Repeat("b", 64), "0x"+strings.Repeat("c", 64)
	value := snapshotAt(true, 7)
	value["generation"] = g
	value["target"] = map[string]any{"l1_number": 10, "l1_hash": "0x" + strings.Repeat("a", 64), "height": 6, "hash": hash, "comet_hash": comet, "generation": g, "inbox": "0x" + strings.Repeat("1", 40)}
	value["committed_head"] = map[string]any{"height": 6, "hash": hash}
	value["trusted_consensus_head"] = map[string]any{"height": 6, "hash": hash}
	value["recovery_origin"] = map[string]any{"generation": g, "height": 6, "l1_number": 9, "l1_hash": "0x" + strings.Repeat("a", 64), "l1_timestamp": 100, "el_hash": hash, "comet_hash": comet, "forced_cursor": 0, "committee_hash": "0x" + strings.Repeat("d", 64)}
	return value
}
func armed(path string) *gate {
	g := newGate(path, time.Second)
	session := "test:7"
	g.session.Store(&session)
	return g
}
func voteRequest(typ tm.SignedMsgType, round int32, nilBlock bool) pv.Message {
	vote := &tm.Vote{Type: typ, Height: 1, Round: round, Timestamp: time.Unix(100, 0)}
	if !nilBlock {
		vote.BlockID = tm.BlockID{Hash: bytes.Repeat([]byte{1}, 32), PartSetHeader: tm.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{2}, 32)}}
	}
	return pv.Message{Sum: &pv.Message_SignVoteRequest{SignVoteRequest: &pv.SignVoteRequest{ChainId: chain, Vote: vote}}}
}
func proposalRequest() pv.Message {
	return pv.Message{Sum: &pv.Message_SignProposalRequest{SignProposalRequest: &pv.SignProposalRequest{ChainId: chain, Proposal: &tm.Proposal{Type: tm.ProposalType, Height: 1, PolRound: -1, Timestamp: time.Unix(100, 0)}}}}
}
func TestClosedGateAllSigningFamilies(t *testing.T) {
	path := control(t, func(map[string]any) any { return snapshot(false) })
	gate := armed(path)
	backend, _, state := filePV(t)
	signer := &recordingPV{FilePV: backend}
	before, _ := os.ReadFile(state)
	requests := []pv.Message{voteRequest(tm.PrevoteType, 0, true), voteRequest(tm.PrecommitType, 0, true), voteRequest(tm.PrevoteType, 1, false), voteRequest(tm.PrecommitType, 1, false), proposalRequest(), proposalRequest()}
	for _, req := range requests {
		res, err := gate.handle(signer, req, chain)
		if err == nil {
			t.Fatal("closed signing succeeded")
		}
		if res.GetSignedVoteResponse() == nil && res.GetSignedProposalResponse() == nil {
			t.Fatal("missing protocol denial")
		}
	}
	after, _ := os.ReadFile(state)
	if !bytes.Equal(before, after) {
		t.Fatal("denial modified FilePV state")
	}
	if signer.calls.Load() != 0 {
		t.Fatal("closed gate invoked FilePV signing method")
	}
	for _, req := range []pv.Message{{Sum: &pv.Message_PingRequest{PingRequest: &pv.PingRequest{}}}, {Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: chain}}}} {
		if _, err := gate.handle(signer, req, chain); err != nil {
			t.Fatal(err)
		}
	}
}
func TestReadyIsFreshAndFilePVPersistsDoubleSignProtection(t *testing.T) {
	var ready atomic.Bool
	ready.Store(true)
	var checks atomic.Int64
	path := control(t, func(map[string]any) any { checks.Add(1); return snapshot(ready.Load()) })
	g := armed(path)
	signer, key, state := filePV(t)
	req := voteRequest(tm.PrecommitType, 0, false)
	res, err := g.handle(signer, req, chain)
	if err != nil || res.GetSignedVoteResponse().Error != nil {
		t.Fatalf("ready: %v %v", res, err)
	}
	signed := res.GetSignedVoteResponse().Vote.Signature
	if len(signed) != 65 {
		t.Fatal("no official signature")
	}
	signer = privval.LoadFilePV(key, state)
	retry, _ := g.handle(signer, voteRequest(tm.PrecommitType, 0, false), chain)
	if !bytes.Equal(signed, retry.GetSignedVoteResponse().Vote.Signature) {
		t.Fatal("same HRS retry changed signature")
	}
	conflicting := voteRequest(tm.PrecommitType, 0, true)
	res, _ = g.handle(signer, conflicting, chain)
	if res.GetSignedVoteResponse().Error == nil {
		t.Fatal("double sign allowed")
	}
	before, _ := os.ReadFile(state)
	ready.Store(false)
	res, err = g.handle(signer, voteRequest(tm.PrecommitType, 0, false), chain)
	if err == nil || res.GetSignedVoteResponse().Error == nil {
		t.Fatal("cached Ready accepted")
	}
	after, _ := os.ReadFile(state)
	if !bytes.Equal(before, after) {
		t.Fatal("denial mutated state")
	}
	if checks.Load() != 4 {
		t.Fatal("missing fresh check")
	}
}

// The gate reads only schema_version, session_id, chain_id, phase and eligible_height
// (SYNC-9-10/9-11, RECOV-8.2-4). Every other field, known or unknown, is ignored: the target
// comparison is app-side (SYNC-9-5). Anything but phase "ready" for this chain_id in the armed
// session at the request's eligible height denies before FilePV, and a reply for another
// session also drops the armed session.
func TestGateChecksOnlySessionChainAndPhase(t *testing.T) {
	line := func(r map[string]any) string { raw, _ := json.Marshal(r); return string(raw) }
	set := func(field string, value any) func(map[string]any) string {
		return func(r map[string]any) string { r[field] = value; return line(r) }
	}
	for _, test := range []struct {
		name  string
		reply func(map[string]any) string
		signs bool
	}{
		{"ready", line, true},
		{"extra-target-field", set("target", "garbage"), true},
		{"unknown-field", set("future", map[string]any{"x": 1}), true},
		{"null-target", set("target", nil), true},
		{"gate-fields-only", func(r map[string]any) string {
			return line(map[string]any{"schema_version": r["schema_version"], "session_id": r["session_id"], "chain_id": r["chain_id"], "phase": r["phase"], "eligible_height": r["eligible_height"]})
		}, true},
		{"missing-eligible-height", func(r map[string]any) string { delete(r, "eligible_height"); return line(r) }, false},
		{"null-eligible-height", set("eligible_height", nil), false},
		{"zero-eligible-height", set("eligible_height", 0), false},
		{"negative-eligible-height", set("eligible_height", -1), false},
		{"string-eligible-height", set("eligible_height", "1"), false},
		{"fractional-eligible-height", set("eligible_height", 1.5), false},
		{"other-eligible-height", set("eligible_height", 2), false},
		{"case-folded-eligible-height", func(r map[string]any) string {
			return strings.Replace(line(r), `"eligible_height":1`, `"eligible_height":2,"Eligible_Height":1`, 1)
		}, false},
		{"catching-up", set("phase", "catching_up"), false},
		{"other-chain", set("chain_id", "etna-other"), false},
		{"null-chain", set("chain_id", nil), false},
		{"other-session", set("session_id", "other"), false},
		{"duplicate-phase", func(r map[string]any) string {
			return strings.Replace(line(r), `"phase":"ready"`, `"phase":"catching_up","phase":"ready"`, 1)
		}, false},
		{"other-schema", set("schema_version", 2), false},
		{"empty-chain", set("chain_id", ""), false},
		// Keys are exact: a case-folded duplicate after the real key never overrides it.
		{"case-folded-phase", func(r map[string]any) string {
			return strings.Replace(line(r), `"phase":"ready"`, `"phase":"catching_up","Phase":"ready"`, 1)
		}, false},
		{"case-folded-chain", func(r map[string]any) string {
			return strings.Replace(line(r), `"chain_id":"`+chain+`"`, `"chain_id":"etna-other","CHAIN_ID":"`+chain+`"`, 1)
		}, false},
		{"case-folded-session", func(r map[string]any) string {
			return strings.Replace(line(r), `"session_id":"test:7"`, `"session_id":"other","Session_ID":"test:7"`, 1)
		}, false},
		{"case-folded-only", func(r map[string]any) string {
			return strings.Replace(line(r), `"phase":"ready"`, `"Phase":"ready"`, 1)
		}, false},
	} {
		t.Run(test.name, func(t *testing.T) {
			path := control(t, func(map[string]any) any { return json.RawMessage(test.reply(snapshot(true))) })
			g := armed(path)
			backend, key, state := filePV(t)
			signer := &recordingPV{FilePV: backend}
			before, _ := os.ReadFile(state)
			res, err := g.handle(signer, voteRequest(tm.PrevoteType, 0, false), chain)
			if test.signs {
				if err != nil || res.GetSignedVoteResponse().Error != nil || len(res.GetSignedVoteResponse().Vote.Signature) != 65 {
					t.Fatalf("refused: %v %v", res, err)
				}
				if persisted := privval.LoadFilePV(key, state).LastSignState; persisted.Height != 1 {
					t.Fatal("signature not persisted")
				}
				return
			}
			if err == nil || res.GetSignedVoteResponse().Error == nil || len(res.GetSignedVoteResponse().Vote.Signature) != 0 {
				t.Fatalf("signed: %v", res)
			}
			if after, _ := os.ReadFile(state); signer.calls.Load() != 0 || !bytes.Equal(before, after) {
				t.Fatal("denial reached FilePV")
			}
			if test.name == "other-session" && g.session.Load() != nil {
				t.Fatalf("another session's reply kept session %q armed", *g.session.Load())
			}
		})
	}
}

// Before InitChain the app's snapshot carries chain_id null. begin_session still arms the
// transport's session, so Comet's startup PubKey connects, and signing on it denies.
func TestBeginArmsSessionBeforeInitChain(t *testing.T) {
	path := control(t, func(req map[string]any) any {
		r := snapshot(req["op"] != "begin_session")
		r["chain_id"] = nil
		return r
	})
	g := newGate(path, time.Second)
	if session, err := g.begin(time.Now().Add(time.Second)); err != nil || session != "test:7" || g.session.Load() == nil {
		t.Fatalf("pre-InitChain begin_session: %q %v", session, err)
	}
	backend, _, state := filePV(t)
	signer := &recordingPV{FilePV: backend}
	before, _ := os.ReadFile(state)
	if res, err := g.handle(signer, voteRequest(tm.PrevoteType, 0, false), chain); err == nil || res.GetSignedVoteResponse().Error == nil {
		t.Fatal("signed without a chain ID")
	}
	if after, _ := os.ReadFile(state); signer.calls.Load() != 0 || !bytes.Equal(before, after) {
		t.Fatal("denial reached FilePV")
	}
}

// A reply that cannot carry Ready for this session and chain denies before FilePV: a wrong
// schema, an absent, null or empty session, a null phase or chain_id, an absent gate field,
// an error reply, or an absent app.
func TestControlFailuresDeny(t *testing.T) {
	for _, test := range []string{"version", "null_version", "session", "null_session", "empty_session", "missing_session", "chain", "null_chain", "missing_chain", "null_phase", "missing", "auth_error", "app_dead"} {
		t.Run(test, func(t *testing.T) {
			path := control(t, func(req map[string]any) any {
				r := snapshot(true)
				switch test {
				case "version":
					r["schema_version"] = 2
				case "null_version":
					r["schema_version"] = nil
				case "session":
					r["session_id"] = "other:1"
				case "null_session":
					r["session_id"] = nil
				case "empty_session":
					r["session_id"] = ""
				case "missing_session":
					delete(r, "session_id")
				case "chain":
					r["chain_id"] = "wrong"
				case "null_chain":
					r["chain_id"] = nil
				case "missing_chain":
					delete(r, "chain_id")
				case "null_phase":
					r["phase"] = nil
				case "missing":
					delete(r, "phase")
				case "auth_error":
					return map[string]any{"error": "unauthorized"}
				}
				return r
			})
			if test == "app_dead" {
				path = filepath.Join(t.TempDir(), "absent.sock")
			}
			g := armed(path)
			backend, _, state := filePV(t)
			signer := &recordingPV{FilePV: backend}
			before, _ := os.ReadFile(state)
			res, err := g.handle(signer, proposalRequest(), chain)
			if err == nil || res.GetSignedProposalResponse().Error == nil {
				t.Fatal("bad trust accepted")
			}
			after, _ := os.ReadFile(state)
			if signer.calls.Load() != 0 || !bytes.Equal(before, after) {
				t.Fatal("denial reached FilePV")
			}
		})
	}
}

// Readiness is the phase alone (SYNC-9-10/9-11): every phase other than the exact string
// "ready" denies before FilePV, and begin_session must answer a phase that is not "ready".
func TestReadinessIsPhaseOnly(t *testing.T) {
	const absent = "<absent>"
	for _, phase := range []any{"ready", "acquiring", "catching_up", "halted", "READY", " ready", "ready\n", "unknown", "", nil, absent} {
		with := func(r map[string]any) map[string]any {
			if phase == absent {
				delete(r, "phase")
			} else {
				r["phase"] = phase
			}
			return r
		}
		name := fmt.Sprintf("%#v", phase)
		t.Run("sign/"+name, func(t *testing.T) {
			path := control(t, func(map[string]any) any { return with(snapshot(true)) })
			backend, _, state := filePV(t)
			signer := &recordingPV{FilePV: backend}
			before, _ := os.ReadFile(state)
			res, err := armed(path).handle(signer, voteRequest(tm.PrecommitType, 0, false), chain)
			if phase == "ready" {
				if err != nil || res.GetSignedVoteResponse().Error != nil || len(res.GetSignedVoteResponse().Vote.Signature) != 65 {
					t.Fatalf("ready phase refused: %v %v", res, err)
				}
				return
			}
			if err == nil || res.GetSignedVoteResponse().Error == nil {
				t.Fatal("non-ready phase signed")
			}
			after, _ := os.ReadFile(state)
			if signer.calls.Load() != 0 || !bytes.Equal(before, after) {
				t.Fatal("non-ready phase reached FilePV")
			}
		})
		t.Run("begin/"+name, func(t *testing.T) {
			path := control(t, func(map[string]any) any { return with(snapshot(false)) })
			g := newGate(path, time.Second)
			session, err := g.begin(time.Now().Add(time.Second))
			closed := phase != "ready" && phase != nil && phase != absent
			if closed != (err == nil) {
				t.Fatalf("begin_session phase %q: session %q err %v", phase, session, err)
			}
			if !closed && g.session.Load() != nil {
				t.Fatal("refused begin_session armed a session")
			}
		})
	}
}

// Every trust query is bounded by the control timeout (SYNC-9-11): a malformed, duplicate-key
// or oversize reply, an app that accepts and never answers, a listener that never accepts, and
// a stale socket with no listener all deny a signing request within that bound, and none
// reaches FilePV. A dead or hung trust socket never hangs or authorizes a signature.
func TestMalformedAndTimeoutBounded(t *testing.T) {
	encoded, _ := json.Marshal(snapshot(true))
	duplicate := strings.Replace(string(encoded), `"phase":"ready"`, `"phase":"acquiring","phase":"ready"`, 1) + "\n"
	for _, test := range []struct{ name, payload string }{
		{"malformed", "{bad}\n"},
		{"duplicate", duplicate},
		{"oversize", strings.Repeat("x", maxControlFrame+1) + "\n"},
		{"unterminated", string(encoded)},
		{"silent", ""},
		{"never-accepts", ""},
		{"stale-socket", ""},
	} {
		t.Run(test.name, func(t *testing.T) {
			path := filepath.Join(shortTemp(t), "s")
			l, err := net.ListenUnix("unix", &net.UnixAddr{Name: path, Net: "unix"})
			if err != nil {
				t.Fatal(err)
			}
			defer l.Close()
			hold := make(chan struct{})
			defer close(hold)
			switch test.name {
			case "stale-socket":
				l.SetUnlinkOnClose(false)
				l.Close()
			case "never-accepts":
			default:
				go func() {
					c, e := l.Accept()
					if e != nil {
						return
					}
					defer c.Close()
					c.Write([]byte(test.payload))
					<-hold // Keep the connection open: only the deadline ends the read.
				}()
			}
			g := armed(path)
			g.timeout = 30 * time.Millisecond
			backend, _, state := filePV(t)
			signer := &recordingPV{FilePV: backend}
			before, _ := os.ReadFile(state)
			start := time.Now()
			res, err := g.handle(signer, voteRequest(tm.PrecommitType, 0, false), chain)
			if err == nil || res.GetSignedVoteResponse().Error == nil || len(res.GetSignedVoteResponse().Vote.Signature) != 0 {
				t.Fatal("malformed, hung or dead trust authorized a signature")
			}
			if elapsed := time.Since(start); elapsed > time.Second {
				t.Fatalf("unbounded trust query: %v", elapsed)
			}
			after, _ := os.ReadFile(state)
			if signer.calls.Load() != 0 || !bytes.Equal(before, after) {
				t.Fatal("denial reached FilePV")
			}
		})
	}
}
func TestDialBeginsEachTransportAndRearmsAppRestart(t *testing.T) {
	var begins atomic.Int64
	path := control(t, func(req map[string]any) any {
		r := snapshot(false)
		if req["op"] == "begin_session" {
			begins.Add(1)
		}
		return r
	})
	g := newGate(path, time.Second)
	var peers []net.Conn
	defer func() {
		for _, p := range peers {
			p.Close()
		}
	}()
	dial := g.dialer(func() (net.Conn, error) { a, b := net.Pipe(); peers = append(peers, b); return a, nil })
	for range 2 {
		c, err := dial()
		if err != nil {
			t.Fatal(err)
		}
		c.Close()
	}
	if begins.Load() != 2 {
		t.Fatal("transport did not rearm")
	}
	old := "previous-process:7"
	g.session.Store(&old)
	if err := g.check(chain, 1, time.Now().Add(2*time.Second)); err == nil {
		t.Fatal("old session accepted")
	}
	if begins.Load() != 3 || g.session.Load() == nil || *g.session.Load() != "test:7" {
		t.Fatal("app restart did not rearm")
	}
}

// appSessions answers like the app's trust handle: begin_session allocates a new closed
// session and check_session reports the current session, which the app authenticates later.
type appSessions struct {
	mu          sync.Mutex
	current     string
	ready       bool
	begins      int
	unavailable bool
}

func (a *appSessions) reply(req map[string]any) any {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.unavailable {
		return map[string]any{"error": "unavailable"}
	}
	if req["op"] == "begin_session" {
		a.begins++
		a.current = fmt.Sprintf("test:%d", a.begins)
		a.ready = false
	}
	r := snapshot(a.ready)
	r["session_id"] = a.current
	return r
}
func (a *appSessions) set(change func(*appSessions)) {
	a.mu.Lock()
	defer a.mu.Unlock()
	change(a)
}
func (a *appSessions) beginCount() int {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.begins
}
func observation(t *testing.T, path string) (uint64, string) {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var event struct {
		Sequence uint64 `json:"sequence"`
		Session  string `json:"session_id"`
	}
	if err = json.Unmarshal(data, &event); err != nil {
		t.Fatal(err)
	}
	return event.Sequence, event.Session
}

// A held signing request on a fresh session, such as the step a restarted Comet replays after a
// refusal, waits for the app's asynchronous check of that very session and is signed once it
// passes, within the hold (SYNC-9-12). The session was begun when the transport connected.
func TestHeldRequestSignsOnceTheFreshSessionIsTrusted(t *testing.T) {
	app := &appSessions{}
	path := control(t, app.reply)
	g := newGate(path, time.Second)
	g.hold = 3 * time.Second
	g.denialPath = filepath.Join(t.TempDir(), "denial.json")
	if _, err := g.begin(time.Now().Add(time.Second)); err != nil {
		t.Fatal(err)
	}
	go func() {
		time.Sleep(400 * time.Millisecond)
		app.set(func(a *appSessions) { a.ready = true })
	}()
	signer, _, _ := filePV(t)
	start := time.Now()
	res, err := g.handle(signer, voteRequest(tm.PrecommitType, 0, false), chain)
	if err != nil || res.GetSignedVoteResponse().Error != nil || len(res.GetSignedVoteResponse().Vote.Signature) != 65 {
		t.Fatalf("held request was refused: %v %v", res, err)
	}
	if elapsed := time.Since(start); elapsed < 300*time.Millisecond || elapsed > 2*time.Second {
		t.Fatalf("held request answered after %v", elapsed)
	}
	if sequence, session := observation(t, g.denialPath); app.beginCount() != 1 || sequence != 0 || session != "test:1" {
		t.Fatalf("begins %d observation %d %q", app.beginCount(), sequence, session)
	}
}

// Trust that stays closed is refused explicitly once the hold runs out, well before Comet's
// fixed 5 s read timeout, and published; an app that restarts meanwhile gets a fresh session.
// A halted app and another chain_id are final and refused at once, without holding.
func TestHeldRequestRefusesInTimeAndFinalAnswersDoNotHold(t *testing.T) {
	for _, test := range []struct {
		name  string
		reply func(*appSessions, map[string]any) map[string]any
		hold  bool
	}{
		{"closed", func(_ *appSessions, r map[string]any) map[string]any { return r }, true},
		{"halted", func(_ *appSessions, r map[string]any) map[string]any { r["phase"] = "halted"; return r }, false},
		{"other-chain", func(_ *appSessions, r map[string]any) map[string]any { r["chain_id"] = "etna-other"; return r }, false},
		{"other-height", func(_ *appSessions, r map[string]any) map[string]any {
			r["phase"], r["eligible_height"] = "ready", 2
			return r
		}, false},
	} {
		t.Run(test.name, func(t *testing.T) {
			app := &appSessions{}
			path := control(t, func(req map[string]any) any {
				r := app.reply(req).(map[string]any)
				if req["op"] == "check_session" {
					r = test.reply(app, r)
				}
				return r
			})
			g := newGate(path, time.Second)
			g.hold = 600 * time.Millisecond
			g.denialPath = filepath.Join(t.TempDir(), "denial.json")
			if _, err := g.begin(time.Now().Add(time.Second)); err != nil {
				t.Fatal(err)
			}
			if test.name == "closed" {
				// An app restart mid-hold: the next round begins a fresh session and keeps holding.
				go func() {
					time.Sleep(200 * time.Millisecond)
					app.set(func(a *appSessions) { a.current = "restarted:0" })
				}()
			}
			backend, _, state := filePV(t)
			signer := &recordingPV{FilePV: backend}
			before, _ := os.ReadFile(state)
			start := time.Now()
			res, err := g.handle(signer, voteRequest(tm.PrevoteType, 0, false), chain)
			elapsed := time.Since(start)
			if err == nil || res.GetSignedVoteResponse().Error == nil {
				t.Fatal("refused trust signed")
			}
			if test.hold && (elapsed < 500*time.Millisecond || elapsed > 1500*time.Millisecond) {
				t.Fatalf("closed trust was not held for the hold: %v", elapsed)
			}
			if !test.hold && elapsed > 300*time.Millisecond {
				t.Fatalf("a final refusal was held: %v", elapsed)
			}
			if after, _ := os.ReadFile(state); signer.calls.Load() != 0 || !bytes.Equal(before, after) {
				t.Fatal("refusal reached FilePV")
			}
			sequence, session := observation(t, g.denialPath)
			if sequence != 1 || (test.hold && (app.beginCount() != 2 || session != "test:2")) {
				t.Fatalf("begins %d observation %d %q", app.beginCount(), sequence, session)
			}
		})
	}
}

// The only signable height is the app's eligible height (SYNC-9-10): every other height, for
// votes, nil votes and proposals alike, is refused before FilePV, with the HRS unchanged; the
// eligible height signs. The app's answer moves with its committed boundary.
func TestOnlyTheEligibleHeightSigns(t *testing.T) {
	var eligible atomic.Uint64
	eligible.Store(5)
	path := control(t, func(map[string]any) any { return snapshotAt(true, eligible.Load()) })
	g := armed(path)
	backend, key, state := filePV(t)
	signer := &recordingPV{FilePV: backend}
	at := func(request pv.Message, height int64) pv.Message {
		if vote := request.GetSignVoteRequest(); vote != nil {
			vote.Vote.Height = height
		} else {
			request.GetSignProposalRequest().Proposal.Height = height
		}
		return request
	}
	before, _ := os.ReadFile(state)
	for _, height := range []int64{1, 4, 6, 1 << 40} {
		for _, request := range []pv.Message{voteRequest(tm.PrevoteType, 0, false), voteRequest(tm.PrecommitType, 0, true), proposalRequest()} {
			res, err := g.handle(signer, at(request, height), chain)
			if err == nil || !strings.Contains(err.Error(), "eligible height 5") {
				t.Fatalf("height %d: %v %v", height, res, err)
			}
		}
	}
	if after, _ := os.ReadFile(state); signer.calls.Load() != 0 || !bytes.Equal(before, after) {
		t.Fatal("a height other than the eligible one reached FilePV")
	}
	res, err := g.handle(signer, at(proposalRequest(), 5), chain)
	if err != nil || res.GetSignedProposalResponse().Error != nil || len(res.GetSignedProposalResponse().Proposal.Signature) != 65 {
		t.Fatalf("eligible height refused: %v %v", res, err)
	}
	eligible.Store(6)
	if _, err = g.handle(signer, at(voteRequest(tm.PrevoteType, 0, false), 5), chain); err == nil {
		t.Fatal("a committed height signed again")
	}
	if res, err = g.handle(signer, at(voteRequest(tm.PrevoteType, 0, false), 6), chain); err != nil || res.GetSignedVoteResponse().Error != nil {
		t.Fatalf("next eligible height refused: %v %v", res, err)
	}
	if persisted := privval.LoadFilePV(key, state).LastSignState; persisted.Height != 6 {
		t.Fatalf("persisted HRS height %d", persisted.Height)
	}
}

// The signer connects to Comet promptly whatever the app's state: a transport is exposed, and
// answers PubKey and Ping, even when the app cannot begin its session (START-10-6). The empty
// session it publishes tells the supervisor the transport connected, and the first signing
// request begins the session, held until it is trusted.
func TestDialerConnectsPromptlyWithoutTheApp(t *testing.T) {
	app := &appSessions{}
	path := filepath.Join(shortTemp(t), "trust.sock")
	g := newGate(path, 200*time.Millisecond)
	g.hold = 3 * time.Second
	g.denialPath = filepath.Join(t.TempDir(), "denial.json")
	signer, _, _ := filePV(t)
	addr := filepath.Join(shortTemp(t), "comet.sock")
	raw, err := net.Listen("unix", addr)
	if err != nil {
		t.Fatal(err)
	}
	endpoint := privval.NewSignerListenerEndpoint(log.NewNopLogger(), privval.NewUnixListener(raw))
	client, err := privval.NewSignerClient(endpoint, chain)
	if err != nil {
		t.Fatal(err)
	}
	server := privval.NewSignerServer(privval.NewSignerDialerEndpoint(log.NewNopLogger(), g.dialer(privval.DialUnixFn(addr))), chain, signer)
	server.SetRequestHandler(g.handle)
	if err = server.Start(); err != nil {
		t.Fatal(err)
	}
	defer func() { g.closeTransports(); server.Stop(); endpoint.Stop() }()
	if err = client.WaitForConnection(3 * time.Second); err != nil {
		t.Fatal(err)
	}
	if _, err = client.GetPubKey(); err != nil {
		t.Fatal(err)
	}
	if err = client.Ping(); err != nil {
		t.Fatal(err)
	}
	if sequence, session := observation(t, g.denialPath); sequence != 0 || session != "" || g.session.Load() != nil {
		t.Fatalf("connection without the app: %d %q", sequence, session)
	}
	// The app comes up and authenticates the session the first signing request begins.
	l, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	go func() {
		for {
			c, e := l.Accept()
			if e != nil {
				return
			}
			go func() {
				defer c.Close()
				var req map[string]any
				if json.NewDecoder(c).Decode(&req) == nil {
					reply := app.reply(req)
					if req["op"] == "begin_session" {
						go func() { time.Sleep(300 * time.Millisecond); app.set(func(a *appSessions) { a.ready = true }) }()
					}
					json.NewEncoder(c).Encode(reply)
				}
			}()
		}
	}()
	request := voteRequest(tm.PrecommitType, 0, false)
	vote := request.GetSignVoteRequest().Vote
	if err = client.SignVote(chain, vote); err != nil || len(vote.Signature) != 65 {
		t.Fatalf("first signing request on the lazily begun session: %v", err)
	}
	if sequence, session := observation(t, g.denialPath); app.beginCount() != 1 || sequence != 0 || session != "test:1" {
		t.Fatalf("begins %d observation %d %q", app.beginCount(), sequence, session)
	}
}

func TestNilAndWrongChainRequests(t *testing.T) {
	g := armed("missing")
	signer, _, _ := filePV(t)
	for _, req := range []pv.Message{{Sum: &pv.Message_SignVoteRequest{}}, {Sum: &pv.Message_SignProposalRequest{}}, {Sum: &pv.Message_SignVoteRequest{SignVoteRequest: &pv.SignVoteRequest{ChainId: "wrong", Vote: &tm.Vote{}}}}} {
		if _, err := g.handle(signer, req, chain); err == nil {
			t.Fatal("invalid request accepted")
		}
	}
}

// Use the same official protobuf endpoint and transports as a real Comet process: a Unix
// socket, and stock Noise with both peer IDs pinned. Closed nil/locked/retained messages must
// receive protocol denials.
func TestOfficialSignerWire(t *testing.T) {
	for _, transport := range []string{"unix", "noise"} {
		t.Run(transport, func(t *testing.T) {
			var ready atomic.Bool
			path := control(t, func(req map[string]any) any {
				if req["op"] == "begin_session" {
					return snapshot(false)
				}
				return snapshot(ready.Load())
			})
			g := newGate(path, time.Second)
			signer, _, state := filePV(t)
			before, _ := os.ReadFile(state)
			var listener net.Listener
			var dial privval.SocketDialer
			var err error
			if transport == "unix" {
				addr := filepath.Join(shortTemp(t), "comet.sock")
				raw, e := net.Listen("unix", addr)
				if e != nil {
					t.Fatal(e)
				}
				listener = privval.NewUnixListener(raw)
				dial = privval.DialUnixFn(addr)
			} else {
				listener, dial = noisePair(t, ed25519.GenPrivKey(), ed25519.GenPrivKey())
			}
			endpoint := privval.NewSignerListenerEndpoint(log.NewNopLogger(), listener)
			client, err := privval.NewSignerClient(endpoint, chain)
			if err != nil {
				t.Fatal(err)
			}
			server := privval.NewSignerServer(privval.NewSignerDialerEndpoint(log.NewNopLogger(), g.dialer(dial)), chain, signer)
			server.SetRequestHandler(g.handle)
			if err = server.Start(); err != nil {
				t.Fatal(err)
			}
			defer func() { g.closeTransports(); server.Stop(); endpoint.Stop() }()
			if err = client.WaitForConnection(3 * time.Second); err != nil {
				t.Fatal(err)
			}
			if _, err = client.GetPubKey(); err != nil {
				t.Fatal(err)
			}
			for _, typ := range []tm.SignedMsgType{tm.PrevoteType, tm.PrecommitType} {
				for _, nilBlock := range []bool{true, false} {
					request := voteRequest(typ, 0, nilBlock)
					vote := request.GetSignVoteRequest().Vote
					if err = client.SignVote(chain, vote); err == nil {
						t.Fatal("closed vote signed on wire")
					}
				}
			}
			for range 2 {
				request := proposalRequest()
				if err = client.SignProposal(chain, request.GetSignProposalRequest().Proposal); err == nil {
					t.Fatal("retained proposal signed")
				}
			}
			after, _ := os.ReadFile(state)
			if !bytes.Equal(before, after) {
				t.Fatal("wire denial changed FilePV")
			}
			ready.Store(true)
			request := voteRequest(tm.PrecommitType, 0, false)
			vote := request.GetSignVoteRequest().Vote
			if err = client.SignVote(chain, vote); err != nil || len(vote.Signature) != 65 {
				t.Fatalf("ready official signing: %v", err)
			}
			ready.Store(false)
			if err = client.SignVote(chain, vote); err == nil {
				t.Fatal("repeat signature bypassed closed gate")
			}
		})
	}
}

func TestPubKeyAndPingWithAbsentAppAndNoSession(t *testing.T) {
	g := newGate("/absent-trust.sock", time.Second)
	signer, _, _ := filePV(t)
	for _, req := range []pv.Message{{Sum: &pv.Message_PingRequest{PingRequest: &pv.PingRequest{}}}, {Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: chain}}}} {
		if _, err := g.handle(signer, req, chain); err != nil {
			t.Fatal(err)
		}
	}
}

func TestMalformedReadyRequestsNeverReachFilePV(t *testing.T) {
	path := control(t, func(map[string]any) any { return snapshot(true) })
	g := armed(path)
	backend, _, state := filePV(t)
	signer := &recordingPV{FilePV: backend}
	before, _ := os.ReadFile(state)
	invalidVote := voteRequest(tm.PrevoteType, 0, true)
	invalidVote.GetSignVoteRequest().Vote.Type = tm.UnknownType
	malformedBlock := voteRequest(tm.PrevoteType, 0, false)
	malformedBlock.GetSignVoteRequest().Vote.BlockID.Hash = []byte{1}
	invalidProposal := proposalRequest()
	invalidProposal.GetSignProposalRequest().Proposal.Type = tm.UnknownType
	for _, request := range []pv.Message{invalidVote, malformedBlock, invalidProposal} {
		if _, err := g.handle(signer, request, chain); err == nil {
			t.Fatal("malformed request accepted")
		}
	}
	after, _ := os.ReadFile(state)
	if signer.calls.Load() != 0 || !bytes.Equal(before, after) {
		t.Fatal("malformed Ready request reached FilePV")
	}
}

// A timeout must be observable even when the app never published a closed state.
func TestDenialSignalIncludesTimeoutWithoutChangingHRS(t *testing.T) {
	path := control(t, func(map[string]any) any { time.Sleep(100 * time.Millisecond); return snapshot(true) })
	g := armed(path)
	g.timeout = 10 * time.Millisecond
	g.denialPath = filepath.Join(t.TempDir(), "denial.json")
	signer, _, state := filePV(t)
	before, _ := os.ReadFile(state)
	for sequence := uint64(1); sequence <= 2; sequence++ {
		_, err := g.handle(signer, voteRequest(tm.PrevoteType, 0, true), chain)
		if err == nil {
			t.Fatal("timeout authorized a signature")
		}
		data, err := os.ReadFile(g.denialPath)
		if err != nil {
			t.Fatalf("timeout must publish denial before returning: %v", err)
		}
		var event struct {
			Sequence uint64 `json:"sequence"`
		}
		if err := json.Unmarshal(data, &event); err != nil || event.Sequence != sequence {
			t.Fatalf("denial sequence: %s %v", data, err)
		}
	}
	after, _ := os.ReadFile(state)
	if !bytes.Equal(before, after) {
		t.Fatal("timeout changed authoritative HRS")
	}
}

// A recovered generation has its own full chain_id and so its own HRS state (RECOV-8.2-1,
// RECOV-8.2-5): once its trust is Ready the gate signs into the state the signer serves, which
// init-state created for that chain_id, and a request for any other chain is refused.
func TestGateSignsRecoveredGenerationIntoItsOwnState(t *testing.T) {
	ready := recoveredSnapshot(1)
	g := armed(control(t, func(map[string]any) any { return ready }))
	signer, key, state := filePV(t)
	vote := func(chain string) pv.Message {
		return pv.Message{Sum: &pv.Message_SignVoteRequest{SignVoteRequest: &pv.SignVoteRequest{ChainId: chain, Vote: &tm.Vote{Type: tm.PrevoteType, Height: 7, Timestamp: time.Unix(100, 0)}}}}
	}
	before, _ := os.ReadFile(state)
	res, err := g.handle(signer, vote("etna-other"), chain)
	if err == nil || res.GetSignedVoteResponse().Error == nil {
		t.Fatal("another chain's request signed")
	}
	if after, _ := os.ReadFile(state); !bytes.Equal(before, after) {
		t.Fatal("refused chain changed the HRS")
	}
	res, err = g.handle(signer, vote(chain), chain)
	if err != nil || res.GetSignedVoteResponse().Error != nil || len(res.GetSignedVoteResponse().Vote.Signature) != 65 {
		t.Fatalf("recovered generation refused: %v %v", res, err)
	}
	if persisted := privval.LoadFilePV(key, state); persisted.LastSignState.Height != 7 {
		t.Fatal("signature not persisted in the chain's own HRS")
	}
}

// noisePair is stock Comet's Noise signer listener, keyed by cometKey and pinning signerKey's
// peer ID as Comet's noise://<signer-peer-id>@<ip>:<port> does, and the signer's dialer for it,
// keyed by signerKey and pinning cometKey's peer ID.
func noisePair(t *testing.T, cometKey, signerKey ed25519.PrivKey) (net.Listener, privval.SocketDialer) {
	t.Helper()
	signerPeer, err := transportPeerID(signerKey)
	if err != nil {
		t.Fatal(err)
	}
	cometPeer, err := transportPeerID(cometKey)
	if err != nil {
		t.Fatal(err)
	}
	raw, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	listener, err := privval.NewNoiseListener(raw, cometKey, []peer.ID{signerPeer})
	if err != nil {
		t.Fatal(err)
	}
	dial, err := noiseDialer("noise://"+cometPeer.String()+"@"+raw.Addr().String(), signerKey)
	if err != nil {
		t.Fatal(err)
	}
	return listener, dial
}
