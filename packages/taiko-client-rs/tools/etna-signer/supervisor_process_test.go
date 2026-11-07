package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
)

// A real persistence failure must reach the supervisor's durable terminal path,
// rather than its trust-refusal restart path. The parent supplies Comet's official
// transport while the supervised Comet child records process incarnations.
func TestSupervisorLatchesUncertainSigningStateAcrossRestart(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root bypasses the directory-read permission fault")
	}
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Fatal(err)
	}
	binary := buildSigner(t)
	for _, mode := range []string{"legacy", "authority-zero", "authority-recovered", "authority-transition"} {
		t.Run(mode, func(t *testing.T) {
			c := authorityFixture(t)
			domain, ready := chain, snapshot(true)
			generation, state := uint64(0), c.LegacyState
			if mode != "legacy" {
				if mode == "authority-recovered" || mode == "authority-transition" {
					generation = 2
				}
				var response *trustResponse
				domain, response = readyDomain(t, c, generation)
				raw, _ := json.Marshal(response)
				if err := json.Unmarshal(raw, &ready); err != nil {
					t.Fatal(err)
				}
				if generation == 0 {
					ready["recovery_origin"] = nil
				}
				a, err := openAuthority(c)
				if err != nil {
					t.Fatal(err)
				}
				if mode != "authority-transition" {
					signer, err := a.authorize(domain, response)
					if err != nil {
						a.Close()
						t.Fatal(err)
					}
					state = signer.(*authorizedPV).domain.State
				}
				a.Close()
			}
			controlPath := control(t, func(request map[string]any) any {
				response := make(map[string]any, len(ready))
				for key, value := range ready {
					response[key] = value
				}
				if request["op"] == "begin_session" {
					response["trust_ready"], response["syncing"], response["phase"] = false, true, "acquiring"
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
			genesis, _ := json.Marshal(map[string]any{"chain_id": domain})
			if err := os.WriteFile(filepath.Join(home, "config", "genesis.json"), genesis, 0600); err != nil {
				t.Fatal(err)
			}
			starts := filepath.Join(root, "comet-starts")
			cometCommand, _ := json.Marshal([]string{python, "-c", "import os,time; open(os.environ['COMET_STARTS'],'a').write('start\\n'); time.sleep(300)"})
			environment := make([]string, 0, len(os.Environ()))
			for _, value := range os.Environ() {
				if !strings.HasPrefix(value, "ETNA_") {
					environment = append(environment, value)
				}
			}
			environment = append(environment, "ETNA_COMET_HOME="+home, "ETNA_APP_STORE="+store,
				"ETNA_PRIV_KEY="+c.Key, "ETNA_PRIV_STATE="+c.LegacyState, "ETNA_CHAIN_ID="+domain,
				"ETNA_SIGNER_BIN="+binary, "ETNA_COMET_COMMAND_JSON="+string(cometCommand), "COMET_STARTS="+starts,
				"ETNA_AUTHORITY_ROOT=", "ETNA_GENERATION=0", "ETNA_L1_CHAIN_ID=", "ETNA_L2_CHAIN_ID=", "ETNA_INBOX=", "ETNA_ENROLL_LEGACY=0")
			if mode != "legacy" {
				environment = append(environment, "ETNA_AUTHORITY_ROOT="+c.Root, "ETNA_GENERATION="+strconv.FormatUint(generation, 10),
					"ETNA_L1_CHAIN_ID="+c.L1ChainID, "ETNA_L2_CHAIN_ID="+c.L2ChainID, "ETNA_INBOX="+c.Inbox)
			}
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
				return pv.Message{Sum: &pv.Message_SignVoteRequest{SignVoteRequest: &pv.SignVoteRequest{ChainId: domain, Vote: authorityVote(7)}}}
			}
			if mode == "authority-transition" {
				pubkey := pv.Message{Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: domain}}}
				initial := signerExchange(t, conn, pubkey)
				if initial.GetPubKeyResponse() == nil || initial.GetPubKeyResponse().Error != nil {
					t.Fatal("initial authority identity handshake failed", initial)
				}
			} else {
				initial := signerExchange(t, conn, request())
				if signed := initial.GetSignedVoteResponse(); signed == nil || signed.Error != nil || len(signed.Vote.Signature) != 65 {
					t.Fatal("initial trusted signature failed", signed)
				}
			}
			before, err := os.ReadFile(state)
			if err != nil {
				t.Fatal(err)
			}
			keyBefore, _ := os.ReadFile(c.Key)
			directory := filepath.Dir(state)
			fault := os.FileMode(0300)
			if mode == "authority-transition" {
				directory, fault = c.Root, 0500 // Fail the transition's intent write.
			}
			if err := os.Chmod(directory, fault); err != nil {
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
			stopTestProcess(t, supervisor)
			start()
			time.Sleep(400 * time.Millisecond)
			after, _ := os.ReadFile(state)
			keyAfter, _ := os.ReadFile(c.Key)
			retainedLatch, _ := os.ReadFile(latch)
			incarnations, _ := os.ReadFile(starts)
			if !bytes.Equal(before, after) || !bytes.Equal(keyBefore, keyAfter) || !bytes.Equal(latched, retainedLatch) {
				t.Fatal("supervisor restart changed uncertain HRS, key or terminal evidence")
			}
			if strings.Count(string(incarnations), "start\n") != 1 {
				t.Fatalf("automatically restarted uncertain signing authority: %q", incarnations)
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
