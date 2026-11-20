package boundary

import (
	"bytes"
	"encoding/json"
	"fmt"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	"github.com/cometbft/cometbft/evidence"
	"github.com/cometbft/cometbft/libs/log"
	"github.com/cometbft/cometbft/p2p"
	pb "github.com/cometbft/cometbft/proto/tendermint/types"
	sm "github.com/cometbft/cometbft/state"
	cmt "github.com/cometbft/cometbft/types"
	gogotypes "github.com/cosmos/gogoproto/types"
)

const historicalSeconds int64 = 1699999900
const broadcastFrame = "github.com/cometbft/cometbft/evidence.(*Reactor).broadcastEvidenceRoutine"

var evidenceCases = []string{"cold-grid", "gossip", "pending-restart", "committed-window"}

func historicalTime() time.Time { return time.Unix(historicalSeconds, 0).UTC() }

func evidenceState(t *testing.T, s publicSetup, height, age int64) sm.State {
	t.Helper()
	vals := s.validators(t, 3)
	params := *cmt.DefaultConsensusParams()
	params.Validator.PubKeyTypes = []string{s.signer.Type()}
	params.Evidence.MaxAgeNumBlocks = 900
	params.Evidence.MaxAgeDuration = time.Hour
	params.Version.App = 17
	params.ABCI.VoteExtensionsEnableHeight = 0
	need(t, params.ValidateBasic() == nil, "valid synthetic evidence parameters")
	version := sm.InitStateVersion
	version.Consensus.App = 17
	return sm.State{Version: version, ChainID: s.rows["precommit_a"].ChainID,
		InitialHeight: 1, LastBlockHeight: height, LastBlockTime: historicalTime().Add(time.Duration(age) * time.Second),
		LastBlockID: s.vote(t, "precommit_a", 0).BlockID,
		LastValidators: vals.Copy(), Validators: vals.Copy(), NextValidators: vals.Copy(),
		LastHeightValidatorsChanged: 1001, LastHeightConsensusParamsChanged: 1001,
		ConsensusParams: params, AppHash: bytes.Repeat([]byte{0x10}, 32), LastResultsHash: bytes.Repeat([]byte{0x20}, 32)}
}

func evidenceView(t *testing.T, s publicSetup, ev *cmt.DuplicateVoteEvidence) observation {
	t.Helper()
	bare, err := ev.ToProto().Marshal()
	need(t, err == nil && bytes.Equal(bare, ev.Bytes()), "bare duplicate-vote bytes: %v", err)
	wrapped, err := cmt.EvidenceToProto(ev)
	need(t, err == nil, "evidence wrapper: %v", err)
	envelope, err := wrapped.Marshal()
	need(t, err == nil, "evidence wrapper bytes: %v", err)
	list := &pb.EvidenceList{Evidence: []pb.Evidence{*wrapped}}
	listBytes, err := list.Marshal()
	need(t, err == nil, "evidence-list bytes: %v", err)
	return observation{"height": ev.Height(), "seconds": ev.Time().Unix(), "nanos": ev.Time().Nanosecond(),
		"voteA": voteView(ev.VoteA, s.rows["precommit_a"].ChainID), "voteB": voteView(ev.VoteB, s.rows["precommit_a"].ChainID),
		"validatorPower": ev.ValidatorPower, "totalVotingPower": ev.TotalVotingPower,
		"duplicateProto": hx(bare), "evidenceBytes": hx(ev.Bytes()), "hash": hx(ev.Hash()),
		"envelopeProto": hx(envelope), "listProto": hx(listBytes), "listBytes": len(listBytes),
		"listHash": hx(cmt.EvidenceList{ev}.Hash()), "validators": setView(t, s.validators(t, 3))}
}

func makeEvidence(t *testing.T, s publicSetup, stamp time.Time) *cmt.DuplicateVoteEvidence {
	t.Helper()
	// Supply B first so the stock constructor, not this fixture, chooses order.
	ev, err := cmt.NewDuplicateVoteEvidence(s.vote(t, "precommit_b", 0), s.vote(t, "precommit_a", 0), stamp, s.validators(t, 3))
	need(t, err == nil && ev.ValidateBasic() == nil, "public duplicate-vote shape: %v", err)
	need(t, evidence.VerifyDuplicateVote(ev, s.rows["precommit_a"].ChainID, s.validators(t, 3)) == nil, "real duplicate-vote verification")
	return ev
}

func evidenceRows(t *testing.T, db dbm.DB) map[string]string {
	t.Helper()
	it, err := db.Iterator(nil, nil)
	need(t, err == nil, "evidence database iterator: %v", err)
	defer func() { need(t, it.Close() == nil, "close evidence database iterator") }()
	rows := make(map[string]string)
	for ; it.Valid(); it.Next() {
		rows[hx(it.Key())] = hx(it.Value())
	}
	need(t, it.Error() == nil, "database iterator error")
	return rows
}

