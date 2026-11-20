package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/ed25519"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/libp2p/go-libp2p/core/peer"
)

// supervisorEnvironment is the supervisor's environment for this process's state layout,
// without any inherited ETNA_ variable.
func supervisorEnvironment(home, store, key, state string, extra ...string) []string {
	environment := make([]string, 0, len(os.Environ()))
	for _, value := range os.Environ() {
		if !strings.HasPrefix(value, "ETNA_") {
			environment = append(environment, value)
		}
	}
	environment = append(environment, "ETNA_COMET_HOME="+home, "ETNA_APP_STORE="+store,
		"ETNA_PRIV_KEY="+key, "ETNA_PRIV_STATE_DIR="+filepath.Dir(state),
		"ETNA_DOMAINS_LOG="+domainsLogOf(state), "ETNA_CHAIN_ID="+chain)
	return append(environment, extra...)
}

// validatorConfig is a supervised validator's config.toml: its signer listener and the
// listed-peer P2P settings the supervisor requires (START-10-6).
func validatorConfig(laddr string) []byte {
	return []byte(fmt.Sprintf("priv_validator_laddr = %q\n[p2p]\npex = false\nmax_num_inbound_peers = 0\n", laddr))
}

// cometManifest writes a deployment manifest pinning executable for this host's platform, as the
// shipped comet-manifest.json pins the official linux/amd64 executable, and returns the
// supervisor environment entry naming it (CONS-3.1-1).
func cometManifest(t *testing.T, dir, executable string) string {
	t.Helper()
	resolved, err := filepath.EvalSymlinks(executable)
	if err != nil {
		t.Fatal(err)
	}
	digest := sha256.Sum256(readFile(t, resolved))
	manifest, _ := json.Marshal(map[string]any{"schema": 1, "engine": "cometbft", "release": "v0.40.0",
		"source_commit": "0880b4d378f347ab16e54ec677ff50d803f37d62",
		"platforms":     map[string]any{runtime.GOOS + "/" + runtime.GOARCH: map[string]string{"sha256": hex.EncodeToString(digest[:])}}})
	path := filepath.Join(dir, "comet-manifest.json")
	if err := os.WriteFile(path, manifest, 0600); err != nil {
		t.Fatal(err)
	}
	return "ETNA_COMET_MANIFEST=" + path
}

// noiseComet plays stock Comet's noise://<signer-peer-id>@127.0.0.1:<port> signer listener for a
// supervised home: Comet's persistent node key in <home>/config/node_key.json, and a signer
// transport key in keyDir that the listener pins. It returns the listener, its config.toml
// address and the environment entry naming the transport key.
func noiseComet(t *testing.T, home, keyDir string) (net.Listener, string, string) {
	t.Helper()
	cometKey := ed25519.GenPrivKey()
	raw, err := cmtjson.Marshal(transportKeyFile{PrivKey: cometKey})
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(home, "config", "node_key.json"), raw, 0600); err != nil {
		t.Fatal(err)
	}
	transportKey := filepath.Join(keyDir, "signer-transport.json")
	if err = transportKeygen([]string{"--transport-key", transportKey}, io.Discard); err != nil {
		t.Fatal(err)
	}
	signerKey, err := loadTransportKey(transportKey)
	if err != nil {
		t.Fatal(err)
	}
	tcp, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	listener, err := privval.NewNoiseListener(tcp, cometKey, []peer.ID{mustPeer(t, signerKey)}, privval.NoiseListenerTimeoutAccept(20*time.Second))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { listener.Close() })
	return listener, "noise://" + mustPeer(t, signerKey).String() + "@" + tcp.Addr().String(), "ETNA_SIGNER_TRANSPORT_KEY=" + transportKey
}

