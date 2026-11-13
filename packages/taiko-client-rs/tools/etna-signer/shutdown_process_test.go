package main

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/libs/log"
	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

type shutdownFixture struct {
	Key, State, Log, Control, Comet, Entered, Release string
}

// The child runs the production shutdown path with stock transport and FilePV.
// Only scheduling is controlled: state synchronization waits until the parent has
// sent SIGTERM and observed the transport closing, then uses the actual filesystem.
func TestSignerSignalDuringSyncHelper(t *testing.T) {
	path := os.Getenv("ETNA_SIGNER_SHUTDOWN_CONFIG")
	if path == "" {
		return
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var fixture shutdownFixture
	if err := json.Unmarshal(raw, &fixture); err != nil {
		t.Fatal(err)
	}
	signer, release, err := openSigningState(chain, fixture.Key, fixture.State, fixture.Log)
	if err != nil {
		t.Fatal(err)
	}
	defer release()
	signer.syncFile = func(file *os.File) error {
		// Hold the state's fsync, after stock FilePV wrote; the marker's runs before that write.
		if strings.HasSuffix(file.Name(), inflightSuffix) {
			return file.Sync()
		}
		if err := os.WriteFile(fixture.Entered, nil, 0600); err != nil {
			return err
		}
		for {
			if _, err := os.Stat(fixture.Release); err == nil {
				return file.Sync()
			}
			time.Sleep(time.Millisecond)
		}
	}
	gate := newGate(fixture.Control, time.Second)
	endpoint := privval.NewSignerDialerEndpoint(log.NewTMLogger(os.Stderr), gate.dialer(privval.DialUnixFn(fixture.Comet)))
	server := privval.NewSignerServer(endpoint, chain, signer)
	server.SetRequestHandler(gate.handle)
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGTERM)
	defer signal.Stop(signals)
	if err := server.Start(); err != nil {
		t.Fatal(err)
	}
	if err := awaitSignerShutdown(server, gate, signals); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

// Choosing the normal signal branch must not hide a persistence error discovered
// by an in-flight handler. A healthy request interrupted by the same signal still
// shuts down successfully rather than being misclassified as fatal, and leaves no fence.
func TestSignerSignalWaitsForInFlightPersistence(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root bypasses the directory-read permission fault")
	}
	for _, fault := range []bool{false, true} {
		t.Run(fmt.Sprintf("directory-fault=%v", fault), func(t *testing.T) {
			_, key, state := filePV(t)
			root := shortTemp(t)
			fixture := shutdownFixture{
				Key: key, State: state, Log: domainsLogOf(state), Control: control(t, func(request map[string]any) any { return snapshot(request["op"] != "begin_session") }),
				Comet: filepath.Join(root, "comet.sock"), Entered: filepath.Join(root, "entered"), Release: filepath.Join(root, "release"),
			}
			raw, err := net.ListenUnix("unix", &net.UnixAddr{Name: fixture.Comet, Net: "unix"})
			if err != nil {
				t.Fatal(err)
			}
			if err := raw.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
				t.Fatal(err)
			}
			listener := privval.NewUnixListener(raw)
			defer listener.Close()
			config, _ := json.Marshal(fixture)
			path := filepath.Join(root, "config.json")
			if err := os.WriteFile(path, config, 0600); err != nil {
				t.Fatal(err)
			}
			logs, err := os.Create(filepath.Join(root, "child.log"))
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { logs.Close() })
			child := exec.Command(os.Args[0], "-test.run=^TestSignerSignalDuringSyncHelper$")
			child.Env = append(os.Environ(), "ETNA_SIGNER_SHUTDOWN_CONFIG="+path)
			child.Stdout, child.Stderr = logs, logs
			if err := child.Start(); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { stopTestProcess(t, child) })
			t.Cleanup(func() { os.WriteFile(fixture.Release, nil, 0600) })
			conn := acceptSigner(t, listener)
			request := voteRequest(tm.PrevoteType, 0, false)
			if _, err := protoio.NewDelimitedWriter(conn).WriteMsg(&request); err != nil {
				t.Fatal(err)
			}
			deadline := time.Now().Add(3 * time.Second)
			for time.Now().Before(deadline) {
				if _, err := os.Stat(fixture.Entered); err == nil {
					break
				}
				time.Sleep(time.Millisecond)
			}
			if _, err := os.Stat(fixture.Entered); err != nil {
				t.Fatal("signer did not reach the state-sync boundary", err)
			}
			if fault {
				if err := os.Chmod(filepath.Dir(state), 0300); err != nil {
					t.Fatal(err)
				}
				t.Cleanup(func() { os.Chmod(filepath.Dir(state), 0700) })
			}
			if err := child.Process.Signal(syscall.SIGTERM); err != nil {
				t.Fatal(err)
			}
			if err := conn.SetReadDeadline(time.Now().Add(3 * time.Second)); err != nil {
				t.Fatal(err)
			}
			var response pv.Message
			if _, err := protoio.NewDelimitedReader(conn, 16*1024).ReadMsg(&response); err == nil {
				t.Fatal("request completed before the controlled sync was released")
			} else if network, ok := err.(net.Error); ok && network.Timeout() {
				t.Fatal("signal did not begin transport shutdown", err)
			}
			if err := os.WriteFile(fixture.Release, nil, 0600); err != nil {
				t.Fatal(err)
			}
			done := make(chan error, 1)
			go func() { done <- child.Wait() }()
			select {
			case err := <-done:
				contents, _ := os.ReadFile(logs.Name())
				if fault && (err == nil || !strings.Contains(string(contents), errSigningStateUnsafe.Error())) {
					t.Fatalf("signal hid in-flight persistence uncertainty: exit %v\n%s", err, contents)
				}
				if !fault && err != nil {
					t.Fatalf("healthy signal shutdown became fatal: %v\n%s", err, contents)
				}
				// Only the failed fsync writes the fence; a signal during a healthy one does not.
				if _, err := os.Lstat(fencePath(state)); fault != (err == nil) {
					t.Fatalf("directory fault %v, fence: %v", fault, err)
				}
			case <-time.After(5 * time.Second):
				child.Process.Kill()
				<-done
				t.Fatal("signer did not finish shutdown after sync completed")
			}
		})
	}
}