func evidenceResult(err error) observation {
	result := observation{"accepted": err == nil, "errorType": "", "reason": "", "error": ""}
	if err != nil {
		result["errorType"], result["reason"], result["error"] = fmt.Sprintf("%T", err), err.Error(), err.Error()
		if invalid, ok := err.(*cmt.ErrInvalidEvidence); ok {
			result["reason"] = invalid.Reason.Error()
		}
	}
	return result
}

type evidenceHistory struct {
	mu sync.Mutex
	meta *cmt.BlockMeta
	available bool
	headers []int64
	commits []int64
	heightCalls int
}

func (h *evidenceHistory) LoadBlockMeta(height int64) *cmt.BlockMeta {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.headers = append(h.headers, height)
	if height == 1000 && h.available {
		return h.meta
	}
	return nil
}
func (h *evidenceHistory) LoadBlockCommit(height int64) *cmt.Commit {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.commits = append(h.commits, height)
	return nil
}
func (h *evidenceHistory) Height() int64 {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.heightCalls++
	return 1000
}

type evidenceStore struct {
	sm.Store
	mu sync.Mutex
	validators []int64
}

func (s *evidenceStore) LoadValidators(height int64) (*cmt.ValidatorSet, error) {
	s.mu.Lock()
	s.validators = append(s.validators, height)
	s.mu.Unlock()
	return s.Store.LoadValidators(height)
}

type evidenceBranch struct {
	path string
	name string
	stateDB dbm.DB
	evidenceDB dbm.DB
	store *evidenceStore
	history *evidenceHistory
	pool *evidence.Pool
	closed bool
	broadcastMayLive bool
}

func openEvidenceBranch(t *testing.T, s publicSetup, name string, used map[string]bool) *evidenceBranch {
	t.Helper()
	path := t.TempDir()
	need(t, !used[path], "evidence/state directory reused")
	used[path] = true
	b := &evidenceBranch{path: path, name: name}
	// Register ownership before the first acquisition; setup Fatal paths still
	// attempt both closes. A begun broadcast has an additional exit prerequisite.
	t.Cleanup(func() { b.close(t) })
	stateDB, err := dbm.NewGoLevelDB("state", path)
	if stateDB != nil { b.stateDB = stateDB }
	need(t, err == nil && stateDB != nil, "open state database: %v", err)
	evidenceDB, err := dbm.NewGoLevelDB("evidence", path)
	if evidenceDB != nil { b.evidenceDB = evidenceDB }
	need(t, err == nil && evidenceDB != nil, "open evidence database: %v", err)
	b.store = &evidenceStore{Store: sm.NewStore(b.stateDB, sm.StoreOptions{})}
	need(t, b.store.Bootstrap(evidenceState(t, s, 1000, 0)) == nil, "actual state Bootstrap")
	b.history = &evidenceHistory{available: true, meta: &cmt.BlockMeta{Header: cmt.Header{
		ChainID: s.rows["precommit_a"].ChainID, Height: 1000, Time: historicalTime()}}}
	return b
}

func (b *evidenceBranch) start(t *testing.T) {
	t.Helper()
	var err error
	b.pool, err = evidence.NewPool(b.evidenceDB, b.store, b.history)
	need(t, err == nil, "actual evidence NewPool: %v", err)
}

func (b *evidenceBranch) close(t *testing.T) {
	t.Helper()
	if b.closed { return }
	if b.broadcastMayLive {
		t.Errorf("INCONCLUSIVE: database close withheld until actual broadcast exit")
		return
	}
	errors := make([]string, 0, 2)
	if b.evidenceDB != nil {
		if err := b.evidenceDB.Close(); err != nil { errors = append(errors, "evidence: "+err.Error()) }
	}
	if b.store != nil {
		if err := b.store.Close(); err != nil { errors = append(errors, "state: "+err.Error()) }
	} else if b.stateDB != nil {
		if err := b.stateDB.Close(); err != nil { errors = append(errors, "partial state: "+err.Error()) }
	}
	b.closed = true
	need(t, len(errors) == 0, "INCONCLUSIVE: database close errors: %v", errors)
}

func (b *evidenceBranch) reopen(t *testing.T) {
	t.Helper()
	need(t, b.closed, "reopen must follow close")
	b.stateDB, b.evidenceDB, b.store, b.pool = nil, nil, nil, nil
	b.closed = false
	stateDB, err := dbm.NewGoLevelDB("state", b.path)
	if stateDB != nil { b.stateDB = stateDB }
	need(t, err == nil && stateDB != nil, "reopen state database: %v", err)
	evidenceDB, err := dbm.NewGoLevelDB("evidence", b.path)
	if evidenceDB != nil { b.evidenceDB = evidenceDB }
	need(t, err == nil && evidenceDB != nil, "reopen evidence database: %v", err)
	b.store = &evidenceStore{Store: sm.NewStore(b.stateDB, sm.StoreOptions{})}
}

func (b *evidenceBranch) lookups() observation {
	b.history.mu.Lock()
	defer b.history.mu.Unlock()
	b.store.mu.Lock()
	defer b.store.mu.Unlock()
	return observation{"headers": append([]int64{}, b.history.headers...), "commits": append([]int64{}, b.history.commits...),
		"heightCalls": b.history.heightCalls, "validators": append([]int64{}, b.store.validators...)}
}