// A real persistence failure must reach the supervisor's durable terminal path,
// rather than its trust-refusal restart path. The parent supplies Comet's official
// transport while the supervised Comet child records process incarnations. A recovered
// generation runs the same single mode on its own chain_id state.
func TestSupervisorLatchesUncertainSigningStateAcrossRestart(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root bypasses the directory-read permission fault")
	}
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Fatal(err)
	}
	binary := signerBinary(t)
	for _, mode := range []string{"generation-zero", "recovered"} {
		t.Run(mode, func(t *testing.T) {
			_, key, state := filePV(t)
			ready := snapshotAt(true, 7)
			if mode == "recovered" {
				ready = recoveredSnapshot(2)
			}
			controlPath := control(t, func(request map[string]any) any {
				response := make(map[string]any, len(ready))
				for key, value := range ready {
					response[key] = value
				}
				if request["op"] == "begin_session" {
					response["phase"] = "acquiring"
				}
				return response
			})
			root := shortTemp(t)
			home, store := filepath.Join(root, "comet"), filepath.Join(root, "app")
			for _, path := range []string{filepath.Join(home, "config"), store} {
				if err := os.MkdirAll(path, 0700); err != nil {
					t.Fatal(err)
				}
			}
			if err := os.Symlink(controlPath, filepath.Join(store, "checkpoint-trust.sock")); err != nil {
				t.Fatal(err)
			}
			listener, laddr, transportKey := noiseComet(t, home, root)
			if err := os.WriteFile(filepath.Join(home, "config", "config.toml"), validatorConfig(laddr), 0600); err != nil {
				t.Fatal(err)
			}
			genesis, _ := json.Marshal(map[string]any{"chain_id": chain})
			if err := os.WriteFile(filepath.Join(home, "config", "genesis.json"), genesis, 0600); err != nil {
				t.Fatal(err)
			}
			starts := filepath.Join(root, "comet-starts")
			cometCommand, _ := json.Marshal([]string{python, "-c", "import os,time; open(os.environ['COMET_STARTS'],'a').write('start\\n'); time.sleep(300)"})
			environment := supervisorEnvironment(home, store, key, state,
				"ETNA_SIGNER_BIN="+binary, "ETNA_COMET_COMMAND_JSON="+string(cometCommand), "COMET_STARTS="+starts,
				transportKey, cometManifest(t, root, python))
			logs, err := os.Create(filepath.Join(root, "supervisor.log"))
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				logs.Close()
				if t.Failed() {
					contents, _ := os.ReadFile(logs.Name())
					t.Logf("supervisor output: %s", contents)
				}
			})
			start := func() *exec.Cmd {
				child := exec.Command(python, "../../script/etna_validator.py")
				child.Env, child.Stdout, child.Stderr = environment, logs, logs
				if err := child.Start(); err != nil {
					t.Fatal(err)
				}
				t.Cleanup(func() { stopTestProcess(t, child) })
				return child
			}
			supervisor := start()
			conn := acceptSigner(t, listener)
			request := func() pv.Message {
				return pv.Message{Sum: &pv.Message_SignVoteRequest{SignVoteRequest: &pv.SignVoteRequest{ChainId: chain, Vote: &tm.Vote{Type: tm.PrevoteType, Height: 7, Timestamp: time.Unix(100, 0)}}}}
			}
			initial := signerExchange(t, conn, request())
			if signed := initial.GetSignedVoteResponse(); signed == nil || signed.Error != nil || len(signed.Vote.Signature) != 65 {
				t.Fatal("initial trusted signature failed", signed)
			}
			before, err := os.ReadFile(state)
			if err != nil {
				t.Fatal(err)
			}
			keyBefore, _ := os.ReadFile(key)
			directory := filepath.Dir(state)
			if err := os.Chmod(directory, 0300); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { os.Chmod(directory, 0700) })
			if err := conn.SetDeadline(time.Now().Add(3 * time.Second)); err != nil {
				t.Fatal(err)
			}
			retry := request()
			if _, err := protoio.NewDelimitedWriter(conn).WriteMsg(&retry); err != nil {
				t.Fatal(err)
			}
			var response pv.Message
			_, readErr := protoio.NewDelimitedReader(conn, 16*1024).ReadMsg(&response)
			if readErr == nil {
				signed := response.GetSignedVoteResponse()
				if signed == nil || signed.Error == nil || len(signed.Vote.Signature) != 0 {
					t.Fatal("directory-sync failure published a signature", signed)
				}
			}
			if err := os.Chmod(directory, 0700); err != nil {
				t.Fatal(err)
			}
			latch := filepath.Join(store, "validator-supervisor.halted")
			deadline := time.Now().Add(5 * time.Second)
			for time.Now().Before(deadline) {
				if _, err := os.Stat(latch); err == nil {
					break
				}
				time.Sleep(20 * time.Millisecond)
			}
			latched, err := os.ReadFile(latch)
			if err != nil {
				t.Fatal("signing-state uncertainty did not durably halt the supervisor", err)
			}
			fence, err := os.ReadFile(fencePath(state))
			if err != nil {
				t.Fatal("the failed directory fsync left no signer fence", err)
			}
			stopTestProcess(t, supervisor)
			start()
			time.Sleep(400 * time.Millisecond)
			after, _ := os.ReadFile(state)
			keyAfter, _ := os.ReadFile(key)
			retainedLatch, _ := os.ReadFile(latch)
			retainedFence, _ := os.ReadFile(fencePath(state))
			incarnations, _ := os.ReadFile(starts)
			if !bytes.Equal(before, after) || !bytes.Equal(keyBefore, keyAfter) || !bytes.Equal(latched, retainedLatch) || !bytes.Equal(fence, retainedFence) {
				t.Fatal("supervisor restart changed uncertain HRS, key or terminal evidence")
			}
			if strings.Count(string(incarnations), "start\n") != 1 {
				t.Fatalf("automatically restarted uncertain signing authority: %q", incarnations)
			}
		})
	}
}

