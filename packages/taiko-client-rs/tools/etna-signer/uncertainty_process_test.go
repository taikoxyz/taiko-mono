package main

import (
	"bytes"
	"encoding/json"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// The supervisor is stopped before the actual directory fsync failure, then
// SIGKILLed before it can write any app latch. The stock FilePV/transport child
// runs production synchronization and shutdown; only its sync scheduling is held.
// The failed fsync leaves the signer's fence, which alone makes the restarted
// supervisor halt.
func TestSupervisorSIGKILLBeforeHaltRetainsSignerFence(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root bypasses the directory-read permission fault")
	}
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Fatal(err)
	}
	_, key, state := filePV(t)
	root := shortTemp(t)
	home, store := filepath.Join(root, "comet"), filepath.Join(root, "app")
	for _, path := range []string{filepath.Join(home, "config"), store} {
		if err := os.MkdirAll(path, 0700); err != nil {
			t.Fatal(err)
		}
	}
	fixture := shutdownFixture{
		Key: key, State: state, Log: domainsLogOf(state), Control: control(t, func(request map[string]any) any { return snapshot(request["op"] != "begin_session") }),
		Comet: filepath.Join(root, "comet.sock"), Entered: filepath.Join(root, "entered"), Release: filepath.Join(root, "release"),
	}
	if err := os.Symlink(fixture.Control, filepath.Join(store, "checkpoint-trust.sock")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, "config", "config.toml"), []byte("priv_validator_laddr = \"tcp://127.0.0.1:1\"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	genesis, _ := json.Marshal(map[string]any{"chain_id": chain})
	os.WriteFile(filepath.Join(home, "config", "genesis.json"), genesis, 0600)
	config, _ := json.Marshal(fixture)
	configPath := filepath.Join(root, "fixture.json")
	os.WriteFile(configPath, config, 0600)
	raw, err := net.ListenUnix("unix", &net.UnixAddr{Name: fixture.Comet, Net: "unix"})
	if err != nil {
		t.Fatal(err)
	}
	raw.SetDeadline(time.Now().Add(10 * time.Second))
	listener := privval.NewUnixListener(raw)
	defer listener.Close()
	starts, cometPID := filepath.Join(root, "starts"), filepath.Join(root, "comet.pid")
	cometCommand, _ := json.Marshal([]string{python, "-c", "import os,time; open(os.environ['COMET_PID'],'w').write(str(os.getpid())); open(os.environ['COMET_STARTS'],'a').write('start\\n'); time.sleep(300)"})
	signerCommand, _ := json.Marshal([]string{os.Args[0], "-test.run=^TestSignerSignalDuringSyncHelper$", "--"})
	environment := supervisorEnvironment(home, store, key, state,
		"ETNA_SIGNER_COMMAND_JSON="+string(signerCommand), "ETNA_SIGNER_SHUTDOWN_CONFIG="+configPath,
		"ETNA_COMET_COMMAND_JSON="+string(cometCommand), "COMET_STARTS="+starts, "COMET_PID="+cometPID)
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
	waitFor := func(description string, condition func() bool) {
		t.Helper()
		deadline := time.Now().Add(5 * time.Second)
		for !condition() && time.Now().Before(deadline) {
			time.Sleep(10 * time.Millisecond)
		}
		if !condition() {
			t.Fatal(description)
		}
	}
	supervisor := start()
	orphanComet := false
	t.Cleanup(func() {
		os.Chmod(filepath.Dir(state), 0700)
		os.WriteFile(fixture.Release, nil, 0600)
		supervisor.Process.Signal(syscall.SIGCONT)
		if orphanComet {
			if raw, err := os.ReadFile(cometPID); err == nil {
				if pid, err := strconv.Atoi(string(raw)); err == nil {
					syscall.Kill(pid, syscall.SIGKILL)
				}
			}
		}
	})
	conn := acceptSigner(t, listener)
	request := voteRequest(tm.PrevoteType, 0, false)
	if _, err := protoio.NewDelimitedWriter(conn).WriteMsg(&request); err != nil {
		t.Fatal(err)
	}
	waitFor("signer did not reach post-FilePV synchronization", func() bool { _, err := os.Stat(fixture.Entered); return err == nil })
	if err := supervisor.Process.Signal(syscall.SIGSTOP); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(filepath.Dir(state), 0300); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chmod(filepath.Dir(state), 0700) })
	if err := os.WriteFile(fixture.Release, nil, 0600); err != nil {
		t.Fatal(err)
	}
	waitFor("signer did not report actual fsync failure", func() bool {
		contents, _ := os.ReadFile(logs.Name())
		return bytes.Contains(contents, []byte(errSigningStateUnsafe.Error()))
	})
	if err := supervisor.Process.Kill(); err != nil {
		t.Fatal(err)
	}
	if err := supervisor.Wait(); err == nil {
		t.Fatal("supervisor was not SIGKILLed")
	}
	orphanComet = true
	pidBytes, err := os.ReadFile(cometPID)
	if err != nil {
		t.Fatal(err)
	}
	pid, err := strconv.Atoi(string(pidBytes))
	if err != nil {
		t.Fatal(err)
	}
	if err := syscall.Kill(pid, syscall.SIGTERM); err != nil {
		t.Fatal(err)
	}
	orphanComet = false
	os.Chmod(filepath.Dir(state), 0700)
	fence, err := os.ReadFile(fencePath(state))
	if err != nil {
		t.Fatal("the failed directory fsync left no signer fence", err)
	}
	latch := filepath.Join(store, "validator-supervisor.halted")
	if _, err := os.Lstat(latch); !os.IsNotExist(err) {
		t.Fatal("supervisor was not killed before its app latch")
	}
	before, _ := os.ReadFile(state)
	keyBefore, _ := os.ReadFile(key)
	// Wait until our orphaned test child has released its inherited component lease.
	owner := filepath.Join(root, ".comet.etna-owner.lock")
	waitFor("killed supervisor's child retained ownership", func() bool {
		file, err := ownerLock(owner)
		if err != nil {
			return false
		}
		file.Close()
		return true
	})
	restarted := start()
	waitFor("restart did not halt on signer-owned evidence", func() bool { _, err := os.Stat(latch); return err == nil })
	if err := restarted.Process.Signal(syscall.Signal(0)); err != nil {
		t.Fatal("halted restart did not retain its supervisor", err)
	}
	after, _ := os.ReadFile(state)
	keyAfter, _ := os.ReadFile(key)
	retained, _ := os.ReadFile(fencePath(state))
	incarnations, _ := os.ReadFile(starts)
	if string(incarnations) != "start\n" || !bytes.Equal(before, after) || !bytes.Equal(keyBefore, keyAfter) || !bytes.Equal(fence, retained) {
		t.Fatalf("restart changed signing authority or rearmed Comet: %q", incarnations)
	}
}