func (b *evidenceBranch) resetLookups() {
	b.history.mu.Lock()
	b.history.headers, b.history.commits, b.history.heightCalls = nil, nil, 0
	b.history.mu.Unlock()
	b.store.mu.Lock()
	b.store.validators = nil
	b.store.mu.Unlock()
}

func (b *evidenceBranch) view(t *testing.T) observation {
	t.Helper()
	state, err := b.store.Load()
	need(t, err == nil, "actual state Load: %v", err)
	paramsProto := state.ConsensusParams.ToProto()
	params, err := paramsProto.Marshal()
	need(t, err == nil, "state params bytes: %v", err)
	pending, pendingBytes := b.pool.PendingEvidence(-1)
	hashes := make([]string, len(pending))
	for i, ev := range pending { hashes[i] = hx(ev.Hash()) }
	poolState := b.pool.State()
	return observation{"store": b.name, "stateProto": hx(state.Bytes()), "poolStateProto": hx(poolState.Bytes()),
		"height": state.LastBlockHeight, "seconds": state.LastBlockTime.Unix(), "nanos": state.LastBlockTime.Nanosecond(),
		"paramsProto": hx(params), "stateRows": evidenceRows(t, b.stateDB), "evidenceRows": evidenceRows(t, b.evidenceDB),
		"size": b.pool.Size(), "pendingHashes": hashes, "pendingBytes": pendingBytes,
		"frontPresent": b.pool.EvidenceFront() != nil}
}

func (b *evidenceBranch) update(t *testing.T, state sm.State, committed cmt.EvidenceList) {
	t.Helper()
	b.pool.Update(state, committed)
	need(t, b.store.Save(state) == nil, "actual state Save after Pool.Update")
}

func coldEvidence(t *testing.T, s publicSetup, ev *cmt.DuplicateVoteEvidence, used map[string]bool) (observation, observation) {
	contexts := make([]observation, 0, 6)
	details := make([]observation, 0, 6)
	accepted, expired := 0, 0
	for _, height := range []int64{1900, 1901} {
		for _, age := range []int64{3599, 3600, 3601} {
			name := fmt.Sprintf("cold-%d-%d", height, age)
			b := openEvidenceBranch(t, s, name, used)
			state := evidenceState(t, s, height, age)
			need(t, b.store.Save(state) == nil, "cold latest state Save")
			b.start(t)
			before := b.view(t)
			b.resetLookups()
			err := b.pool.CheckEvidence(cmt.EvidenceList{ev})
			result, after, lookups := evidenceResult(err), b.view(t), b.lookups()
			label := "accept"
			if err != nil {
				want := fmt.Sprintf("evidence from height %d (created at: %v) is too old; min height is %d and evidence can not be older than %v", ev.Height(), ev.Time(), height-900, state.LastBlockTime.Add(time.Hour))
				need(t, err.Error() == want, "INCONCLUSIVE: unrelated cold evidence error: %v", err)
				label = "expired"
				expired++
			} else { accepted++ }
			contexts = append(contexts, observation{"store": name, "height": height, "seconds": state.LastBlockTime.Unix(),
				"accepted": err == nil, "result": label, "headerLookups": lookups["headers"], "validatorLookups": lookups["validators"],
				"beforePending": before["size"], "afterPending": after["size"], "afterGossip": after["frontPresent"]})
			details = append(details, observation{"before": before, "after": after, "result": result, "lookups": lookups})
			b.close(t)
		}
	}
	alias := makeEvidence(t, s, ev.VoteA.Timestamp)
	b := openEvidenceBranch(t, s, "cold-vote-time-alias", used)
	need(t, b.store.Save(evidenceState(t, s, 1900, 3599)) == nil, "alias latest state Save")
	b.start(t)
	before := b.view(t)
	b.resetLookups()
	err := b.pool.CheckEvidence(cmt.EvidenceList{alias})
	after, lookups := b.view(t), b.lookups()
	need(t, err != nil && err.Error() == fmt.Sprintf("evidence has a different time to the block it is associated with (%v != %v)", alias.Time(), ev.Time()), "actual wrong historical evidence time refusal")
	aliasContext := observation{"seconds": alias.Time().Unix(), "nanos": alias.Time().Nanosecond(), "accepted": false,
		"result": "historical-time", "headerLookups": lookups["headers"], "validatorLookups": lookups["validators"],
		"beforePending": before["size"], "afterPending": after["size"]}
	aliasDetails := observation{"evidence": evidenceView(t, s, alias), "before": before, "after": after, "result": evidenceResult(err), "lookups": lookups}
	b.close(t)
	if accepted != 5 || expired != 1 {
		t.Errorf("evidence-age id=cold-grid expected=5-valid-1-expired got=%d-valid-%d-expired", accepted, expired)
	}
	return observation{"case": "cold-grid", "evidenceHeight": ev.Height(), "historicalSeconds": ev.Time().Unix(),
		"historicalNanos": ev.Time().Nanosecond(), "voteSeconds": ev.VoteA.Timestamp.Unix(), "voteNanos": ev.VoteA.Timestamp.Nanosecond(),
		"maxAgeNumBlocks": 900, "maxAgeSeconds": 3600, "cells": contexts, "voteTimeAlias": aliasContext},
		observation{"cells": details, "voteTimeAlias": aliasDetails}
}