// The real signer refuses an unsafe signing state with exit 3 (here a lost domains log), and the
// supervisor latches: Comet started once with the first pair never starts again, across a
// supervisor restart too, and the HRS is untouched (RECOV-8.2-3).
func TestSupervisorLatchesRefusedSigningState(t *testing.T) {
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Fatal(err)
	}
	binary := signerBinary(t)
	_, key, state := filePV(t)
	if err := os.Remove(domainsLogOf(state)); err != nil {
		t.Fatal(err)
	}
	before := readFile(t, state)
	root := shortTemp(t)
	home, store := filepath.Join(root, "comet"), filepath.Join(root, "app")
	for _, path := range []string{filepath.Join(home, "config"), store} {
		if err := os.MkdirAll(path, 0700); err != nil {
			t.Fatal(err)
		}
	}
	controlPath := control(t, func(request map[string]any) any { return snapshot(request["op"] != "begin_session") })
	if err := os.Symlink(controlPath, filepath.Join(store, "checkpoint-trust.sock")); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(home, "run"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, "config", "config.toml"), validatorConfig("unix://run/signer.sock"), 0600); err != nil {
		t.Fatal(err)
	}
	genesis, _ := json.Marshal(map[string]any{"chain_id": chain})
	if err := os.WriteFile(filepath.Join(home, "config", "genesis.json"), genesis, 0600); err != nil {
		t.Fatal(err)
	}
	starts := filepath.Join(root, "comet-starts")
	cometCommand, _ := json.Marshal([]string{"/bin/sh", "-c", "echo start >> \"$COMET_STARTS\"; exec sleep 300"})
	environment := supervisorEnvironment(home, store, key, state,
		"ETNA_SIGNER_BIN="+binary, "ETNA_COMET_COMMAND_JSON="+string(cometCommand), "COMET_STARTS="+starts,
		cometManifest(t, root, "/bin/sh"))
	logs, err := os.Create(filepath.Join(root, "supervisor.log"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		logs.Close()
		if t.Failed() {
			contents, _ := os.ReadFile(logs.Name())
			t.Logf("supervisor output: %s", contents)
		}
	})
	start := func() *exec.Cmd {
		child := exec.Command(python, "../../script/etna_validator.py")
		child.Env, child.Stdout, child.Stderr = environment, logs, logs
		if err := child.Start(); err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { stopTestProcess(t, child) })
		return child
	}
	latch := filepath.Join(store, "validator-supervisor.halted")
	latched := func() bool { _, err := os.Stat(latch); return err == nil }
	supervisor := start()
	deadline := time.Now().Add(5 * time.Second)
	for !latched() && time.Now().Before(deadline) {
		time.Sleep(20 * time.Millisecond)
	}
	if !latched() {
		t.Fatal("refused signing state did not latch the supervisor")
	}
	if contents, _ := os.ReadFile(logs.Name()); !bytes.Contains(contents, []byte("domains log")) {
		t.Fatalf("signer did not report the lost domains log: %s", contents)
	}
	time.Sleep(300 * time.Millisecond)
	if err := supervisor.Process.Signal(syscall.Signal(0)); err != nil {
		t.Fatal("latched supervisor exited", err)
	}
	evidence := readFile(t, latch)
	stopTestProcess(t, supervisor)
	start()
	time.Sleep(400 * time.Millisecond)
	if incarnations, _ := os.ReadFile(starts); strings.Count(string(incarnations), "start\n") != 1 {
		t.Fatalf("Comet started %q times", incarnations)
	}
	if !bytes.Equal(readFile(t, latch), evidence) || !bytes.Equal(readFile(t, state), before) {
		t.Fatal("restart changed the latch or the HRS")
	}
	if _, err := os.Lstat(domainsLogOf(state)); !os.IsNotExist(err) {
		t.Fatal("a lost domains log was recreated")
	}
	// The supervisor's marker lands where this signer looks for it (TestServeRefusalMatrix), so
	// a fresh app store cannot hide the exit 3.
	if marker, err := os.ReadFile(unsafeMarkerPath(domainsLogOf(state), chain)); err != nil || !bytes.Contains(marker, []byte("unsafe signing state")) {
		t.Fatalf("no signer-unsafe marker beside the domains log: %q %v", marker, err)
	}
}

