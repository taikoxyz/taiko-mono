package main

import (
	"bytes"
	"encoding/json"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"sync/atomic"
	"testing"

	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// ACCEPTANCE §2.4: signers keep HRS state through crashes, restarts and failover, without reset
// or rollback. The real binary serves the official privval wire to a Comet-owned Unix listener,
// with a trust peer that begins closed sessions and reports them Ready, and a supervisor channel
// that reports that listener's process and its home's store instance.
//
//  1. Host 1, set up with keygen, init-domains-log and init-state in separate key, hrs/ and
//     domains/ directories, signs prevote H5 R0 for block A, bound to host 1's store instance.
//  2. After a SIGKILL and a restart on the same home, same-height continuity is not established,
//     so the new session takes the durable floor 6 before it is admitted: the identical vote,
//     block B at the same HRS and H4 are all refused, and the HRS is unchanged (RECOV-8.2-1/2,
//     SYNC-9-13).
//  3. Failover is operational practice (RECOV-8.2-6): with host 1 stopped, its key, state and
//     log move byte for byte to host 2, the state and the log again in separate directories,
//     and host 1's state is removed, so host 1 refuses to serve again. Host 2's home has its own
//     store instance; the floor stays 6, H5 stays refused, and host 2 signs precommit H6 once
//     the app makes H6 eligible.
//  4. A failover that moves the state without its log, or the log without its state, is lost
//     signing state: exit 3, nothing created (RECOV-8.2-3). The log detects absence only; it
//     cannot detect a state restored from a backup, which is forbidden.
func TestHRSSurvivesCrashRestartAndFailover(t *testing.T) {
	binary := signerBinary(t)
	var eligible atomic.Uint64
	eligible.Store(5)
	trust := control(t, func(request map[string]any) any { return snapshotAt(request["op"] != "begin_session", eligible.Load()) })
	var instance atomic.Value
	instance.Store(testInstance)
	supervisor := serveSupervisor(t, func() *cometProcess { return reportsComet(instance.Load().(string))() })
	logs := signerLogs(t)
	type host struct{ key, state, log string }
	base := t.TempDir()
	newHost := func(name string) host {
		dir := filepath.Join(base, name)
		h := host{filepath.Join(dir, "key", "key.json"), filepath.Join(dir, "hrs", chain+".json"), filepath.Join(dir, "domains", "domains.log")}
		for _, path := range []string{h.key, h.state, h.log} {
			if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
				t.Fatal(err)
			}
		}
		return h
	}
	command := func(args ...string) {
		t.Helper()
		if out, err := exec.Command(binary, args...).CombinedOutput(); err != nil {
			t.Fatalf("%s: %v %s", args[0], err, out)
		}
	}
	serve := func(h host) (*exec.Cmd, net.Conn) {
		t.Helper()
		socket := filepath.Join(shortTemp(t), "comet.sock")
		args := []string{"--comet-signer-addr", "unix://" + socket, "--trust-socket", trust, "--supervisor-socket", supervisor, "--chain-id", chain, "--priv-key", h.key, "--priv-state", h.state, "--domains-log", h.log}
		return serveDirectly(t, listenComet(t, socket), logs, args)
	}
	kill := func(child *exec.Cmd) {
		t.Helper()
		if err := child.Process.Kill(); err != nil {
			t.Fatal(err)
		}
		if err := child.Wait(); err == nil {
			t.Fatal("signer was not SIGKILLed")
		}
	}
	sign := func(conn net.Conn, request pv.Message) []byte {
		t.Helper()
		signature, remote := released(signerExchange(t, conn, request))
		if remote != nil || len(signature) == 0 {
			t.Fatalf("trusted signing request refused: %v", remote)
		}
		return signature
	}
	refused := func(conn net.Conn, request pv.Message, reason string) {
		t.Helper()
		if signature, remote := released(signerExchange(t, conn, request)); remote == nil || len(signature) != 0 || !strings.Contains(remote.Description, reason) {
			t.Fatalf("signed instead of refusing with %q: %v", reason, remote)
		}
	}
	// The answers of a fenced signer whose HRS is prevote H5 R0 for A.
	fenced := func(conn net.Conn) {
		t.Helper()
		refused(conn, heightVote(tm.PrevoteType, 5, 1), "durable floor")
		refused(conn, heightVote(tm.PrevoteType, 5, 3), "durable floor")
		refused(conn, heightVote(tm.PrecommitType, 5, 1), "durable floor")
		refused(conn, heightVote(tm.PrevoteType, 4, 1), "not the eligible height 5")
	}
	// hrs is the HRS part of a state: the floor and binding may change, never the HRS.
	hrs := func(raw []byte) string {
		t.Helper()
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(raw, &fields); err != nil {
			t.Fatal(err)
		}
		return string(fields["height"]) + string(fields["round"]) + string(fields["step"]) + string(fields["signature"]) + string(fields["signbytes"])
	}
	floor := func(raw []byte) string {
		t.Helper()
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(raw, &fields); err != nil {
			t.Fatal(err)
		}
		return string(fields["floor"]) + " " + string(fields["store_instance"])
	}

	// 1. Host 1 signs prevote H5 R0 A.
	h1 := newHost("host1")
	command("keygen", "--priv-key", h1.key)
	command("init-domains-log", "--domains-log", h1.log)
	command("init-state", "--chain-id", chain, "--priv-key", h1.key, "--priv-state", h1.state, "--domains-log", h1.log)
	child, conn := serve(h1)
	sign(conn, heightVote(tm.PrevoteType, 5, 1))
	signedA := readFile(t, h1.state)

	// 2. Crash and restart on host 1.
	kill(child)
	if !bytes.Equal(readFile(t, h1.state), signedA) {
		t.Fatal("a crash changed the HRS")
	}
	child, conn = serve(h1)
	fenced(conn)
	if hrs(readFile(t, h1.state)) != hrs(signedA) {
		t.Fatal("refused requests changed the HRS")
	}
	if got := floor(readFile(t, h1.state)); got != `"6" "`+testInstance+`"` {
		t.Fatalf("restart floor and binding: %s", got)
	}

	// 3. Failover: host 1 is stopped, and its latest files move to host 2.
	kill(child)
	h2 := newHost("host2")
	moved := map[string][]byte{}
	for from, to := range map[string]string{h1.key: h2.key, h1.state: h2.state, h1.log: h2.log} {
		raw := readFile(t, from)
		if err := os.WriteFile(to, raw, 0600); err != nil {
			t.Fatal(err)
		}
		moved[to] = raw
	}
	if err := os.Remove(h1.state); err != nil {
		t.Fatal(err)
	}
	if code, stderr := runSigner(t, serveArgs(h1.key, h1.state, h1.log)...); code != exitSigningStateUnsafe || !strings.Contains(stderr, "missing") {
		t.Fatalf("host 1 served without its state: exit %d %s", code, stderr)
	}
	if _, err := os.Lstat(h1.state); !os.IsNotExist(err) {
		t.Fatal("host 1 recreated its moved state")
	}
	instance.Store(otherInstance)
	_, conn = serve(h2)
	fenced(conn)
	if got := floor(readFile(t, h2.state)); got != `"6" "`+otherInstance+`"` {
		t.Fatalf("failover floor and binding: %s", got)
	}
	eligible.Store(6)
	sign(conn, heightVote(tm.PrecommitType, 6, 1))
	var persisted map[string]json.RawMessage
	if err := json.Unmarshal(readFile(t, h2.state), &persisted); err != nil {
		t.Fatal(err)
	}
	if string(persisted["height"]) != `"6"` || string(persisted["round"]) != "0" || string(persisted["step"]) != "3" {
		t.Fatalf("host 2 HRS after the precommit: %s", readFile(t, h2.state))
	}
	for path, raw := range moved {
		if path != h2.state && !bytes.Equal(readFile(t, path), raw) {
			t.Fatalf("host 2 changed %s", path)
		}
	}

	// 4. A failover missing the log, or the state, is refused with exit 3.
	latest := readFile(t, h2.state)
	key := readFile(t, h2.key)
	place := func(files map[string][]byte) {
		for path, raw := range files {
			if err := os.WriteFile(path, raw, 0600); err != nil {
				t.Fatal(err)
			}
		}
	}
	for _, failover := range []struct {
		name, reason string
		setup        func(h host)
	}{
		{"state-without-log", "domains log", func(h host) { place(map[string][]byte{h.key: key, h.state: latest}) }},
		{"state-with-a-fresh-log", "domains log", func(h host) {
			place(map[string][]byte{h.key: key, h.state: latest})
			command("init-domains-log", "--domains-log", h.log)
		}},
		{"log-without-state", "missing", func(h host) { place(map[string][]byte{h.key: key, h.log: moved[h2.log]}) }},
	} {
		t.Run(failover.name, func(t *testing.T) {
			h := newHost(failover.name)
			failover.setup(h)
			before := signingFiles(t, filepath.Dir(filepath.Dir(h.key)))
			if code, stderr := runSigner(t, serveArgs(h.key, h.state, h.log)...); code != exitSigningStateUnsafe || !strings.Contains(stderr, failover.reason) {
				t.Fatalf("incomplete failover exited %d: %s", code, stderr)
			}
			if after := signingFiles(t, filepath.Dir(filepath.Dir(h.key))); !reflect.DeepEqual(after, before) {
				t.Fatalf("a refused failover changed signing files: %v", after)
			}
		})
	}
	if !bytes.Equal(readFile(t, h2.state), latest) {
		t.Fatal("refused failovers changed host 2's HRS")
	}
}