func broadcastProfile() (observation, error) {
	for attempt := 0; attempt < 8; attempt++ {
		n, _ := runtime.GoroutineProfile(nil)
		records := make([]runtime.StackRecord, n+32)
		n, complete := runtime.GoroutineProfile(records)
		if !complete { continue }
		if n <= 0 { return nil, fmt.Errorf("INCONCLUSIVE: nonpositive goroutine profile inventory") }
		depths := make([]int, n)
		maximum, saturated, empty := 0, 0, 0
		for i, record := range records[:n] {
			depths[i] = len(record.Stack())
			if depths[i] > maximum { maximum = depths[i] }
			if depths[i] >= len(record.Stack0) { saturated++ }
			if depths[i] == 0 { empty++ }
		}
		// GoroutineProfile's bool covers the record inventory, not Stack0's
		// 32-PC capacity. A saturated stack could hide the target caller frame.
		// The pinned runtime may return n,true after an endOffset mismatch;
		// reject zero-depth tail records too, rather than counting them absent.
		if saturated != 0 || empty != 0 {
			return observation{"complete": false, "inventoryComplete": true, "totalGoroutines": n,
				"frameCapacity": 32, "stackDepths": depths, "maxStackDepth": maximum,
				"saturatedStacks": saturated, "emptyStacks": empty}, fmt.Errorf("INCONCLUSIVE: incomplete goroutine stack profile")
		}
		matches := make([][]string, 0)
		for _, record := range records[:n] {
			frames := runtime.CallersFrames(record.Stack())
			functions := make([]string, 0)
			found := false
			for {
				frame, more := frames.Next()
				functions = append(functions, frame.Function)
				if frame.Function == broadcastFrame { found = true }
				if !more { break }
			}
			if found { matches = append(matches, functions) }
		}
		return observation{"complete": true, "inventoryComplete": true, "totalGoroutines": n,
			"frameCapacity": 32, "stackDepths": depths, "maxStackDepth": maximum,
			"saturatedStacks": saturated, "emptyStacks": empty, "matches": matches, "count": len(matches)}, nil
	}
	return nil, fmt.Errorf("INCONCLUSIVE: complete goroutine profile unavailable")
}

func waitBroadcastExit() (observation, error) {
	deadline := time.Now().Add(2 * time.Second)
	for {
		profile, err := broadcastProfile()
		if err != nil { return nil, err }
		if profile["count"] == 0 { return profile, nil }
		if time.Now().After(deadline) { return profile, fmt.Errorf("INCONCLUSIVE: broadcast exit not observed") }
		runtime.Gosched()
		time.Sleep(time.Millisecond)
	}
}

type evidencePeerState struct { height int64 }
func (s evidencePeerState) GetHeight() int64 { return s.height }

type evidencePeer struct {
	p2p.Peer // Unexpected methods have no implementation and remain an unexpected panic.
	height int64
	quit chan struct{}
	mu sync.Mutex
	stopped bool
	sends int
	overflow bool
	events chan observation
}

func (p *evidencePeer) ID() p2p.ID { return p2p.ID(fmt.Sprintf("controlled-peer-%d", p.height)) }
func (p *evidencePeer) String() string { return string(p.ID()) }
func (p *evidencePeer) Get(key string) any {
	if key == cmt.PeerStateKey { return evidencePeerState{p.height} }
	panic("unexpected controlled peer lookup")
}
func (p *evidencePeer) Quit() <-chan struct{} { return p.quit }
func (p *evidencePeer) IsRunning() bool {
	p.mu.Lock(); defer p.mu.Unlock()
	return !p.stopped
}
func (p *evidencePeer) stop() {
	p.mu.Lock(); defer p.mu.Unlock()
	if !p.stopped { p.stopped = true; close(p.quit) }
}
func (p *evidencePeer) publish(row observation) {
	p.mu.Lock(); defer p.mu.Unlock()
	select { case p.events <- row: default: p.overflow = true }
}
func (p *evidencePeer) accounting() (int, bool, int) {
	p.mu.Lock(); defer p.mu.Unlock()
	return p.sends, p.overflow, len(p.events)
}
func checkEvidenceAccounting(branch string, sends int, overflow bool, remaining int) error {
	want := 0
	if branch == "send" { want = 1 } else if branch != "old-info" {
		return fmt.Errorf("unexpected native gossip branch %s", branch)
	}
	if sends != want || overflow || remaining != 0 {
		return fmt.Errorf("post-exit gossip accounting branch=%s sends=%d want=%d overflow=%t remaining=%d", branch, sends, want, overflow, remaining)
	}
	return nil
}
func (p *evidencePeer) Send(envelope p2p.Envelope) bool {
	p.mu.Lock(); p.sends++; p.mu.Unlock()
	row := observation{"branch": "send", "channel": envelope.ChannelID, "sourceAbsent": envelope.Src == nil,
		"messageType": fmt.Sprintf("%T", envelope.Message), "listProto": "", "evidenceCount": -1, "error": ""}
	if list, ok := envelope.Message.(*pb.EvidenceList); ok {
		raw, err := list.Marshal()
		row["listProto"], row["evidenceCount"] = hx(raw), len(list.Evidence)
		if err != nil { row["error"] = err.Error() }
	}
	p.publish(row)
	return true
}

