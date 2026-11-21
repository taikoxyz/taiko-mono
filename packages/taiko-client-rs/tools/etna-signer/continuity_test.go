package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"math/rand"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// reportJSON is a cometProcess as the supervisor channel encodes it.
func reportJSON(proc *cometProcess) any {
	if proc == nil {
		return nil
	}
	report := map[string]any{"pid": proc.PID, "start": nil, "store_instance": proc.StoreInstance}
	if proc.Start != "" {
		report["start"] = proc.Start
	}
	return report
}

// serveSupervisor serves the supervisor channel at a fresh socket to signer children of this
// test process, which runs their Comet listeners: every comet query is answered with report().
func serveSupervisor(t *testing.T, report func() *cometProcess) string {
	t.Helper()
	path := filepath.Join(shortTemp(t), "supervisor.sock")
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
				lines := bufio.NewScanner(c)
				for lines.Scan() {
					var request map[string]any
					if json.Unmarshal(lines.Bytes(), &request) != nil {
						return
					}
					reply := map[string]any{"schema": 1, "id": request["id"]}
					switch request["op"] {
					case "comet":
						reply["comet"] = reportJSON(report())
					case "stop":
						reply["stop"] = false
					case "wal":
						reply["binding"] = nil
					default:
						reply["error"] = "unknown op"
					}
					raw, _ := json.Marshal(reply)
					if _, e := c.Write(append(raw, '\n')); e != nil {
						return
					}
				}
			}()
		}
	}()
	return path
}

// reportsComet is a report function for the in-process listener of this test process on
// instance.
func reportsComet(instance string) func() *cometProcess {
	return func() *cometProcess {
		proc := testComet()
		proc.StoreInstance = instance
		return &proc
	}
}

// otherInstance is another home's store instance.
const otherInstance = "ffeeddccbbaa99887766554433221100"

// session is one signer-to-Comet connection's view through the gate: a fresh transport (a new
// cometConn) reporting proc, at the eligible height the trust peer reports.
type session struct {
	t      *testing.T
	g      *gate
	signer *guardedPV
}

// sessionFor admits nothing yet: it is a fresh transport to proc served by signer, with trust
// Ready at *eligible.
func sessionFor(t *testing.T, signer *guardedPV, proc cometProcess, eligible *atomic.Uint64) *session {
	t.Helper()
	path := control(t, func(map[string]any) any { return snapshotAt(true, eligible.Load()) })
	g := newGate(path, time.Second)
	id := "test:7"
	g.session.Store(&id)
	g.conn.Store(&cometConn{})
	g.supervisor = reporting(proc)
	return &session{t: t, g: g, signer: signer}
}

func (s *session) request(request pv.Message) ([]byte, *pv.RemoteSignerError) {
	s.t.Helper()
	response, _ := s.g.handle(s.signer, request, chain)
	return released(response)
}

// signs requires a signature.
func (s *session) signs(request pv.Message) []byte {
	s.t.Helper()
	signature, remote := s.request(request)
	if remote != nil || len(signature) < 65 {
		s.t.Fatalf("signing refused: %v", remote)
	}
	return signature
}

// refuses requires an explicit refusal mentioning reason.
func (s *session) refuses(request pv.Message, reason string) {
	s.t.Helper()
	signature, remote := s.request(request)
	if remote == nil || len(signature) != 0 || !strings.Contains(remote.Description, reason) {
		s.t.Fatalf("not refused with %q: %v", reason, remote)
	}
}

// at is request at height h, round r.
func at(request pv.Message, h int64, r int32) pv.Message {
	if vote := request.GetSignVoteRequest(); vote != nil {
		vote.Vote.Height, vote.Vote.Round = h, r
	} else {
		proposal := request.GetSignProposalRequest().Proposal
		proposal.Height, proposal.Round = h, r
	}
	return request
}

// persisted is the signer state on disk, as a restarted signer reads it.
func persisted(t *testing.T, key, state string) signerState {
	t.Helper()
	return openPV(t, key, state).state
}

// restarted is a new signer process on the persisted state: nothing admitted yet.
func restarted(t *testing.T, key, state string) *guardedPV {
	t.Helper()
	return openPV(t, key, state)
}

// otherProcess is a Comet process other than testComet on instance.
func otherProcess(instance string) cometProcess {
	proc := testComet()
	proc.PID++
	proc.StoreInstance = instance
	return proc
}

// RECOV-8.2-2: a never-used key/domain binds to the Comet store instance before its first
// signature, durably, and keeps no floor.
func TestNewKeyBindsWithoutFloor(t *testing.T) {
	_, key, state := filePV(t)
	// filePV's own session bound it; start again from the unbound zero state.
	if err := os.WriteFile(state, zeroStateBytes(chain), 0600); err != nil {
		t.Fatal(err)
	}
	signer := restarted(t, key, state)
	var eligible atomic.Uint64
	eligible.Store(3)
	s := sessionFor(t, signer, otherProcess(otherInstance), &eligible)
	var boundBeforeSigning bool
	signer.syncFile = func(f *os.File) error {
		if strings.Contains(f.Name(), ".tmp-") && !boundBeforeSigning {
			boundBeforeSigning = bytes.Contains(readFile(t, f.Name()), []byte(otherInstance)) && !bytes.Contains(readFile(t, f.Name()), []byte("signature"))
		}
		return f.Sync()
	}
	s.signs(at(voteRequest(tm.PrevoteType, 0, false), 3, 0))
	if !boundBeforeSigning {
		t.Fatal("the binding was not durable before the first signature")
	}
	if got := persisted(t, key, state); got.StoreInstance != otherInstance || got.Floor != 0 || got.Height != 3 {
		t.Fatalf("new key: instance %q floor %d height %d", got.StoreInstance, got.Floor, got.Height)
	}
}