// A plain crash needs no fence (RECOV-8.2-3: uncertain means a failed fsync). The re-executed
// helper is SIGKILLed inside its state fsync, after stock FilePV synchronously wrote and renamed
// the new HRS, before the transport received any signature. The restarted real signer finds no
// fence and continues from the HRS on disk: the identical step returns the stored signature (a
// fresh one only if the rename was lost, which needs a host crash), a different block at the
// same HRS is refused as conflicting data, and the next height signs (RECOV-8.2-1, SYNC-9-13).
func TestSIGKILLMidSignRestartsWithoutFence(t *testing.T) {
	_, key, state := filePV(t)
	root := shortTemp(t)
	trust := control(t, func(request map[string]any) any { return snapshot(request["op"] != "begin_session") })
	fixture := shutdownFixture{
		Key: key, State: state, Log: domainsLogOf(state), Control: trust,
		Comet: filepath.Join(root, "comet.sock"), Entered: filepath.Join(root, "entered"), Release: filepath.Join(root, "release"),
	}
	listener := listenComet(t, fixture.Comet)
	config, _ := json.Marshal(fixture)
	path := filepath.Join(root, "config.json")
	if err := os.WriteFile(path, config, 0600); err != nil {
		t.Fatal(err)
	}
	logs := signerLogs(t)
	helper := exec.Command(os.Args[0], "-test.run=^TestSignerSignalDuringSyncHelper$")
	helper.Env = append(os.Environ(), "ETNA_SIGNER_SHUTDOWN_CONFIG="+path)
	helper.Stdout, helper.Stderr = logs, logs
	if err := helper.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { stopTestProcess(t, helper) })
	conn := acceptSigner(t, listener)
	request := voteRequest(tm.PrevoteType, 0, false)
	if _, err := protoio.NewDelimitedWriter(conn).WriteMsg(&request); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(fixture.Entered); err == nil {
			break
		}
		time.Sleep(time.Millisecond)
	}
	if _, err := os.Stat(fixture.Entered); err != nil {
		t.Fatal("helper did not reach its state fsync", err)
	}
	if err := helper.Process.Kill(); err != nil {
		t.Fatal(err)
	}
	if err := helper.Wait(); err == nil {
		t.Fatal("helper was not SIGKILLed")
	}
	if err := conn.SetReadDeadline(time.Now().Add(3 * time.Second)); err != nil {
		t.Fatal(err)
	}
	var reply pv.Message
	if _, err := protoio.NewDelimitedReader(conn, 16*1024).ReadMsg(&reply); err == nil {
		t.Fatal("the transport received a reply before the state fsync completed", reply)
	}
	if _, err := os.Lstat(fencePath(state)); !os.IsNotExist(err) {
		t.Fatal("a crash left a signer fence", err)
	}
	stored := privval.LoadFilePV(key, state).LastSignState
	listener.Close()
	args := []string{"--comet-signer-addr", "unix://" + fixture.Comet, "--trust-socket", trust, "--chain-id", chain, "--priv-key", key, "--priv-state", state, "--domains-log", domainsLogOf(state)}
	_, conn = serveDirectly(t, listenComet(t, fixture.Comet), logs, args)
	signature, remote := released(signerExchange(t, conn, voteRequest(tm.PrevoteType, 0, false)))
	persisted := privval.LoadFilePV(key, state).LastSignState
	if remote != nil || len(signature) != 65 || persisted.Height != 1 || !bytes.Equal(signature, persisted.Signature) {
		t.Fatalf("restart did not sign the identical step from its HRS: %v", remote)
	}
	if stored.Height == 1 && !bytes.Equal(signature, stored.Signature) {
		t.Fatal("restart re-signed a step whose signature the disk already held")
	}
	if signature, remote = released(signerExchange(t, conn, voteRequest(tm.PrevoteType, 0, true))); remote == nil || !strings.Contains(remote.Description, "conflicting data") || len(signature) != 0 {
		t.Fatalf("restart signed a different block at the same HRS: %v", remote)
	}
	next := voteRequest(tm.PrevoteType, 0, false)
	next.GetSignVoteRequest().Vote.Height = 2
	signature, remote = released(signerExchange(t, conn, next))
	if persisted = privval.LoadFilePV(key, state).LastSignState; remote != nil || len(signature) != 65 || persisted.Height != 2 || !bytes.Equal(signature, persisted.Signature) {
		t.Fatalf("restart did not sign the next height: %v", remote)
	}
	if _, err := os.Lstat(fencePath(state)); !os.IsNotExist(err) {
		t.Fatal("restarted signing wrote a fence", err)
	}
}