type evidenceLogger struct { peer *evidencePeer }
var _ log.Logger = (*evidenceLogger)(nil)
func (l *evidenceLogger) Debug(string, ...any) {}
func (l *evidenceLogger) Warn(string, ...any) {}
func (l *evidenceLogger) With(...any) log.Logger { return l }
func (l *evidenceLogger) Error(message string, terms ...any) {
	l.peer.publish(observation{"branch": "unexpected-error-log", "message": message, "terms": fmt.Sprint(terms...)})
}
func (l *evidenceLogger) Info(message string, terms ...any) {
	if message != "Not sending peer old evidence" { return }
	rows := make([]observation, 0, len(terms)/2)
	for i := 0; i+1 < len(terms); i += 2 {
		key, ok := terms[i].(string)
		if !ok { key = "unexpected-nonstring-key" }
		value := terms[i+1]
		var encoded any
		switch typed := value.(type) {
		case int64: encoded = typed
		case time.Duration: encoded = int64(typed)
		case time.Time: encoded = observation{"seconds": typed.Unix(), "nanos": typed.Nanosecond()}
		case *evidencePeer: encoded = string(typed.ID())
		default: encoded = fmt.Sprint(value)
		}
		rows = append(rows, observation{"key": key, "type": fmt.Sprintf("%T", value), "value": encoded})
	}
	l.peer.publish(observation{"branch": "old-info", "message": message, "termCount": len(terms), "terms": rows})
}

func gossipProbe(t *testing.T, s publicSetup, ev *cmt.DuplicateVoteEvidence, height int64, used map[string]bool) (observation, observation) {
	t.Helper()
	b := openEvidenceBranch(t, s, fmt.Sprintf("gossip-%d", height), used)
	b.start(t)
	need(t, b.pool.AddEvidence(ev) == nil, "actual gossip AddEvidence")
	seed := b.view(t)
	need(t, b.pool.Size() == 1 && b.pool.EvidenceFront() != nil, "gossip requires actual pending clist item")
	peer := &evidencePeer{height: height, quit: make(chan struct{}), events: make(chan observation, 8)}
	reactor := evidence.NewReactor(b.pool)
	reactor.SetLogger(&evidenceLogger{peer: peer})
	started, stopped := false, false
	var after observation
	cleanup := func() error {
		if stopped { return nil }
		peer.stop()
		var stopErr error
		if started {
			stopErr = reactor.Stop()
		}
		var err error
		after, err = waitBroadcastExit()
		if err != nil { return err }
		b.broadcastMayLive = false
		stopped = true
		b.close(t)
		return stopErr
	}
	defer func() {
		if err := cleanup(); err != nil { t.Errorf("INCONCLUSIVE gossip cleanup: %v", err) }
	}()
	baseline, err := broadcastProfile()
	need(t, err == nil && baseline["count"] == 0, "complete zero-broadcast baseline: %v", err)
	need(t, reactor.Start() == nil, "start controlled evidence reactor")
	started = true
	b.broadcastMayLive = true
	reactor.AddPeer(peer)
	var branch observation
	select {
	case branch = <-peer.events:
	case <-time.After(2 * time.Second):
		t.Fatal("INCONCLUSIVE: no synchronized native gossip branch")
	}
	observed, err := broadcastProfile()
	need(t, err == nil && observed["count"] == 1, "complete positive broadcast profile before Quit: %v", err)
	// The first callback can happen before prepareEvidenceMessage returns.
	// Accounting is final only after that actual worker has terminated.
	need(t, cleanup() == nil, "gossip worker exit before database close")
	sends, overflow, remaining := peer.accounting()
	need(t, checkEvidenceAccounting(branch["branch"].(string), sends, overflow, remaining) == nil,
		"INCONCLUSIVE: ambiguous post-exit native gossip accounting")
	want := "send"
	if height == 1901 { want = "old-info" }
	if branch["branch"] != want {
		t.Errorf("evidence-gossip peer=%d expected=%s got=%v", height, want, branch["branch"])
	}
	var channel, old any
	count := 0
	if branch["branch"] == "send" {
		channel = branch["channel"]
		count, _ = branch["evidenceCount"].(int)
	} else if branch["branch"] == "old-info" {
		actual := make(observation)
		for _, term := range branch["terms"].([]observation) {
			key := term["key"].(string)
			_, duplicate := actual[key]
			need(t, !duplicate, "duplicate stock old-info term")
			actual[key] = term["value"]
		}
		stamp, ok := actual["lastBlockTime"].(observation)
		need(t, ok, "actual stock old-info block time")
		old = observation{"peerHeight": actual["peerHeight"], "evHeight": actual["evHeight"],
			"maxAgeNumBlocks": actual["maxAgeNumBlocks"], "lastSeconds": stamp["seconds"],
			"lastNanos": stamp["nanos"], "maxAgeNanos": actual["maxAgeDuration"]}
	}
	context := observation{"peerHeight": height, "branch": branch["branch"], "sendCount": sends,
		"channel": channel, "evidenceCount": count, "oldInfo": old,
		"exitMethod": "runtime-goroutine-profile", "broadcastAtStart": baseline["count"],
		"broadcastAtObservation": observed["count"], "broadcastAfterQuit": after["count"]}
	return context, observation{"seed": seed, "branch": branch, "baselineProfile": baseline,
		"observedProfile": observed, "afterProfile": after, "sendCount": sends, "eventOverflow": overflow,
		"accountingAfterExit": true, "unconsumedEvents": remaining,
		"peerQuit": !peer.IsRunning(), "reactorRunningAfterStop": reactor.IsRunning(), "databaseClosedAfterExit": b.closed}
}