// RECOV-8.2-2 (vector 2.g, ACCEPTANCE §2.4): a store rebuilt after a signature at H has a fresh
// instance ID. The signer persists a floor of H + 1 before admitting the replacement session, and
// then refuses every proposal and vote at H, nil votes, later rounds and identical retries
// included, with the HRS unchanged; H + 1 signs once the app makes it eligible.
func TestRebuildAfterSignatureFencesThroughH(t *testing.T) {
	signer, key, state := filePV(t)
	var eligible atomic.Uint64
	eligible.Store(1)
	first := sessionFor(t, signer, testComet(), &eligible)
	first.signs(voteRequest(tm.PrevoteType, 0, false))
	hrs := persisted(t, key, state)

	for _, rebuild := range []struct {
		name string
		proc cometProcess
	}{{"changed-instance", otherProcess(otherInstance)}, {"same-process-other-instance", func() cometProcess { p := testComet(); p.StoreInstance = otherInstance; return p }()}} {
		t.Run(rebuild.name, func(t *testing.T) {
			if err := os.WriteFile(state, hrs.encode(), 0600); err != nil {
				t.Fatal(err)
			}
			signer := restarted(t, key, state)
			s := sessionFor(t, signer, rebuild.proc, &eligible)
			var floorDurable bool
			signer.syncFile = func(f *os.File) error {
				if strings.Contains(f.Name(), ".tmp-") {
					floorDurable = bytes.Contains(readFile(t, f.Name()), []byte(`"floor": "2"`))
				}
				return f.Sync()
			}
			for _, request := range []pv.Message{
				voteRequest(tm.PrevoteType, 0, false), // the identical retry
				voteRequest(tm.PrevoteType, 0, true),
				voteRequest(tm.PrecommitType, 0, false),
				voteRequest(tm.PrecommitType, 0, true),
				voteRequest(tm.PrevoteType, 3, true),
				voteRequest(tm.PrecommitType, 3, true),
				proposalRequest(),
				at(proposalRequest(), 1, 4),
			} {
				s.refuses(request, "durable floor")
			}
			if !floorDurable {
				t.Fatal("the floor was not made durable before the session was admitted")
			}
			got := persisted(t, key, state)
			if got.Floor != 2 || got.StoreInstance != rebuild.proc.StoreInstance || got.Height != 1 || got.Step != stepPrevote || !bytes.Equal(got.Signature, hrs.Signature) {
				t.Fatalf("after the rebuild: floor %d instance %q HRS %d/%d", got.Floor, got.StoreInstance, got.Height, got.Step)
			}
			// H + 1 signs once the app has committed H.
			eligible.Store(2)
			defer eligible.Store(1)
			s.signs(at(voteRequest(tm.PrevoteType, 0, true), 2, 0))
		})
	}
}

// RECOV-8.2-2: an ID copied with an older database cannot establish continuity, and no restart
// with an intact binding can either until same-height replay is established: a new Comet process
// on the bound instance takes the floor too.
func TestCopiedInstanceIDAndRestartDoNotRestoreContinuity(t *testing.T) {
	signer, key, state := filePV(t)
	var eligible atomic.Uint64
	eligible.Store(1)
	sessionFor(t, signer, testComet(), &eligible).signs(voteRequest(tm.PrecommitType, 0, false))
	for _, restart := range []struct {
		name string
		proc cometProcess
	}{
		// The supervisor reports the bound ID again, as an older home copied with its ID would.
		{"copied-id-new-process", otherProcess(testInstance)},
		// A new signer process facing the same Comet process.
		{"signer-restart-same-process", testComet()},
	} {
		t.Run(restart.name, func(t *testing.T) {
			s := sessionFor(t, restarted(t, key, state), restart.proc, &eligible)
			s.refuses(voteRequest(tm.PrecommitType, 0, false), "durable floor")
			if got := persisted(t, key, state); got.Floor != 2 || got.StoreInstance != testInstance {
				t.Fatalf("floor %d instance %q", got.Floor, got.StoreInstance)
			}
		})
	}
}

// SYNC-9-4: a reconnect to the same live Comet process repeats the binding check with the
// durable HRS and floor intact, and fences nothing: the identical retry returns the saved
// signature. Another process in the same signer's lifetime is fenced.
func TestReconnectToTheSameProcessKeepsContinuity(t *testing.T) {
	signer, key, state := filePV(t)
	var eligible atomic.Uint64
	eligible.Store(1)
	signature := sessionFor(t, signer, testComet(), &eligible).signs(voteRequest(tm.PrevoteType, 0, false))
	again := sessionFor(t, signer, testComet(), &eligible)
	if retry := again.signs(voteRequest(tm.PrevoteType, 0, false)); !bytes.Equal(retry, signature) {
		t.Fatal("the reconnected retry changed the signature")
	}
	if got := persisted(t, key, state); got.Floor != 0 {
		t.Fatalf("a reconnect to the same process raised the floor to %d", got.Floor)
	}
	sessionFor(t, signer, otherProcess(testInstance), &eligible).refuses(voteRequest(tm.PrecommitType, 0, false), "durable floor")
}