// heightVote is voteRequest at height, round 0, for the block whose hash repeats block.
func heightVote(typ tm.SignedMsgType, height int64, block byte) pv.Message {
	request := voteRequest(typ, 0, false)
	vote := request.GetSignVoteRequest().Vote
	vote.Height = height
	vote.BlockID.Hash = bytes.Repeat([]byte{block}, 32)
	return request
}

// A signer crash outside a supervisor stop restarts the pair from the same HRS, with no latch
// (SYNC-9-14). The supervisor reaps the dead signer and Comet, then starts a new real signer on
// the same state path together with Comet; the signer reconnects over Noise with a fresh closed
// session (SYNC-9-12). The new signer holds the key and state flocks, so the old one released
// them (RECOV-8.2-2), and it continues from the signer state on disk (RECOV-8.2-1, SYNC-9-13).
// The restarted Comet is a new process on the same store instance, and this home has no WAL
// that could replay the last signed height, so the new session takes the durable floor H + 1
// before it is admitted (RECOV-8.2-2): every request at H5 is refused, and H6 signs once the
// app makes it eligible.
//   - sigkill: SIGKILL after a released prevote.
//   - write-panic (exit 2): the state directory loses write permission, so the signer cannot
//     create the precommit's inflight marker and panics, as a failed write does, before any
//     fsync, write or signature. The state on disk is unchanged, and the withheld precommit at
//     H5 stays refused after the restart.
func TestSupervisorRestartsCrashedSignerFromItsHRS(t *testing.T) {
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Fatal(err)
	}
	binary := signerBinary(t)
	for _, crash := range []string{"sigkill", "write-panic"} {
		t.Run(crash, func(t *testing.T) {
			if crash == "write-panic" && os.Geteuid() == 0 {
				t.Skip("root bypasses the directory-write permission fault")
			}
			_, key, state := filePV(t)
			var eligible atomic.Uint64
			eligible.Store(5)
			controlPath := control(t, func(request map[string]any) any { return snapshotAt(request["op"] != "begin_session", eligible.Load()) })
			root := shortTemp(t)
			home, store := filepath.Join(root, "comet"), filepath.Join(root, "app")
			for _, path := range []string{filepath.Join(home, "config"), store} {
				if err := os.MkdirAll(path, 0700); err != nil {
					t.Fatal(err)
				}
			}
			if err := os.Symlink(controlPath, filepath.Join(store, "checkpoint-trust.sock")); err != nil {
				t.Fatal(err)
			}
			listener, laddr, transportKey := noiseComet(t, home, root)
			if err := os.WriteFile(filepath.Join(home, "config", "config.toml"), validatorConfig(laddr), 0600); err != nil {
				t.Fatal(err)
			}
			genesis, _ := json.Marshal(map[string]any{"chain_id": chain})
			if err := os.WriteFile(filepath.Join(home, "config", "genesis.json"), genesis, 0600); err != nil {
				t.Fatal(err)
			}
			starts, pids := filepath.Join(root, "comet-starts"), filepath.Join(root, "signer-pids")
			cometCommand, _ := json.Marshal([]string{python, "-c", "import os,time; open(os.environ['COMET_STARTS'],'a').write('start\\n'); time.sleep(300)"})
			// Record each real signer's PID; exec keeps it.
			signerCommand, _ := json.Marshal([]string{"/bin/sh", "-c", `echo $$ >> "$SIGNER_PIDS"; exec "$0" "$@"`, binary})
			environment := supervisorEnvironment(home, store, key, state, "ETNA_SIGNER_COMMAND_JSON="+string(signerCommand),
				"ETNA_COMET_COMMAND_JSON="+string(cometCommand), "COMET_STARTS="+starts, "SIGNER_PIDS="+pids,
				transportKey, cometManifest(t, root, python))
			logs, err := os.Create(filepath.Join(root, "supervisor.log"))
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				logs.Close()
				if t.Failed() {
					contents, _ := os.ReadFile(logs.Name())
					t.Logf("supervisor output: %s", contents)
				}
			})
			supervisor := exec.Command(python, "../../script/etna_validator.py")
			supervisor.Env, supervisor.Stdout, supervisor.Stderr = environment, logs, logs
			if err := supervisor.Start(); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { stopTestProcess(t, supervisor) })
			lines := func(path string) []string {
				raw, _ := os.ReadFile(path)
				return strings.Fields(string(raw))
			}
			waitFor := func(description string, condition func() bool) {
				t.Helper()
				deadline := time.Now().Add(10 * time.Second)
				for !condition() && time.Now().Before(deadline) {
					time.Sleep(20 * time.Millisecond)
				}
				if !condition() {
					t.Fatal(description)
				}
			}
			conn := acceptSigner(t, listener)
			sigA, remote := released(signerExchange(t, conn, heightVote(tm.PrevoteType, 5, 1)))
			if remote != nil || len(sigA) != 65 {
				t.Fatalf("first trusted prevote failed: %v", remote)
			}
			signedA := readFile(t, state)
			directory := filepath.Dir(state)
			if crash == "sigkill" {
				pid, err := strconv.Atoi(lines(pids)[0])
				if err != nil {
					t.Fatal(err)
				}
				if err := syscall.Kill(pid, syscall.SIGKILL); err != nil {
					t.Fatal(err)
				}
			} else {
				if err := os.Chmod(directory, 0500); err != nil {
					t.Fatal(err)
				}
				t.Cleanup(func() { os.Chmod(directory, 0700) })
				request := heightVote(tm.PrecommitType, 5, 1)
				if err := conn.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
					t.Fatal(err)
				}
				if _, err := protoio.NewDelimitedWriter(conn).WriteMsg(&request); err != nil {
					t.Fatal(err)
				}
				var reply pv.Message
				if _, err := protoio.NewDelimitedReader(conn, 16*1024).ReadMsg(&reply); err == nil {
					t.Fatal("a failed stock state write answered the transport", reply)
				}
			}
			waitFor("the supervisor did not restart the crashed signer", func() bool { return len(lines(pids)) == 2 })
			if crash == "write-panic" {
				if contents, _ := os.ReadFile(logs.Name()); !bytes.Contains(contents, []byte("panic")) || !bytes.Contains(contents, []byte("exit status 2")) {
					t.Fatalf("the signer did not exit 2 from a write panic: %s", contents)
				}
				if !bytes.Equal(readFile(t, state), signedA) {
					t.Fatal("a failed stock state write changed the HRS on disk")
				}
				if err := os.Chmod(directory, 0700); err != nil {
					t.Fatal(err)
				}
			}
			first, _ := strconv.Atoi(lines(pids)[0])
			if err := syscall.Kill(first, 0); err != syscall.ESRCH {
				t.Fatalf("the crashed signer %d was not reaped before its replacement: %v", first, err)
			}
			waitFor("Comet did not restart with the new signer", func() bool { return len(lines(starts)) == 2 })
			conn = acceptSigner(t, listener)
			refused := func(request pv.Message, reason string) {
				t.Helper()
				if signature, remote := released(signerExchange(t, conn, request)); remote == nil || len(signature) != 0 || !strings.Contains(remote.Description, reason) {
					t.Fatalf("restarted signer did not refuse with %q: %v", reason, remote)
				}
			}
			for _, request := range []pv.Message{heightVote(tm.PrevoteType, 5, 1), heightVote(tm.PrevoteType, 5, 3), heightVote(tm.PrecommitType, 5, 1), heightVote(tm.PrecommitType, 5, 0)} {
				refused(request, "durable floor")
			}
			refused(heightVote(tm.PrevoteType, 4, 1), "not the eligible height 5")
			if persisted := privval.LoadFilePV(key, state).LastSignState; persisted.Height != 5 || persisted.Step != 2 || !bytes.Equal(persisted.Signature, sigA) {
				t.Fatalf("persisted HRS %d/%d", persisted.Height, persisted.Step)
			}
			eligible.Store(6)
			if signature, remote := released(signerExchange(t, conn, heightVote(tm.PrecommitType, 6, 1))); remote != nil || len(signature) == 0 {
				t.Fatalf("restart did not sign above its floor: %v", remote)
			}
			if len(lines(pids)) != 2 {
				t.Fatalf("the restarted signer did not keep the flocks: %q", lines(pids))
			}
			if _, err := os.Lstat(filepath.Join(store, "validator-supervisor.halted")); !os.IsNotExist(err) {
				t.Fatal("an ordinary crash latched the supervisor", err)
			}
		})
	}
}

func stopTestProcess(t *testing.T, child *exec.Cmd) {
	t.Helper()
	if child.ProcessState != nil {
		return
	}
	child.Process.Signal(syscall.SIGTERM)
	done := make(chan error, 1)
	go func() { done <- child.Wait() }()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		child.Process.Kill()
		<-done
		t.Error("supervised process did not stop")
	}
}