// This focused real-goroutine regression is selected separately from the four
// protocol component cases. It models the old-Info callback/late-Send window;
// it does not earn Comet/source-control or protocol credit by itself.
func TestEvidencePostExitAccounting(t *testing.T) {
	peer := &evidencePeer{height: 1901, quit: make(chan struct{}), events: make(chan observation, 8)}
	release, done := make(chan struct{}), make(chan struct{})
	go func() {
		defer close(done)
		peer.publish(observation{"branch": "old-info"})
		<-release
		peer.Send(p2p.Envelope{ChannelID: evidence.EvidenceChannel, Message: &pb.EvidenceList{}})
	}()
	defer func() {
		select { case <-release: default: close(release) }
		select { case <-done: case <-time.After(2*time.Second): t.Error("INCONCLUSIVE: accounting regression worker exit") }
	}()
	select { case <-peer.events: case <-time.After(2*time.Second): t.Fatal("INCONCLUSIVE: accounting regression initial callback") }
	preSends, preOverflow, preRemaining := peer.accounting()
	need(t, checkEvidenceAccounting("old-info", preSends, preOverflow, preRemaining) == nil,
		"controlled pre-exit sample must expose the former blind window")
	close(release)
	select { case <-done: case <-time.After(2*time.Second): t.Fatal("INCONCLUSIVE: accounting regression positive join") }
	sends, overflow, remaining := peer.accounting()
	need(t, sends == 1 && !overflow && remaining == 1, "actual late Send after first callback")
	need(t, checkEvidenceAccounting("old-info", sends, overflow, remaining) != nil,
		"post-exit accounting must refuse the same iteration's late Send")
}

func gossipEvidence(t *testing.T, s publicSetup, ev *cmt.DuplicateVoteEvidence, used map[string]bool) (observation, observation) {
	contexts, details := make([]observation, 0, 2), make([]observation, 0, 2)
	for _, height := range []int64{1900, 1901} {
		context, detail := gossipProbe(t, s, ev, height, used)
		contexts, details = append(contexts, context), append(details, detail)
	}
	return observation{"case": "gossip", "evidenceHeight": ev.Height(), "historicalSeconds": ev.Time().Unix(),
		"holderHeight": 1000, "holderSeconds": historicalSeconds, "maxAgeNumBlocks": 900,
		"maxAgeSeconds": 3600, "pendingCount": 1, "frontPresent": true, "observations": contexts},
		observation{"probes": details}
}

func pendingPrefix(t *testing.T, s publicSetup, ev *cmt.DuplicateVoteEvidence, name string, used map[string]bool) (*evidenceBranch, []observation, []observation) {
	t.Helper()
	b := openEvidenceBranch(t, s, name, used)
	b.start(t)
	need(t, b.pool.AddEvidence(ev) == nil, "actual pending prefix AddEvidence")
	full, context := make([]observation, 0, 3), make([]observation, 0, 3)
	for i, row := range [][2]int64{{1000, 0}, {1900, 3600}, {1901, 3601}} {
		if i > 0 { b.update(t, evidenceState(t, s, row[0], row[1]), nil) }
		view := b.view(t)
		need(t, b.pool.Size() == 1 && b.pool.EvidenceFront() != nil, "actual pending prefix retained")
		full = append(full, view)
		context = append(context, observation{"height": row[0], "seconds": historicalSeconds+row[1], "pending": view["size"], "front": view["frontPresent"]})
	}
	return b, context, full
}

