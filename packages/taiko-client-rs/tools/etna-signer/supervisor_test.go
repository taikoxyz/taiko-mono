package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
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
			ready := snapshot(true)
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
			raw, err := net.ListenTCP("tcp", &net.TCPAddr{IP: net.ParseIP("127.0.0.1")})
			if err != nil {
				t.Fatal(err)
			}
			listener := privval.NewTCPListener(raw, ed25519.GenPrivKey())
			defer listener.Close()
			if err := raw.SetDeadline(time.Now().Add(10 * time.Second)); err != nil {
				t.Fatal(err)
			}
			config := fmt.Sprintf("priv_validator_laddr = %q\n", "tcp://"+raw.Addr().String())
			if err := os.WriteFile(filepath.Join(home, "config", "config.toml"), []byte(config), 0600); err != nil {
				t.Fatal(err)
			}
			genesis, _ := json.Marshal(map[string]any{"chain_id": chain})
			if err := os.WriteFile(filepath.Join(home, "config", "genesis.json"), genesis, 0600); err != nil {
				t.Fatal(err)
			}
			starts := filepath.Join(root, "comet-starts")
			cometCommand, _ := json.Marshal([]string{python, "-c", "import os,time; open(os.environ['COMET_STARTS'],'a').write('start\\n'); time.sleep(300)"})
			environment := supervisorEnvironment(home, store, key, state,
				"ETNA_SIGNER_BIN="+binary, "ETNA_COMET_COMMAND_JSON="+string(cometCommand), "COMET_STARTS="+starts)
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
	if err := os.WriteFile(filepath.Join(home, "config", "config.toml"), []byte("priv_validator_laddr = \"tcp://127.0.0.1:1\"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	genesis, _ := json.Marshal(map[string]any{"chain_id": chain})
	if err := os.WriteFile(filepath.Join(home, "config", "genesis.json"), genesis, 0600); err != nil {
		t.Fatal(err)
	}
	starts := filepath.Join(root, "comet-starts")
	cometCommand, _ := json.Marshal([]string{"/bin/sh", "-c", "echo start >> \"$COMET_STARTS\"; exec sleep 300"})
	environment := supervisorEnvironment(home, store, key, state,
		"ETNA_SIGNER_BIN="+binary, "ETNA_COMET_COMMAND_JSON="+string(cometCommand), "COMET_STARTS="+starts)
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