// RECOV-8.2-2: rebinding never lowers the floor, and the old instance stays fenced after a
// failover: binding back to it is another change, and the floor only rises.
func TestFloorNeverLowersAndFailoverFencesTheOldInstance(t *testing.T) {
	signer, key, state := filePV(t)
	var eligible atomic.Uint64
	eligible.Store(1)
	sessionFor(t, signer, testComet(), &eligible).signs(voteRequest(tm.PrevoteType, 0, false))
	// Failover to a standby home: floor 2, bound to the standby's instance.
	standby := otherProcess(otherInstance)
	s := sessionFor(t, restarted(t, key, state), standby, &eligible)
	s.refuses(voteRequest(tm.PrecommitType, 0, false), "durable floor")
	eligible.Store(2)
	s.signs(at(voteRequest(tm.PrevoteType, 0, false), 2, 0))
	if got := persisted(t, key, state); got.Floor != 2 || got.Height != 2 {
		t.Fatalf("standby: floor %d height %d", got.Floor, got.Height)
	}
	// The old instance comes back: it is fenced through the standby's last signature.
	old := sessionFor(t, restarted(t, key, state), testComet(), &eligible)
	old.refuses(at(voteRequest(tm.PrecommitType, 0, false), 2, 0), "durable floor")
	if got := persisted(t, key, state); got.Floor != 3 || got.StoreInstance != testInstance {
		t.Fatalf("old instance: floor %d instance %q", got.Floor, got.StoreInstance)
	}
	// A later rebinding at a lower last-signed height never lowers it (state edited back to H1
	// with floor 3 stays at 3).
	lower := persisted(t, key, state)
	if err := os.WriteFile(state, lower.encode(), 0600); err != nil {
		t.Fatal(err)
	}
	p := restarted(t, key, state)
	if err := p.admit(cometReport{Process: otherProcess(otherInstance)}); err != nil {
		t.Fatal(err)
	}
	if got := persisted(t, key, state); got.Floor != 3 {
		t.Fatalf("rebinding lowered the floor to %d", got.Floor)
	}
}

// The supervisor's report must name this transport's Comet: on a Unix transport its PID and
// start time; a missing report or channel is pending and refused once the hold runs out; a
// report that changes during one connection is refused. Nothing reaches the HRS.
func TestSessionAdmissionVerifiesTheSupervisorReport(t *testing.T) {
	signer, key, state := filePV(t)
	before := readFile(t, state)
	var eligible atomic.Uint64
	eligible.Store(1)
	own := testComet()
	for _, c := range []struct {
		name     string
		conn     *cometConn
		reporter supervisorClient
		reason   string
	}{
		{"unix-other-pid", &cometConn{unix: true, pid: own.PID}, reporting(otherProcess(testInstance)), "not the supervisor's Comet"},
		{"unix-other-start", &cometConn{unix: true, pid: own.PID}, reporting(cometProcess{PID: own.PID, Start: "1", StoreInstance: testInstance}), "started at"},
		{"unix-unknown-peer", &cometConn{unix: true}, reporting(own), "peer credentials are unknown"},
		{"no-comet", &cometConn{}, staticReporter{}, "runs no Comet"},
		{"channel-down", &cometConn{}, staticReporter{err: errSupervisorUnavailable}, "supervisor channel unavailable"},
		{"invalid-instance", &cometConn{}, reporting(cometProcess{PID: own.PID, StoreInstance: "nothex"}), "invalid Comet process report"},
	} {
		t.Run(c.name, func(t *testing.T) {
			s := sessionFor(t, signer, own, &eligible)
			s.g.conn.Store(c.conn)
			s.g.supervisor = c.reporter
			s.refuses(voteRequest(tm.PrevoteType, 0, false), c.reason)
			if !bytes.Equal(before, readFile(t, state)) {
				t.Fatal("a refused admission changed the signer state")
			}
		})
	}
	// The verified Unix peer signs.
	s := sessionFor(t, signer, own, &eligible)
	s.g.conn.Store(&cometConn{unix: true, pid: own.PID})
	s.signs(voteRequest(tm.PrevoteType, 0, false))
	// A report that changes during the connection is refused.
	s.g.supervisor = reporting(func() cometProcess { p := own; p.StoreInstance = otherInstance; return p }())
	s.refuses(voteRequest(tm.PrecommitType, 0, false), "changed during this transport connection")
	_ = key
}

// A failed fsync while persisting a floor or a binding is uncertain state (RECOV-8.2-3): the
// session is not admitted, the fence is written and the signer stops.
func TestFloorPersistenceFailureIsUncertain(t *testing.T) {
	signer, key, state := filePV(t)
	var eligible atomic.Uint64
	eligible.Store(1)
	sessionFor(t, signer, testComet(), &eligible).signs(voteRequest(tm.PrevoteType, 0, false))
	restart := restarted(t, key, state)
	restart.syncFile = func(f *os.File) error {
		if strings.Contains(f.Name(), ".tmp-") {
			return syscall.EIO
		}
		return f.Sync()
	}
	s := sessionFor(t, restart, otherProcess(otherInstance), &eligible)
	response, err := s.g.handle(restart, voteRequest(tm.PrecommitType, 0, false), chain)
	if signature, remote := released(response); !errors.Is(err, errSigningStateUnsafe) || remote == nil || len(signature) != 0 {
		t.Fatalf("failed floor fsync admitted the session: %v", err)
	}
	select {
	case <-s.g.terminal:
	default:
		t.Fatal("failed floor fsync did not stop the signer")
	}
	if record := readFence(t, state); !strings.Contains(record.Error, "input/output error") {
		t.Fatalf("fence %+v", record)
	}
	if got := persisted(t, key, state); got.Floor != 0 {
		t.Fatalf("the failed write reached the state: floor %d", got.Floor)
	}
}