func pendingEvidence(t *testing.T, s publicSetup, ev *cmt.DuplicateVoteEvidence, used map[string]bool) (observation, observation) {
	continuing, cp, cf := pendingPrefix(t, s, ev, "continuing", used)
	defer continuing.close(t)
	restarted, rp, rf := pendingPrefix(t, s, ev, "restart", used)
	defer restarted.close(t)
	for i := range cf {
		left, right := make(observation), make(observation)
		for key, value := range cf[i] { if key != "store" { left[key] = value } }
		for key, value := range rf[i] { if key != "store" { right[key] = value } }
		a, err := json.Marshal(left); need(t, err == nil, "prefix marshal")
		b, err := json.Marshal(right); need(t, err == nil && bytes.Equal(a, b), "independent identical logical prefix")
	}
	beforeCheck := continuing.view(t)
	continuing.resetLookups()
	err := continuing.pool.CheckEvidence(cmt.EvidenceList{ev})
	need(t, err == nil, "continuing cached pending CheckEvidence")
	checkLookups := continuing.lookups()
	beforePrune := continuing.view(t)
	need(t, continuing.pool.Size() == 1, "continuing pending must remain before own pruning Update")
	continuing.update(t, evidenceState(t, s, 1902, 3602), nil)
	afterPrune := continuing.view(t)
	need(t, continuing.pool.Size() == 0 && continuing.pool.EvidenceFront() == nil, "actual continuing later pruning")
	beforeStartup := restarted.view(t)
	restarted.close(t)
	restarted.reopen(t)
	loaded, err := restarted.store.Load()
	need(t, err == nil && loaded.LastBlockHeight == 1901 && loaded.LastBlockTime == historicalTime().Add(3601*time.Second), "persisted latest state before startup")
	preNewPoolRows := evidenceRows(t, restarted.evidenceDB)
	restarted.start(t)
	afterStartup := restarted.view(t)
	need(t, restarted.pool.Size() == 0 && restarted.pool.EvidenceFront() == nil, "actual startup pending pruning")
	return observation{"case": "pending-restart", "evidenceHeight": ev.Height(), "historicalSeconds": historicalSeconds,
		"maxAgeNumBlocks": 900, "maxAgeSeconds": 3600,
		"branches": []observation{{"store": "continuing", "prefix": cp}, {"store": "restart", "prefix": rp}},
		"continuing": observation{"beforeCheck": beforeCheck["size"], "checkAccepted": true,
			"headerLookups": checkLookups["headers"], "validatorLookups": checkLookups["validators"],
			"beforePrune": beforePrune["size"], "pruneHeight": 1902, "pruneSeconds": historicalSeconds+3602,
			"afterPrune": afterPrune["size"], "frontAfterPrune": afterPrune["frontPresent"]},
		"restart": observation{"savedHeight": beforeStartup["height"], "savedSeconds": beforeStartup["seconds"],
			"loadedHeight": loaded.LastBlockHeight, "loadedSeconds": loaded.LastBlockTime.Unix(),
			"beforeStartup": beforeStartup["size"], "afterStartup": afterStartup["size"], "frontAfterStartup": afterStartup["frontPresent"]}},
		observation{"continuingPrefix": cf, "restartPrefix": rf, "beforeCheck": beforeCheck,
			"checkResult": evidenceResult(nil), "checkLookups": checkLookups, "beforePrune": beforePrune,
			"afterPrune": afterPrune, "beforeStartup": beforeStartup, "loadedStateProto": hx(loaded.Bytes()),
			"preNewPoolRows": preNewPoolRows, "afterStartup": afterStartup}
}

