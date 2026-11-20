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
					if request["op"] == "comet" {
						reply["comet"] = reportJSON(report())
					} else {
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
	if err := p.admit(otherProcess(otherInstance)); err != nil {
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
		reporter cometReporter
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
	if proc, err := newSupervisorChannel(path, os.Getpid()).comet(deadline); err != nil || proc == nil || *proc != testComet() {
		t.Fatalf("own peer: %v %v", proc, err)
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
		if err := guarded.admit(testComet()); err != nil {
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