// The supervisor channel authenticates its peer: only the PID this signer was told (its parent
// in production) may serve it, and replies must carry the schema and the request's id.
func TestSupervisorChannelAuthenticatesItsPeer(t *testing.T) {
	path := serveSupervisor(t, reportsComet(testInstance))
	deadline := time.Now().Add(time.Second)
	if report, err := newSupervisorChannel(path, os.Getpid()).comet(deadline); err != nil || report == nil || report.Process != testComet() || report.Replay != nil {
		t.Fatalf("own peer: %v %v", report, err)
	}
	if _, err := newSupervisorChannel(path, os.Getpid()+1).comet(deadline); !errors.Is(err, errSupervisorUnavailable) || !strings.Contains(err.Error(), "peer PID") {
		t.Fatalf("another peer PID was accepted: %v", err)
	}
	for _, c := range []struct{ name, reply string }{
		{"other-schema", `{"schema":2,"id":1,"comet":null}`},
		{"other-id", `{"schema":1,"id":9,"comet":null}`},
		{"duplicate-key", `{"schema":1,"id":1,"comet":null,"comet":null}`},
		{"error", `{"schema":1,"id":1,"error":"no"}`},
		{"no-comet-field", `{"schema":1,"id":1}`},
		{"bad-instance", `{"schema":1,"id":1,"comet":{"pid":1,"start":null,"store_instance":"x"}}`},
		{"bad-start", `{"schema":1,"id":1,"comet":{"pid":1,"start":"x","store_instance":"` + testInstance + `"}}`},
		{"oversize", `{"schema":1,"id":1,"pad":"` + strings.Repeat("x", maxSupervisorFrame) + `"}`},
	} {
		t.Run(c.name, func(t *testing.T) {
			socket := filepath.Join(shortTemp(t), "s.sock")
			l, err := net.Listen("unix", socket)
			if err != nil {
				t.Fatal(err)
			}
			defer l.Close()
			go func() {
				conn, err := l.Accept()
				if err != nil {
					return
				}
				defer conn.Close()
				bufio.NewReader(conn).ReadBytes('\n')
				conn.Write([]byte(c.reply + "\n"))
				time.Sleep(time.Second)
			}()
			if proc, err := newSupervisorChannel(socket, os.Getpid()).comet(time.Now().Add(500 * time.Millisecond)); err == nil {
				t.Fatalf("accepted %s: %v", c.reply, proc)
			}
		})
	}
}

// randomRequest is a vote or proposal at heights 1..3 and rounds 0..2, for a nil block or one of
// two blocks, at one of two timestamps.
func randomRequest(random *rand.Rand) pv.Message {
	h, r := int64(1+random.Intn(3)), int32(random.Intn(3))
	block := random.Intn(3)
	stamp := time.Unix(100+int64(random.Intn(2)), 0)
	var request pv.Message
	switch random.Intn(3) {
	case 0:
		request = voteRequest(tm.PrevoteType, r, block == 0)
	case 1:
		request = voteRequest(tm.PrecommitType, r, block == 0)
	default:
		request = proposalRequest()
		proposal := request.GetSignProposalRequest().Proposal
		proposal.Round, proposal.PolRound = r, int32(random.Intn(int(r)+1))-1
		if block != 0 {
			proposal.BlockID = tm.BlockID{Hash: bytes.Repeat([]byte{1}, 32), PartSetHeader: tm.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{2}, 32)}}
		}
	}
	request = at(request, h, r)
	if vote := request.GetSignVoteRequest(); vote != nil {
		vote.Vote.Timestamp = stamp
		if block == 2 {
			vote.Vote.BlockID.Hash = bytes.Repeat([]byte{9}, 32)
		}
	} else {
		proposal := request.GetSignProposalRequest().Proposal
		proposal.Timestamp = stamp
		if block == 2 {
			proposal.BlockID.Hash = bytes.Repeat([]byte{9}, 32)
		}
	}
	return request
}

// The guarded signer applies stock FilePV's HRS rules exactly: the same request sequence through
// stock FilePV and through it gives the same answers, signatures, extension signatures and
// timestamps, and leaves the same HRS.
func TestGuardedSignerMatchesStockFilePV(t *testing.T) {
	random := rand.New(rand.NewSource(7))
	var signed, refused, retried int
	for trial := range 40 {
		key := secp256k1eth.GenPrivKey()
		stock := privval.NewFilePV(key, filepath.Join(t.TempDir(), "k.json"), filepath.Join(t.TempDir(), "s.json"))
		state := filepath.Join(t.TempDir(), chain+".json")
		if err := os.WriteFile(state, zeroStateBytes(chain), 0600); err != nil {
			t.Fatal(err)
		}
		guarded := newGuardedPV(key, chain, state, zeroState(chain))
		if err := guarded.admit(cometReport{Process: testComet()}); err != nil {
			t.Fatal(err)
		}
		for step := range 30 {
			request := randomRequest(random)
			var errOurs, errTheirs error
			var same bool
			if vote := request.GetSignVoteRequest(); vote != nil {
				ours, theirs := *vote.Vote, *vote.Vote
				errOurs, errTheirs = guarded.SignVote(chain, &ours), stock.SignVote(chain, &theirs)
				same = bytes.Equal(ours.Signature, theirs.Signature) && bytes.Equal(ours.ExtensionSignature, theirs.ExtensionSignature) && ours.Timestamp.Equal(theirs.Timestamp)
				if errOurs == nil && !ours.Timestamp.Equal(vote.Vote.Timestamp) {
					retried++
				}
			} else {
				proposal := request.GetSignProposalRequest().Proposal
				ours, theirs := *proposal, *proposal
				errOurs, errTheirs = guarded.SignProposal(chain, &ours), stock.SignProposal(chain, &theirs)
				same = bytes.Equal(ours.Signature, theirs.Signature) && ours.Timestamp.Equal(theirs.Timestamp)
			}
			// A refusal carries no vote over the wire, so only its message is compared.
			if (errOurs == nil) != (errTheirs == nil) || (errOurs == nil && !same) || (errOurs != nil && errOurs.Error() != errTheirs.Error()) {
				t.Fatalf("trial %d step %d: guarded %v, stock %v, same answer %v", trial, step, errOurs, errTheirs, same)
			}
			if errOurs == nil {
				signed++
			} else {
				refused++
			}
			lss := stock.LastSignState
			if g := guarded.state; g.Height != lss.Height || g.Round != lss.Round || g.Step != lss.Step || !bytes.Equal(g.SignBytes, lss.SignBytes) || !bytes.Equal(g.Signature, lss.Signature) {
				t.Fatalf("trial %d step %d: HRS diverged", trial, step)
			}
		}
		on, err := os.ReadFile(state)
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(on, guarded.state.encode()) {
			t.Fatalf("trial %d: the state on disk is not the signer's", trial)
		}
	}
	if signed == 0 || refused == 0 || retried == 0 {
		t.Fatalf("the sequences did not cover signing (%d), refusal (%d) and timestamp retries (%d)", signed, refused, retried)
	}
}