func markerBranch(t *testing.T, s publicSetup, ev *cmt.DuplicateVoteEvidence, marked bool, used map[string]bool) observation {
	t.Helper()
	name := "unmarked"
	if marked { name = "marked" }
	b := openEvidenceBranch(t, s, name, used)
	defer b.close(t)
	b.start(t)
	if marked { need(t, b.pool.AddEvidence(ev) == nil, "actual marker prefix AddEvidence") }
	before := b.view(t)
	committed := cmt.EvidenceList(nil)
	if marked { committed = cmt.EvidenceList{ev} }
	b.update(t, evidenceState(t, s, 1001, 1), committed)
	afterInstall := b.view(t)
	b.update(t, evidenceState(t, s, 1901, 3601), nil)
	beforePrune := b.view(t)
	pruneErr := b.store.PruneStates(1000, 1001, 1001)
	need(t, pruneErr == nil, "actual PruneStates1000,1001,1001")
	prunedRows := evidenceRows(t, b.stateDB)
	_, oldPresent := prunedRows[hx([]byte("validatorsKey:1000"))]
	_, nextPresent := prunedRows[hx([]byte("validatorsKey:1001"))]
	need(t, !oldPresent && nextPresent, "actual historical1000 deletion and retained1001 row")
	retained, retainedErr := b.store.LoadValidators(1001)
	need(t, retainedErr == nil, "actual retained validator1001 setup precheck")
	b.history.available = false
	b.close(t)
	b.reopen(t)
	loaded, err := b.store.Load()
	need(t, err == nil && loaded.LastBlockHeight == 1901, "actual reopened window state")
	b.start(t)
	beforeCheck := b.view(t)
	b.resetLookups() // Exclude all explicitly recorded setup/precheck calls.
	checkErr := b.pool.CheckEvidence(cmt.EvidenceList{ev})
	result, lookups, afterCheck := evidenceResult(checkErr), b.lookups(), b.view(t)
	key := append([]byte{0}, []byte(fmt.Sprintf("%016X/%X", ev.Height(), ev.Hash()))...)
	marker, err := b.evidenceDB.Get(key)
	need(t, err == nil, "read actual marker bytes")
	var payload gogotypes.Int64Value
	if marked {
		need(t, payload.Unmarshal(marker) == nil && payload.Value == 1000, "actual committed marker payload evidence height")
		invalid, ok := checkErr.(*cmt.ErrInvalidEvidence)
		need(t, ok && invalid.Reason.Error() == "evidence was already committed", "actual typed committed refusal")
	} else {
		need(t, len(marker) == 0 && checkErr != nil && checkErr.Error() == "don't have header #1000", "actual unmarked missing historical header")
	}
	return observation{"marked": marked, "before": before, "afterInstall": afterInstall, "beforePrune": beforePrune,
		"pruneArgs": []int64{1000, 1001, 1001}, "pruneResult": evidenceResult(pruneErr), "prunedStateRows": prunedRows,
		"setupPrecheck": observation{"api": "LoadValidators", "height": 1001, "validators": setView(t, retained)},
		"loadedStateProto": hx(loaded.Bytes()), "beforeCheck": beforeCheck, "checkResult": result,
		"checkLookups": lookups, "afterCheck": afterCheck, "markerKey": hx(key), "markerValue": hx(marker),
		"markerPayloadHeight": payload.Value, "historicalValidatorRowPresent": oldPresent, "historicalHeaderPresent": b.history.available}
}

func markerEvidence(t *testing.T, s publicSetup, ev *cmt.DuplicateVoteEvidence, used map[string]bool) (observation, observation) {
	marked := markerBranch(t, s, ev, true, used)
	unmarked := markerBranch(t, s, ev, false, used)
	resultContext := func(branch observation) observation {
		result := branch["checkResult"].(observation)
		lookups := branch["checkLookups"].(observation)
		return observation{"accepted": result["accepted"], "errorType": result["errorType"], "reason": result["reason"],
			"headerLookups": lookups["headers"], "validatorLookups": lookups["validators"], "pendingAfter": branch["afterCheck"].(observation)["size"]}
	}
	key := marked["markerKey"].(string)
	_, markerBefore := marked["before"].(observation)["evidenceRows"].(map[string]string)[key]
	_, markerAfter := marked["afterInstall"].(observation)["evidenceRows"].(map[string]string)[key]
	_, markerReopen := marked["beforeCheck"].(observation)["evidenceRows"].(map[string]string)[key]
	return observation{"case": "committed-window", "evidenceHeight": ev.Height(), "windowStart": 1001,
		"checkHeight": 1901, "installedAt": 1001, "payloadHeight": marked["markerPayloadHeight"],
		"pendingBeforeInstall": marked["before"].(observation)["size"], "pendingAfterInstall": marked["afterInstall"].(observation)["size"],
		"markerBeforeInstall": markerBefore, "markerAfterInstall": markerAfter, "markerAfterReopen": markerReopen,
		"reopenedPayloadHeight": marked["markerPayloadHeight"], "loadedHeight": marked["beforeCheck"].(observation)["height"],
		"loadedSeconds": marked["beforeCheck"].(observation)["seconds"],
		"historicalHeaderPresent": marked["historicalHeaderPresent"], "historicalValidatorRowPresent": marked["historicalValidatorRowPresent"],
		"marked": resultContext(marked), "unmarked": resultContext(unmarked)}, observation{"marked": marked, "unmarked": unmarked}
}

func TestEvidenceLifecycle(t *testing.T) {
	s := loadPublic(t)
	ev := makeEvidence(t, s, historicalTime())
	need(t, ev.Time() != ev.VoteA.Timestamp && ev.Height() == 1000, "historical time differs from signed vote time")
	used := make(map[string]bool)
	for _, name := range evidenceCases {
		t.Run(name, func(t *testing.T) {
			var context, details observation
			switch name {
			case "cold-grid": context, details = coldEvidence(t, s, ev, used)
			case "gossip": context, details = gossipEvidence(t, s, ev, used)
			case "pending-restart": context, details = pendingEvidence(t, s, ev, used)
			case "committed-window": context, details = markerEvidence(t, s, ev, used)
			default: t.Fatal("unknown evidence case")
			}
			receipt := observation{"schema": "etna-comet-evidence-1", "case": name, "publicInputSha256": s.digest,
				"evidence": evidenceView(t, s, ev), "context": context, "details": details}
			raw, err := json.Marshal(receipt)
			need(t, err == nil && !strings.Contains(string(raw), "\\u0000"), "encode full evidence receipt: %v", err)
			t.Logf("receipt=%s", raw)
		})
	}
}
