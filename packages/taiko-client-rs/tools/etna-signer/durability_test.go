package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// signingFamilies are the three stock signing steps; each has its own HRS step.
var signingFamilies = []string{"prevote", "precommit", "proposal"}

// familyRequest is a signing request at H1 R0. A conflict differs only in its block at the same HRS.
func familyRequest(family string, conflict bool) pv.Message {
	switch family {
	case "prevote":
		return voteRequest(tm.PrevoteType, 0, conflict)
	case "precommit":
		return voteRequest(tm.PrecommitType, 0, conflict)
	}
	request := proposalRequest()
	if conflict {
		request.GetSignProposalRequest().Proposal.BlockID = tm.BlockID{Hash: bytes.Repeat([]byte{1}, 32), PartSetHeader: tm.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{2}, 32)}}
	}
	return request
}

// signFamily signs one request directly on the durable FilePV and returns what the caller received.
func signFamily(signer *durableFilePV, request pv.Message) ([]byte, error) {
	if vote := request.GetSignVoteRequest(); vote != nil {
		err := signer.SignVote(chain, vote.Vote)
		return append(append([]byte{}, vote.Vote.Signature...), vote.Vote.ExtensionSignature...), err
	}
	proposal := request.GetSignProposalRequest().Proposal
	err := signer.SignProposal(chain, proposal)
	return proposal.Signature, err
}

// released is the signature a wire response carries and its remote error.
func released(response pv.Message) ([]byte, *pv.RemoteSignerError) {
	if vote := response.GetSignedVoteResponse(); vote != nil {
		return append(append([]byte{}, vote.Vote.Signature...), vote.Vote.ExtensionSignature...), vote.Error
	}
	if proposal := response.GetSignedProposalResponse(); proposal != nil {
		return proposal.Proposal.Signature, proposal.Error
	}
	return nil, &pv.RemoteSignerError{Description: "no signing response"}
}

// fenceRecord is the fence's exact JSON shape.
type fenceRecord struct {
	Schema    int    `json:"schema"`
	Operation string `json:"operation"`
	State     string `json:"state"`
	Error     string `json:"error"`
}