// testBinding is a live replay binding for a signature at height 1: the generation's initial
// height, so the marker is #ENDHEIGHT 0 and the predecessor is genesis.
func testBinding(length int64) replayBinding {
	return replayBinding{Marker: 0, Length: length, Digest: bytes.Repeat([]byte{byte(length)}, 32)}
}

// replayRig is a signer restarted on a new Comet process of the bound home after it signed
// saved, whose live binding the supervisor reported, with a supervisor whose startup check
// verified that binding and pinned a longer startup prefix, and whose observer reports an open
// replay attempt of height 1.
type replayRig struct {
	t                *testing.T
	key, state       string
	saved            []byte
	signer           *guardedPV
	s                *session
	reporter         *staticReporter
	bound, startup   replayBinding
	eligible         atomic.Uint64
	savedTimestamped time.Time
}

func newReplayRig(t *testing.T, saved pv.Message) *replayRig {
	t.Helper()
	signer, key, state := filePV(t)
	r := &replayRig{t: t, key: key, state: state, bound: testBinding(40), startup: testBinding(90)}
	r.eligible.Store(1)
	first := sessionFor(t, signer, testComet(), &r.eligible)
	live := reporting(testComet())
	live.binding = &r.bound
	first.g.supervisor = live
	r.saved = first.signs(saved)
	if got := persisted(t, key, state); got.Replay == nil || !got.Replay.equal(r.bound) {
		t.Fatalf("the live signature did not record its binding: %+v", got.Replay)
	}
	r.signer = restarted(t, key, state)
	r.reporter = &staticReporter{report: &cometReport{Process: otherProcess(testInstance), Replay: &replayReport{Height: 1, Binding: r.bound, Startup: r.startup}},
		observation: &replayObservation{Attempt: 1, Open: true, Height: 1}, binding: &replayBinding{Marker: 0, Length: 500, Digest: bytes.Repeat([]byte{5}, 32)}}
	r.s = sessionFor(t, r.signer, otherProcess(testInstance), &r.eligible)
	r.s.g.supervisor = r.reporter
	return r
}

// observe changes what the observer reports from now on.
func (r *replayRig) observe(o replayObservation) {
	r.reporter.observation = &o
	r.s.g.supervisor = *r.reporter
}

func (r *replayRig) floor() int64 { return persisted(r.t, r.key, r.state).Floor }

// vote is a vote at height 1 in round, for block (0 nil) at second stamp.
func vote(typ tm.SignedMsgType, round int32, block byte, stamp int64) pv.Message {
	request := voteRequest(typ, round, block == 0)
	if block != 0 {
		request.GetSignVoteRequest().Vote.BlockID.Hash = bytes.Repeat([]byte{block}, 32)
	}
	request.GetSignVoteRequest().Vote.Timestamp = time.Unix(stamp, 0)
	return request
}

// RECOV-8.2-2 vectors 2.e/2.k and SYNC-9-12 12.a, SYNC-9-13 13.e (signer response loss): the
// saved prevote's reply was lost; the restarted pair replays from the verified predecessor, the
// request repeating the saved HRS with only another timestamp gets the saved signature and
// timestamp and confirms the decision, and the first precommit is signed during that replay and
// persisted with the pinned startup prefix. After the replay ends the session continues live.
func TestReplayConfirmsTheSavedVoteAndSignsHigherHRS(t *testing.T) {
	r := newReplayRig(t, vote(tm.PrevoteType, 0, 1, 100))
	if r.floor() != 0 {
		t.Fatal("an eligible replay was fenced")
	}
	retry := vote(tm.PrevoteType, 0, 1, 200)
	signature, remote := r.s.request(retry)
	if remote != nil || !bytes.Equal(signature, r.saved) {
		t.Fatalf("the saved prevote was not returned: %v", remote)
	}
	response, _ := r.s.g.handle(r.signer, vote(tm.PrevoteType, 0, 1, 300), chain)
	if got := response.GetSignedVoteResponse().Vote.Timestamp; !got.Equal(time.Unix(100, 0)) {
		t.Fatalf("the timestamp-only retry got %v, not the saved timestamp", got)
	}
	r.s.signs(vote(tm.PrecommitType, 0, 1, 300))
	if got := persisted(t, r.key, r.state); got.Step != stepPrecommit || got.Replay == nil || !got.Replay.equal(r.startup) || got.Floor != 0 {
		t.Fatalf("the replayed precommit was not bound to the startup prefix: %+v floor %d", got.Replay, got.Floor)
	}
	// Replay: Done; the confirmed session goes on live, with live bindings.
	r.observe(replayObservation{Attempt: 1, Height: 1})
	r.s.signs(vote(tm.PrevoteType, 1, 1, 400))
	if got := persisted(t, r.key, r.state); got.Round != 1 || got.Replay == nil || got.Replay.Length != 500 {
		t.Fatalf("the live vote after replay: %+v", got.Replay)
	}
}

