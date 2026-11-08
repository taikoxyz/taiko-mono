package main

import (
	"bytes"
	"encoding/json"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// The supervisor is stopped before the actual directory fsync failure, then
// SIGKILLed before it can write any app latch. The stock FilePV/transport child
// runs production synchronization and shutdown; only its sync scheduling is held.
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
	fence, err := os.ReadFile(uncertaintyPath(state))
	if err != nil {
		t.Fatal("SIGKILL lost pre-armed signer evidence", err)
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
	retained, _ := os.ReadFile(uncertaintyPath(state))
	incarnations, _ := os.ReadFile(starts)
	if string(incarnations) != "start\n" || !bytes.Equal(before, after) || !bytes.Equal(keyBefore, keyAfter) || !bytes.Equal(fence, retained) {
		t.Fatalf("restart changed signing authority or rearmed Comet: %q", incarnations)
	}
}