func readFence(t *testing.T, state string) fenceRecord {
	t.Helper()
	raw, err := os.ReadFile(fencePath(state))
	if err != nil {
		t.Fatal("no signer fence", err)
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	var record fenceRecord
	if err := decoder.Decode(&record); err != nil {
		t.Fatalf("fence %q: %v", raw, err)
	}
	if record.Schema != 1 || record.Operation != "FilePV signing" {
		t.Fatalf("fence %q", raw)
	}
	return record
}

// A signing step first makes an inflight marker naming this boot durable, its file and then
// the directory, before stock FilePV writes; then it fsyncs the state file and its directory
// after FilePV's synchronous write and rename, and removes the marker. That is four fsyncs, in
// that order, and no fence (SYNC-9-13). A cached same-HRS retry is synchronized the same way,
// since an earlier synchronization may have failed after FilePV updated its in-memory state.
func TestSigningMakesTheMarkerDurableThenSyncsTheStateWithoutFence(t *testing.T) {
	if bootID() == "" {
		t.Fatal("no boot identity on this platform")
	}
	for _, family := range signingFamilies {
		t.Run(family, func(t *testing.T) {
			_, key, state := filePV(t)
			signer := loadDurableFilePV(key, state)
			var order []string
			marked := func(when string) {
				if _, err := os.Lstat(fencePath(state)); !os.IsNotExist(err) {
					t.Errorf("fence present while signing: %v", err)
				}
				if marker, err := os.ReadFile(inflightPath(state)); err != nil || string(marker) != bootID()+"\n" {
					t.Errorf("%s without this boot's inflight marker: %q %v", when, marker, err)
				}
			}
			var before []byte
			signer.syncFile = func(file *os.File) error {
				marked("file fsync")
				if strings.HasSuffix(file.Name(), inflightSuffix) {
					order = append(order, "marker")
					before = readFile(t, state)
				} else {
					order = append(order, "state")
				}
				return file.Sync()
			}
			signer.syncDir = func(directory string) error {
				marked("directory fsync")
				if len(order) == 1 && !bytes.Equal(before, readFile(t, state)) {
					t.Error("stock FilePV wrote between the marker's file and directory fsyncs")
				}
				order = append(order, "directory")
				if directory != filepath.Dir(state) {
					t.Errorf("synchronized %s, not the state's directory", directory)
				}
				return syncDirectory(directory)
			}
			var first []byte
			for attempt, step := range []string{"new", "cached"} {
				order = nil
				initial := readFile(t, state)
				signature, err := signFamily(signer, familyRequest(family, false))
				if err != nil || len(signature) < 65 {
					t.Fatalf("%s signature: %v", step, err)
				}
				if want := []string{"marker", "directory", "state", "directory"}; strings.Join(order, ",") != strings.Join(want, ",") {
					t.Fatalf("%s signature fsyncs %v, want %v", step, order, want)
				}
				if !bytes.Equal(before, initial) {
					t.Fatalf("%s signature changed the HRS before its marker was durable", step)
				}
				if attempt == 0 {
					first = signature
				} else if !bytes.Equal(first[:65], signature[:65]) {
					t.Fatal("cached retry changed the signature")
				}
				if _, err := os.Lstat(inflightPath(state)); !os.IsNotExist(err) {
					t.Fatalf("%s signature left its inflight marker: %v", step, err)
				}
			}
			if _, err := os.Lstat(fencePath(state)); !os.IsNotExist(err) {
				t.Fatalf("signing wrote a fence: %v", err)
			}
			persisted := privval.LoadFilePV(key, state).LastSignState
			if persisted.Height != 1 || !bytes.Equal(persisted.Signature, first[:65]) {
				t.Fatalf("signed state %d does not hold the released signature", persisted.Height)
			}
		})
	}
}

// A marker whose own fsync fails refuses the step before stock FilePV writes: the HRS is
// unchanged and nothing is signed. The HRS volume is failing, so the signer latches and writes
// the fence like any failed fsync (RECOV-8.2-3).
func TestMarkerSyncFailureRefusesBeforeTheStateChanges(t *testing.T) {
	for _, failing := range []string{"file", "directory"} {
		t.Run(failing, func(t *testing.T) {
			_, key, state := filePV(t)
			signer := loadDurableFilePV(key, state)
			if failing == "file" {
				signer.syncFile = func(*os.File) error { return syscall.EIO }
			} else {
				signer.syncDir = func(string) error { return syscall.EIO }
			}
			before := readFile(t, state)
			signature, err := signFamily(signer, familyRequest("prevote", false))
			if !errors.Is(err, errSigningStateUnsafe) || !errors.Is(err, syscall.EIO) || len(signature) != 0 {
				t.Fatalf("failed marker fsync signed: %v", err)
			}
			if !bytes.Equal(before, readFile(t, state)) {
				t.Fatal("stock FilePV wrote before the marker was durable")
			}
			if record := readFence(t, state); !strings.Contains(record.Error, "inflight marker") {
				t.Fatalf("fence %+v", record)
			}
			if err := signer.signDurably(func() error { t.Error("stock signing ran after the latch"); return nil }); !errors.Is(err, errSigningStateUnsafe) {
				t.Fatalf("latch: %v", err)
			}
		})
	}
}

// A failed state fsync makes the latest state uncertain (RECOV-8.2-3): the signature is
// withheld, the fence records the cause, the in-memory latch refuses every later request
// without reaching stock signing, and the gate reports the terminal error so the process
// exits 3. A restart refuses on the fence; only an operator's removal of it lets a new
// process resume, and that process keeps the stock HRS protection.
func TestStateSyncFailureWritesFenceLatchesAndStops(t *testing.T) {
	for _, family := range signingFamilies {
		t.Run(family, func(t *testing.T) {
			_, key, state := filePV(t)
			signer := loadDurableFilePV(key, state)
			var files int
			signer.syncFile = func(file *os.File) error {
				if strings.HasSuffix(file.Name(), inflightSuffix) {
					return file.Sync()
				}
				files++
				return syscall.EIO
			}
			g := armed(control(t, func(map[string]any) any { return snapshot(true) }))
			response, err := g.handle(signer, familyRequest(family, false), chain)
			if !errors.Is(err, errSigningStateUnsafe) || !errors.Is(err, syscall.EIO) {
				t.Fatalf("failed fsync was not unsafe: %v", err)
			}
			if signature, remote := released(response); len(signature) != 0 || remote == nil {
				t.Fatal("failed fsync released a signature")
			}
			if record := readFence(t, state); record.State != state || !strings.Contains(record.Error, "input/output error") {
				t.Fatalf("fence %+v", record)
			}
			select {
			case terminal := <-g.terminal:
				if !errors.Is(terminal, errSigningStateUnsafe) {
					t.Fatalf("terminal %v", terminal)
				}
			default:
				t.Fatal("failed fsync did not stop the signer")
			}
			// The disk recovers; the latch still refuses, before stock signing or another fsync.
			signer.syncFile = (*os.File).Sync
			for _, conflict := range []bool{false, true} {
				response, err = g.handle(signer, familyRequest(family, conflict), chain)
				if signature, _ := released(response); !errors.Is(err, errSigningStateUnsafe) || len(signature) != 0 {
					t.Fatalf("latched signer signed (conflict %v): %v", conflict, err)
				}
			}
			if err := signer.signDurably(func() error { t.Error("stock signing ran after the latch"); return nil }); !errors.Is(err, errSigningStateUnsafe) {
				t.Fatalf("latch: %v", err)
			}
			if files != 1 {
				t.Fatalf("latched signer synchronized again (%d fsyncs)", files)
			}
			if _, _, err := openSigningState(chain, key, state, domainsLogOf(state)); !errors.Is(err, errSigningStateUnsafe) || !strings.Contains(err.Error(), "fence") {
				t.Fatalf("restart bypassed the fence: %v", err)
			}
			// The inflight marker stays as same-boot evidence beside the fence.
			if err := os.Remove(fencePath(state)); err != nil {
				t.Fatal(err)
			}
			if _, _, err := openSigningState(chain, key, state, domainsLogOf(state)); !errors.Is(err, errSigningStateUnsafe) || !strings.Contains(err.Error(), "inflight marker") {
				t.Fatalf("restart bypassed this boot's inflight marker: %v", err)
			}
			// Only an operator's removal of both lets a new process sign, from the HRS on disk.
			if err := os.Remove(inflightPath(state)); err != nil {
				t.Fatal(err)
			}
			restarted, release, err := openSigningState(chain, key, state, domainsLogOf(state))
			if err != nil {
				t.Fatal(err)
			}
			defer release()
			if signature, err := signFamily(restarted, familyRequest(family, true)); err == nil || !strings.Contains(err.Error(), "conflicting data") || len(signature) != 0 {
				t.Fatalf("repaired restart lost double-sign protection: %v", err)
			}
			signature, err := signFamily(restarted, familyRequest(family, false))
			persisted := privval.LoadFilePV(key, state).LastSignState
			if err != nil || len(signature) < 65 || !bytes.Equal(signature[:65], persisted.Signature) || persisted.Height != 1 {
				t.Fatalf("repaired restart did not return the stored signature: %v", err)
			}
		})
	}
}

// A death after the inflight marker is durable and before the step finished or wrote the fence
// leaves the marker naming this boot, and a restart on that boot refuses it: its page cache may
// show a state whose failed fsync was already reported and cleared (RECOV-8.2-3, SYNC-9-13). Any
// other content means the step never got past the marker's own fsync, with the HRS unchanged: an
// empty or zero-filled marker, what a host crash leaves when only the name reached the disk, and
// another boot's marker are removed and ignored. Any other inode, or an oversized one, refuses,
// and a hard link to the state is refused as a second link to it. A marker that cannot be
// created panics before any fsync or stock write.
func TestInflightMarkerRefusesOnlyTheSameBoot(t *testing.T) {
	for _, c := range []struct {
		name   string
		setup  func(marker, state string)
		refuse string
	}{
		{"this-boot", func(marker, _ string) { os.WriteFile(marker, []byte(bootID()+"\n"), 0600) }, "inflight marker"},
		{"this-boot-unterminated", func(marker, _ string) { os.WriteFile(marker, []byte(bootID()), 0600) }, "inflight marker"},
		{"oversized", func(marker, _ string) { os.WriteFile(marker, bytes.Repeat([]byte("a"), 129), 0600) }, "inflight marker"},
		{"directory", func(marker, _ string) { os.Mkdir(marker, 0700) }, "inflight marker"},
		{"symlink-to-another-boot", func(marker, _ string) {
			other := filepath.Join(t.TempDir(), "other")
			os.WriteFile(other, []byte("earlier-boot\n"), 0600)
			os.Symlink(other, marker)
		}, "inflight marker"},
		// A hard link is refused before the marker is read, by the state's single-link check.
		{"hard-link-to-the-state", func(marker, state string) { os.Link(state, marker) }, "exactly one filesystem link"},
		{"empty-after-host-crash", func(marker, _ string) { os.WriteFile(marker, nil, 0600) }, ""},
		{"zero-filled-after-host-crash", func(marker, _ string) { os.WriteFile(marker, make([]byte, 37), 0600) }, ""},
		{"another-boot", func(marker, _ string) { os.WriteFile(marker, []byte("earlier-boot\n"), 0600) }, ""},
	} {
		t.Run(c.name, func(t *testing.T) {
			_, key, state := filePV(t)
			c.setup(inflightPath(state), state)
			before := readFile(t, state)
			signer, release, err := openSigningState(chain, key, state, domainsLogOf(state))
			if c.refuse != "" {
				if !errors.Is(err, errSigningStateUnsafe) || !strings.Contains(err.Error(), c.refuse) {
					t.Fatalf("restart accepted the marker: %v", err)
				}
				if !bytes.Equal(before, readFile(t, state)) {
					t.Fatal("refusal changed the HRS")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			defer release()
			if _, err := os.Lstat(inflightPath(state)); !os.IsNotExist(err) {
				t.Fatalf("startup kept the stale marker: %v", err)
			}
			if !bytes.Equal(before, readFile(t, state)) {
				t.Fatal("removing the stale marker changed the HRS")
			}
			if signature, err := signFamily(signer, familyRequest("prevote", false)); err != nil || len(signature) != 65 {
				t.Fatalf("stale marker blocked signing: %v", err)
			}
			if _, err := os.Lstat(inflightPath(state)); !os.IsNotExist(err) {
				t.Fatalf("signing left its marker: %v", err)
			}
		})
	}
	// A marker that cannot be created (here an existing directory) panics before any fsync or
	// stock write, like a failed stock write (exit 2), and writes no fence. The supervisor's
	// restart then refuses the inode left at the marker's path (refuseInflight).
	t.Run("uncreatable", func(t *testing.T) {
		_, key, state := filePV(t)
		signer := loadDurableFilePV(key, state)
		if err := os.Mkdir(inflightPath(state), 0700); err != nil {
			t.Fatal(err)
		}
		signer.syncFile = func(*os.File) error { t.Error("synchronized without a marker"); return nil }
		before := readFile(t, state)
		var recovered any
		func() {
			defer func() { recovered = recover() }()
			signFamily(signer, familyRequest("prevote", false))
			t.Error("an uncreatable marker did not panic")
		}()
		if err, ok := recovered.(error); !ok || !errors.Is(err, errInflightWrite) {
			t.Fatalf("panic %v", recovered)
		}
		if !bytes.Equal(before, readFile(t, state)) {
			t.Fatal("stock FilePV wrote without a marker")
		}
		if _, err := os.Lstat(fencePath(state)); !os.IsNotExist(err) {
			t.Fatalf("an unwritten marker wrote a fence: %v", err)
		}
		if _, _, err := openSigningState(chain, key, state, domainsLogOf(state)); !errors.Is(err, errSigningStateUnsafe) || !strings.Contains(err.Error(), "inflight marker") {
			t.Fatalf("restart accepted the inode at the marker's path: %v", err)
		}
	})
}

// A stock persistence panic (a failed temporary write or rename, or a corrupt last-sign state)
// comes at or before FilePV's atomic rename, with the HRS unchanged and none of the step's state
// fsyncs run. The step removes its durable marker before the panic goes on, so the process exits
// 2 without a fence and the supervisor's restart on this boot serves the unchanged HRS.
func TestStockPanicRemovesTheMarkerSoTheRestartServes(t *testing.T) {
	_, key, state := filePV(t)
	signer := loadDurableFilePV(key, state)
	before := readFile(t, state)
	var recovered any
	func() {
		defer func() { recovered = recover() }()
		signer.signDurably(func() error {
			if marker, err := os.ReadFile(inflightPath(state)); err != nil || string(marker) != bootID()+"\n" {
				t.Errorf("stock signing ran without this boot's durable marker: %q %v", marker, err)
			}
			panic("stock write failed")
		})
		t.Error("the stock panic did not propagate")
	}()
	if recovered != "stock write failed" {
		t.Fatalf("panic %v", recovered)
	}
	if _, err := os.Lstat(inflightPath(state)); !os.IsNotExist(err) {
		t.Fatalf("a stock panic left the marker: %v", err)
	}
	if _, err := os.Lstat(fencePath(state)); !os.IsNotExist(err) {
		t.Fatalf("a stock panic wrote a fence: %v", err)
	}
	if !bytes.Equal(before, readFile(t, state)) {
		t.Fatal("the HRS changed")
	}
	restarted, release, err := openSigningState(chain, key, state, domainsLogOf(state))
	if err != nil {
		t.Fatalf("the restart after a stock panic refused: %v", err)
	}
	defer release()
	if signature, err := signFamily(restarted, familyRequest("prevote", false)); err != nil || len(signature) != 65 {
		t.Fatalf("the restart did not sign: %v", err)
	}
}

// listenComet is a fresh Comet-owned privval listener at socket.
func listenComet(t *testing.T, socket string) net.Listener {
	t.Helper()
	raw, err := net.ListenUnix("unix", &net.UnixAddr{Name: socket, Net: "unix"})
	if err != nil {
		t.Fatal(err)
	}
	listener := privval.NewUnixListener(raw)
	t.Cleanup(func() { listener.Close() })
	return listener
}

// signerLogs collects a child's output and prints it if the test fails.
func signerLogs(t *testing.T) *os.File {
	t.Helper()
	logs, err := os.Create(filepath.Join(shortTemp(t), "signer.log"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		logs.Close()
		if t.Failed() {
			contents, _ := os.ReadFile(logs.Name())
			t.Logf("signer output: %s", contents)
		}
	})
	return logs
}

// serveDirectly starts the real signer on listener and completes Comet's startup PubKey.
func serveDirectly(t *testing.T, listener net.Listener, logs *os.File, args []string) (*exec.Cmd, net.Conn) {
	t.Helper()
	child := exec.Command(signerBinary(t), args...)
	child.Stdout, child.Stderr = logs, logs
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { stopTestProcess(t, child) })
	conn := acceptSigner(t, listener)
	pubkey := pv.Message{Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: chain}}}
	if response := signerExchange(t, conn, pubkey); response.GetPubKeyResponse() == nil || response.GetPubKeyResponse().Error != nil {
		t.Fatal("initial pubkey failed")
	}
	return child, conn
}