// Fresh signing at the replayed height stays closed until the saved decision is confirmed, and
// an unconfirmed request outside an authenticated attempt (stock fell through on a replay error,
// vector 2.j; a skipped replay) raises the durable floor, after which nothing at H signs.
func TestUnconfirmedReplayFencesOutsideTheAttempt(t *testing.T) {
	for _, c := range []struct {
		name string
		obs  replayObservation
	}{
		{"replay-error", replayObservation{Attempt: 1, Height: 1, Tainted: true}},
		{"replay-ended-unconfirmed", replayObservation{Attempt: 1, Height: 1}},
		{"no-replay-attempt", replayObservation{}},
		{"attempt-for-another-height", replayObservation{Attempt: 1, Open: true, Height: 2}},
	} {
		t.Run(c.name, func(t *testing.T) {
			r := newReplayRig(t, vote(tm.PrevoteType, 0, 1, 100))
			r.s.refuses(vote(tm.PrecommitType, 0, 1, 100), "stays closed until replay confirms")
			if r.floor() != 0 {
				t.Fatal("a closed request inside the attempt fenced the height")
			}
			r.observe(c.obs)
			r.s.refuses(vote(tm.PrevoteType, 0, 1, 100), "durable floor")
			if r.floor() != 2 {
				t.Fatalf("floor %d after an unconfirmed replay", r.floor())
			}
			r.observe(replayObservation{Attempt: 1, Open: true, Height: 1})
			r.s.refuses(vote(tm.PrevoteType, 0, 1, 100), "durable floor")
			r.s.refuses(vote(tm.PrecommitType, 0, 1, 100), "durable floor")
		})
	}
}

// Vector 2.m/2.n: after a proposal, a request at that proposal HRS marks progress to the propose
// step only. The identical proposal gets the saved signature, a rebuilt one with another BlockID
// or POLRound is refused, and no fresh vote at H is signed without independent confirmation,
// which this signer does not implement: when the attempt ends, H is fenced.
func TestProposalReplayMarksProgressOnly(t *testing.T) {
	proposal := func(block byte, pol int32) pv.Message {
		request := at(proposalRequest(), 1, 1)
		p := request.GetSignProposalRequest().Proposal
		p.PolRound = pol
		p.BlockID = tm.BlockID{Hash: bytes.Repeat([]byte{block}, 32), PartSetHeader: tm.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{block}, 32)}}
		return request
	}
	r := newReplayRig(t, proposal(1, -1))
	if again := r.s.signs(proposal(1, -1)); !bytes.Equal(again, r.saved) {
		t.Fatal("the identical proposal did not return the saved signature")
	}
	r.s.refuses(proposal(2, -1), "conflicting data")
	r.s.refuses(proposal(1, 0), "conflicting data")
	prevote := vote(tm.PrevoteType, 1, 1, 100)
	r.s.refuses(prevote, "stays closed until replay confirms")
	r.observe(replayObservation{Attempt: 1, Height: 1})
	r.s.refuses(prevote, "durable floor")
	if r.floor() != 2 {
		t.Fatalf("floor %d", r.floor())
	}
}

// Vectors 2.q/2.r: an upgraded app accepts a proposal it rejected, so replay asks for a block
// prevote although the saved last signature is the nil precommit (2.q): the earlier HRS is
// refused, the saved precommit's timestamp-only retry confirms, and higher HRS are admitted
// after it. With only the nil prevote saved (2.r), the conflicting block prevote is refused and
// fresh signing at H stays closed.
func TestUpgradedAppReplayAtTheSavedPrecommit(t *testing.T) {
	t.Run("2.q", func(t *testing.T) {
		r := newReplayRig(t, vote(tm.PrecommitType, 0, 0, 100))
		r.s.refuses(vote(tm.PrevoteType, 0, 1, 200), "step regression")
		r.s.refuses(vote(tm.PrecommitType, 1, 0, 200), "stays closed until replay confirms")
		if again := r.s.signs(vote(tm.PrecommitType, 0, 0, 200)); !bytes.Equal(again, r.saved) {
			t.Fatal("the saved precommit was not returned")
		}
		r.s.signs(vote(tm.PrevoteType, 1, 1, 200))
	})
	t.Run("2.r", func(t *testing.T) {
		r := newReplayRig(t, vote(tm.PrevoteType, 0, 0, 100))
		r.s.refuses(vote(tm.PrevoteType, 0, 1, 200), "conflicting data")
		r.s.refuses(vote(tm.PrecommitType, 0, 1, 200), "stays closed until replay confirms")
		r.observe(replayObservation{Attempt: 1, Height: 1})
		r.s.refuses(vote(tm.PrecommitType, 0, 1, 200), "durable floor")
	})
}

