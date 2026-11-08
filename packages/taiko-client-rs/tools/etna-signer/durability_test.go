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

// A signature costs exactly two fsyncs, the state file's and its directory's, after stock
// FilePV's synchronous write and rename, and no fence is written while signing (SYNC-9-13).
// Both run under an inflight marker naming this boot, removed once they succeed. A cached
// same-HRS retry is synchronized the same way, since an earlier synchronization may have failed
// after FilePV updated its in-memory state.
func TestSigningSyncsStateAndDirectoryOnceWithoutFence(t *testing.T) {
	if bootID() == "" {
		t.Fatal("no boot identity on this platform")
	}
	for _, family := range signingFamilies {
		t.Run(family, func(t *testing.T) {
			_, key, state := filePV(t)
			signer := loadDurableFilePV(key, state)
			var files, dirs int
			unfenced := func() {
				if _, err := os.Lstat(fencePath(state)); !os.IsNotExist(err) {
					t.Errorf("fence present while signing: %v", err)
				}
				if marker, err := os.ReadFile(inflightPath(state)); err != nil || string(marker) != bootID()+"\n" {
					t.Errorf("synchronized without this boot's inflight marker: %q %v", marker, err)
				}
			}
			signer.syncFile = func(file *os.File) error {
				files++
				unfenced()
				return file.Sync()
			}
			signer.syncDir = func(directory string) error {
				dirs++
				unfenced()
				if directory != filepath.Dir(state) {
					t.Errorf("synchronized %s, not the state's directory", directory)
				}
				return syncDirectory(directory)
			}
			var first []byte
			for attempt, step := range []string{"new", "cached"} {
				files, dirs = 0, 0
				signature, err := signFamily(signer, familyRequest(family, false))
				if err != nil || len(signature) < 65 {
					t.Fatalf("%s signature: %v", step, err)
				}
				if files != 1 || dirs != 1 {
					t.Fatalf("%s signature: %d state and %d directory fsyncs, want 1 and 1", step, files, dirs)
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
			signer.syncFile = func(*os.File) error { files++; return syscall.EIO }
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

// A death between starting to synchronize the state and either finishing or writing the fence
// leaves only the inflight marker. A restart on the same boot refuses it, since that boot's page
// cache may show a state whose failed fsync was already reported and cleared; a marker from
// another boot is stale and ignored, since a reboot drops that cache (RECOV-8.2-3, SYNC-9-13).
// Anything else at the marker's path refuses, and a marker that cannot be written latches like
// a failed fsync, before any fsync or signature.
func TestInflightMarkerRefusesOnlyTheSameBoot(t *testing.T) {
	for _, c := range []struct {
		name   string
		setup  func(marker string)
		refuse bool
	}{
		{"this-boot", func(marker string) { os.WriteFile(marker, []byte(bootID()+"\n"), 0600) }, true},
		{"empty", func(marker string) { os.WriteFile(marker, nil, 0600) }, true},
		{"oversized", func(marker string) { os.WriteFile(marker, bytes.Repeat([]byte("a"), 129), 0600) }, true},
		{"directory", func(marker string) { os.Mkdir(marker, 0700) }, true},
		{"symlink-to-another-boot", func(marker string) {
			other := filepath.Join(t.TempDir(), "other")
			os.WriteFile(other, []byte("earlier-boot\n"), 0600)
			os.Symlink(other, marker)
		}, true},
		{"another-boot", func(marker string) { os.WriteFile(marker, []byte("earlier-boot\n"), 0600) }, false},
	} {
		t.Run(c.name, func(t *testing.T) {
			_, key, state := filePV(t)
			c.setup(inflightPath(state))
			signer, release, err := openSigningState(chain, key, state, domainsLogOf(state))
			if c.refuse {
				if !errors.Is(err, errSigningStateUnsafe) || !strings.Contains(err.Error(), "inflight marker") {
					t.Fatalf("restart accepted the marker: %v", err)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			defer release()
			if signature, err := signFamily(signer, familyRequest("prevote", false)); err != nil || len(signature) != 65 {
				t.Fatalf("stale marker blocked signing: %v", err)
			}
			if _, err := os.Lstat(inflightPath(state)); !os.IsNotExist(err) {
				t.Fatalf("signing left the stale marker: %v", err)
			}
		})
	}
	t.Run("unwritable", func(t *testing.T) {
		_, key, state := filePV(t)
		signer := loadDurableFilePV(key, state)
		if err := os.Mkdir(inflightPath(state), 0700); err != nil {
			t.Fatal(err)
		}
		signer.syncFile = func(*os.File) error { t.Error("synchronized without a marker"); return nil }
		if signature, err := signFamily(signer, familyRequest("prevote", false)); !errors.Is(err, errSigningStateUnsafe) || len(signature) != 0 {
			t.Fatalf("unmarked synchronization released a signature: %v", err)
		}
		if record := readFence(t, state); !strings.Contains(record.Error, "inflight marker") {
			t.Fatalf("fence %+v", record)
		}
		if err := signer.signDurably(func() error { t.Error("stock signing ran after the latch"); return nil }); !errors.Is(err, errSigningStateUnsafe) {
			t.Fatalf("latch: %v", err)
		}
	})
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