// The state directory stays writable and searchable, so stock FilePV replaces its HRS file,
// but opening the directory for fsync fails. The serving process withholds the signature,
// writes the fence and exits 3; a restart exits 3 on the fence and leaves the HRS unchanged
// (RECOV-8.2-3, SYNC-9-13).
func TestFsyncFailureExitsThreeAndFenceRefusesRestart(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root bypasses the directory-read permission fault")
	}
	for _, family := range signingFamilies {
		t.Run(family, func(t *testing.T) {
			_, key, state := filePV(t)
			canonical, err := filepath.EvalSymlinks(state)
			if err != nil {
				t.Fatal(err)
			}
			directory := filepath.Dir(state)
			trust := control(t, func(request map[string]any) any { return snapshot(request["op"] != "begin_session") })
			socket := filepath.Join(shortTemp(t), "comet.sock")
			args := []string{"--comet-signer-addr", "unix://" + socket, "--trust-socket", trust, "--chain-id", chain, "--priv-key", key, "--priv-state", state, "--domains-log", domainsLogOf(state)}
			child, conn := serveDirectly(t, listenComet(t, socket), signerLogs(t), args)
			if err = os.Chmod(directory, 0300); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { os.Chmod(directory, 0700) })
			if f, e := os.Open(directory); e == nil {
				f.Close()
				t.Fatal("directory fault did not prevent opening it for synchronization")
			}
			request := familyRequest(family, false)
			if err := conn.SetDeadline(time.Now().Add(3 * time.Second)); err != nil {
				t.Fatal(err)
			}
			if _, err := protoio.NewDelimitedWriter(conn).WriteMsg(&request); err != nil {
				t.Fatal(err)
			}
			var reply pv.Message
			if _, err := protoio.NewDelimitedReader(conn, 16*1024).ReadMsg(&reply); err == nil {
				// Exit may close the transport before the error reply.
				if signature, remote := released(reply); len(signature) != 0 || remote == nil {
					t.Fatal("released a signature before the directory fsync")
				}
			}
			done := make(chan error, 1)
			go func() { done <- child.Wait() }()
			select {
			case <-done:
				if code := child.ProcessState.ExitCode(); code != exitSigningStateUnsafe {
					t.Fatalf("fsync failure exited %d, not %d", code, exitSigningStateUnsafe)
				}
			case <-time.After(3 * time.Second):
				child.Process.Kill()
				<-done
				t.Fatal("signer with uncertain state did not terminate")
			}
			if err = os.Chmod(directory, 0700); err != nil {
				t.Fatal(err)
			}
			if record := readFence(t, state); record.State != canonical || !strings.Contains(record.Error, "permission denied") {
				t.Fatalf("fence %+v", record)
			}
			before, fence := readFile(t, state), readFile(t, fencePath(state))
			if code, stderr := runSigner(t, args...); code != exitSigningStateUnsafe || !strings.Contains(stderr, "fence") {
				t.Fatalf("restart with a fence exited %d: %s", code, stderr)
			}
			if !bytes.Equal(before, readFile(t, state)) || !bytes.Equal(fence, readFile(t, fencePath(state))) {
				t.Fatal("refused restart changed the HRS or the fence")
			}
		})
	}
}