// Replay admission is cleared by a repair, a replay error, another attempt and a disconnect
// (RECOV-8.2-2): a new attempt must confirm again against the latest durable HRS.
func TestReplayAdmissionIsClearedAndMustConfirmAgain(t *testing.T) {
	t.Run("disconnect", func(t *testing.T) {
		r := newReplayRig(t, vote(tm.PrevoteType, 0, 1, 100))
		r.s.signs(vote(tm.PrevoteType, 0, 1, 100))
		// A reconnect to the same process clears the confirmation.
		again := sessionFor(t, r.signer, otherProcess(testInstance), &r.eligible)
		again.g.supervisor = *r.reporter
		again.refuses(vote(tm.PrecommitType, 0, 1, 100), "stays closed until replay confirms")
		again.signs(vote(tm.PrevoteType, 0, 1, 100))
		again.signs(vote(tm.PrecommitType, 0, 1, 100))
	})
	t.Run("another-attempt", func(t *testing.T) {
		r := newReplayRig(t, vote(tm.PrevoteType, 0, 1, 100))
		r.s.signs(vote(tm.PrevoteType, 0, 1, 100))
		r.observe(replayObservation{Attempt: 2, Open: true, Height: 1})
		r.s.refuses(vote(tm.PrecommitType, 0, 1, 100), "stays closed until replay confirms")
	})
	t.Run("repair", func(t *testing.T) {
		r := newReplayRig(t, vote(tm.PrevoteType, 0, 1, 100))
		r.s.signs(vote(tm.PrevoteType, 0, 1, 100))
		r.observe(replayObservation{Attempt: 1, Height: 1, Tainted: true, Repaired: true})
		r.s.refuses(vote(tm.PrecommitType, 0, 1, 100), "until the supervisor restarts the pair")
		if r.floor() != 0 {
			t.Fatal("a stock tail repair fenced the height")
		}
	})
}

// Vector 2.l: a torn tail after all bound input keeps this start closed at H without a floor,
// while stock repairs it; a transient refusal of a request at H (trust, a timeout) does the same,
// as the supervisor's guarded restart retries it (SYNC-9-12).
func TestRecoverableInterruptionsKeepHClosedWithoutAFloor(t *testing.T) {
	t.Run("torn-tail", func(t *testing.T) {
		r := newReplayRig(t, vote(tm.PrevoteType, 0, 1, 100))
		r.reporter.report.Replay.Repair = true
		again := restarted(t, r.key, r.state)
		r.s = sessionFor(t, again, otherProcess(testInstance), &r.eligible)
		r.s.g.supervisor = *r.reporter
		r.signer = again
		r.s.refuses(vote(tm.PrevoteType, 0, 1, 100), "until the supervisor restarts the pair")
		r.observe(replayObservation{Attempt: 1, Height: 1, Tainted: true, Repaired: true})
		r.s.refuses(vote(tm.PrecommitType, 0, 1, 100), "until the supervisor restarts the pair")
		if r.floor() != 0 {
			t.Fatal("a torn tail fenced the height")
		}
	})
	t.Run("trust-refusal", func(t *testing.T) {
		r := newReplayRig(t, vote(tm.PrevoteType, 0, 1, 100))
		closed := control(t, func(map[string]any) any { return snapshot(false) })
		open := r.s.g.path
		r.s.g.path = closed
		r.s.refuses(vote(tm.PrevoteType, 0, 1, 100), "checkpoint trust")
		r.s.g.path = open
		r.observe(replayObservation{Attempt: 1, Height: 1})
		r.s.refuses(vote(tm.PrecommitType, 0, 1, 100), "until the supervisor restarts the pair")
		if r.floor() != 0 {
			t.Fatal("a trust refusal during replay fenced the height")
		}
	})
}

// The startup check must verify exactly the saved binding: another binding, height or a startup
// prefix that does not extend it opens no replay session, and the restart is fenced as without
// one; an unavailable observer refuses the request at H without touching the state.
func TestReplaySessionNeedsTheSavedBinding(t *testing.T) {
	for _, c := range []struct {
		name   string
		change func(*replayReport)
	}{
		{"other-length", func(r *replayReport) { r.Binding.Length++ }},
		{"other-digest", func(r *replayReport) { r.Binding.Digest = bytes.Repeat([]byte{9}, 32) }},
		{"other-height", func(r *replayReport) { r.Height = 2 }},
		{"short-startup", func(r *replayReport) { r.Startup.Length = r.Binding.Length - 1 }},
		{"other-startup-marker", func(r *replayReport) { r.Startup.Marker = 3 }},
	} {
		t.Run(c.name, func(t *testing.T) {
			r := newReplayRig(t, vote(tm.PrevoteType, 0, 1, 100))
			c.change(r.reporter.report.Replay)
			r.s.g.supervisor = *r.reporter
			r.s.refuses(vote(tm.PrevoteType, 0, 1, 100), "durable floor")
		})
	}
	t.Run("observer-unavailable", func(t *testing.T) {
		r := newReplayRig(t, vote(tm.PrevoteType, 0, 1, 100))
		r.reporter.observation = nil
		r.s.g.supervisor = *r.reporter
		before := readFile(t, r.state)
		r.s.refuses(vote(tm.PrevoteType, 0, 1, 100), "supervisor channel unavailable")
		if !bytes.Equal(before, readFile(t, r.state)) {
			t.Fatal("an unavailable observer changed the state")
		}
	})
}

// armedSession is a session whose supervisor has armed the stop on a precommit, records the
// signer's stop reports and computes live replay bindings, so the precommits it signs can be
// confirmed by same-height replay.
func armedSession(t *testing.T, signer *guardedPV, eligible *atomic.Uint64) (*session, *stopLog) {
	t.Helper()
	s := sessionFor(t, signer, testComet(), eligible)
	stops := &stopLog{}
	reporter := bound(testComet())
	reporter.armed, reporter.stops = true, stops
	s.g.supervisor = reporter
	return s, stops
}

// bound is a supervisor that reports proc and the live replay binding testBinding(40).
func bound(proc cometProcess) staticReporter {
	reporter := reporting(proc)
	binding := testBinding(40)
	reporter.binding = &binding
	return reporter
}

// An armed stop closes only after a precommit that same-height replay can confirm after the
// upgrade (RECOV-8.2-2): a precommit signed while the supervisor cannot compute its replay
// binding, as the last signature at arming or a fresh one, leaves the gate open, and the next
// precommit that carries a binding closes it.
func TestStopOnPrecommitWaitsForAReplayablePrecommit(t *testing.T) {
	signer, key, state := filePV(t)
	var eligible atomic.Uint64
	eligible.Store(1)
	sessionFor(t, signer, testComet(), &eligible).signs(vote(tm.PrecommitType, 0, 1, 100))
	s, stops := armedSession(t, signer, &eligible)
	unbound := reporting(testComet())
	unbound.armed, unbound.stops = true, stops
	s.g.supervisor = unbound
	if closed, _, _ := signer.armStop(); closed {
		t.Fatal("arming closed on a last precommit without a replay binding")
	}
	s.signs(vote(tm.PrecommitType, 1, 1, 100))
	if stops.String() != "" || persisted(t, key, state).Replay != nil {
		t.Fatalf("closed after a precommit without a replay binding: %v", stops)
	}
	reporter := bound(testComet())
	reporter.armed, reporter.stops = true, stops
	s.g.supervisor = reporter
	s.signs(vote(tm.PrecommitType, 2, 1, 100))
	if got := persisted(t, key, state); stops.String() != "1/2" || got.Replay == nil || got.Round != 2 {
		t.Fatalf("stop reports %v after a bound precommit, state %+v", stops, got)
	}
	s.refuses(vote(tm.PrevoteType, 3, 1, 100), "stopped after its precommit")
}

// START-10.1-14b, RECOV-8.2-2 vector 2.p: armed for a planned ruleset upgrade after the old app
// rejected a proposal and prevoted nil at H, the signer still signs the prevote, then persists
// and returns the next precommit, nil included, as its last signature and closes: every later
// request, its own retry included, is refused, and the stop is reported once.
func TestStopOnPrecommitClosesAfterIt(t *testing.T) {
	signer, key, state := filePV(t)
	var eligible atomic.Uint64
	eligible.Store(1)
	s, stops := armedSession(t, signer, &eligible)
	s.signs(vote(tm.PrevoteType, 0, 0, 100))
	if stops.String() != "" {
		t.Fatal("a prevote closed the gate")
	}
	precommit := s.signs(vote(tm.PrecommitType, 0, 0, 100))
	if got := persisted(t, key, state); got.Step != stepPrecommit || !bytes.Equal(got.Signature, precommit) {
		t.Fatal("the closing precommit is not the persisted last signature")
	}
	if stops.String() != "1/0" {
		t.Fatalf("stop reports %v", stops)
	}
	before := readFile(t, state)
	for _, request := range []pv.Message{vote(tm.PrecommitType, 0, 0, 100), vote(tm.PrevoteType, 1, 0, 100), vote(tm.PrecommitType, 1, 1, 100), at(proposalRequest(), 1, 2)} {
		s.refuses(request, "stopped after its precommit")
	}
	if !bytes.Equal(before, readFile(t, state)) || stops.String() != "1/0" {
		t.Fatalf("the closed gate changed the state or reported again: %v", stops)
	}
}

// If a precommit already is the last signature, arming closes the gate under the same signing
// lock: at once from the supervisor poll, before any later request.
func TestStopOnPrecommitWhenThePrecommitIsAlreadyLast(t *testing.T) {
	signer, _, _ := filePV(t)
	var eligible atomic.Uint64
	eligible.Store(1)
	first := sessionFor(t, signer, testComet(), &eligible)
	first.g.supervisor = bound(testComet())
	first.signs(vote(tm.PrecommitType, 0, 1, 100))
	s, stops := armedSession(t, signer, &eligible)
	go s.g.pollStop(signer, 10*time.Millisecond)
	defer s.g.closeTransports()
	deadline := time.Now().Add(2 * time.Second)
	for stops.String() == "" && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond)
	}
	s.g.closeTransports()
	if stops.String() != "1/0" {
		t.Fatalf("stop reports %v", stops)
	}
	s, _ = armedSession(t, signer, &eligible)
	s.refuses(vote(tm.PrevoteType, 1, 0, 100), "stopped after its precommit")
}

// Without the armed stop a precommit closes nothing; arming waits for the next precommit, and a
// repeat of a saved prevote does not count.
func TestStopOnPrecommitWaitsForAPrecommit(t *testing.T) {
	signer, _, _ := filePV(t)
	var eligible atomic.Uint64
	eligible.Store(1)
	plain := sessionFor(t, signer, testComet(), &eligible)
	plain.signs(vote(tm.PrevoteType, 0, 1, 100))
	s, stops := armedSession(t, signer, &eligible)
	s.signs(vote(tm.PrevoteType, 0, 1, 100))
	s.signs(vote(tm.PrevoteType, 1, 1, 100))
	if stops.String() != "" {
		t.Fatalf("closed without a precommit: %v", stops)
	}
	s.signs(vote(tm.PrecommitType, 1, 1, 100))
	if stops.String() != "1/1" {
		t.Fatalf("stop reports %v", stops)
	}
}
