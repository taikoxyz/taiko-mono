package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	"github.com/cometbft/cometbft/types"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"
)

// The child executes the same durable transition phases as authorize, then pauses at the
// selected boundary. The parent uses SIGKILL: no deferred Close or graceful cleanup runs.
func TestAuthorityCrashHelper(t *testing.T) {
	path := os.Getenv("ETNA_AUTHORITY_CRASH_CONFIG")
	if path == "" {
		return
	}
	raw, e := os.ReadFile(path)
	if e != nil {
		t.Fatal(e)
	}
	var c authorityConfig
	if e = json.Unmarshal(raw, &c); e != nil {
		t.Fatal(e)
	}
	a, e := openAuthority(c)
	if e != nil {
		t.Fatal(e)
	}
	chain, r := readyDomain(t, c, 2)
	d := authorityDomain{Generation: 2, Chain: chain, State: filepath.Join(a.config.Root, chain+".json"), Origin: r.RecoveryOrigin}
	stage := os.Getenv("ETNA_AUTHORITY_CRASH_STAGE")
	if stage != "before-intent" {
		if e = a.recordIntent(d); e != nil {
			t.Fatal(e)
		}
	}
	if stage == "state" || stage == "manifest" || stage == "signature" {
		if e = a.stageDomain(d); e != nil {
			t.Fatal(e)
		}
	}
	if stage == "manifest" || stage == "signature" {
		if e = a.publishDomain(d); e != nil {
			t.Fatal(e)
		}
	}
	if stage == "signature" {
		p, e := a.authorize(chain, r)
		if e != nil {
			t.Fatal(e)
		}
		v := authorityVote(7)
		if e = p.SignVote(chain, v); e != nil {
			t.Fatal(e)
		}
		if e = exclusiveDurable(path+".signature", v.Signature); e != nil {
			t.Fatal(e)
		}
	}
	fmt.Println("durable-boundary")
	for {
		time.Sleep(time.Second)
	}
}
func TestAuthoritySIGKILLTransitionBoundaries(t *testing.T) {
	for _, stage := range []string{"before-intent", "intent", "state", "manifest", "signature"} {
		t.Run(stage, func(t *testing.T) {
			c := authorityFixture(t)
			old, oldReady := readyDomain(t, c, 0)
			a, e := openAuthority(c)
			if e != nil {
				t.Fatal(e)
			}
			p, e := a.authorize(old, oldReady)
			if e != nil {
				t.Fatal(e)
			}
			if e = p.SignVote(old, authorityVote(20)); e != nil {
				t.Fatal(e)
			}
			a.Close()
			before, _ := os.ReadFile(c.LegacyState)
			keyBefore, _ := os.ReadFile(c.Key)
			config := filepath.Join(t.TempDir(), "config.json")
			raw, _ := json.Marshal(c)
			os.WriteFile(config, raw, 0600)
			child := exec.Command(os.Args[0], "-test.run=^TestAuthorityCrashHelper$")
			child.Env = append(os.Environ(), "ETNA_AUTHORITY_CRASH_CONFIG="+config, "ETNA_AUTHORITY_CRASH_STAGE="+stage)
			out, e := child.StdoutPipe()
			if e != nil {
				t.Fatal(e)
			}
			var stderr bytes.Buffer
			child.Stderr = &stderr
			if e = child.Start(); e != nil {
				t.Fatal(e)
			}
			ready := make(chan string, 1)
			go func() { line, _ := bufio.NewReader(out).ReadString('\n'); ready <- line }()
			select {
			case line := <-ready:
				if line != "durable-boundary\n" {
					child.Process.Kill()
					child.Wait()
					t.Fatalf("child failed %q: %s", line, stderr.String())
				}
			case <-time.After(10 * time.Second):
				child.Process.Kill()
				child.Wait()
				t.Fatal("child did not reach boundary")
			}
			if other, e := openAuthority(c); e == nil {
				other.Close()
				child.Process.Kill()
				child.Wait()
				t.Fatal("live child did not own key")
			}
			child.Process.Kill()
			if e = child.Wait(); e == nil {
				t.Fatal("child was not killed")
			}
			a, e = openAuthority(c)
			if e != nil {
				t.Fatal(e)
			}
			defer a.Close()
			_, e = a.authorize(old, oldReady)
			if stage == "before-intent" {
				if e != nil {
					t.Fatal(e)
				}
			} else if e == nil {
				t.Fatal("crash reopened old generation")
			}
			next, r := readyDomain(t, c, 2)
			p, e = a.authorize(next, r)
			if e != nil {
				t.Fatal(e)
			}
			v := authorityVote(7)
			if e = p.SignVote(next, v); e != nil {
				t.Fatal(e)
			}
			if stage == "signature" {
				previous, e := os.ReadFile(config + ".signature")
				if e != nil || !bytes.Equal(previous, v.Signature) {
					t.Fatal("crash changed same-HRS signature", e)
				}
			}
			after, _ := os.ReadFile(c.LegacyState)
			keyAfter, _ := os.ReadFile(c.Key)
			if !bytes.Equal(before, after) || !bytes.Equal(keyBefore, keyAfter) {
				t.Fatal("crash transition changed original signing files")
			}
		})
	}
}

func TestAuthorityNativeProcessHandshakeAndSignature(t *testing.T) {
	binary := buildSigner(t)
	c := authorityFixture(t)
	old, _ := readyDomain(t, c, 0)
	p := privval.LoadFilePV(c.Key, c.LegacyState)
	if e := p.SignVote(old, authorityVote(20)); e != nil {
		t.Fatal(e)
	}
	before, _ := os.ReadFile(c.LegacyState)
	chain, r := readyDomain(t, c, 2)
	var ready atomic.Bool
	var begins atomic.Uint64
	path := control(t, func(req map[string]any) any {
		if req["schema_version"] != float64(2) {
			return map[string]any{}
		}
		if req["op"] == "begin_session" {
			begins.Add(1)
			ready.Store(false)
		}
		snapshot := *r
		snapshot.SessionID = fmt.Sprintf("authority:%d", begins.Load())
		snapshot.Ready = ready.Load()
		snapshot.Syncing = !snapshot.Ready
		if !snapshot.Ready {
			snapshot.Phase = "acquiring"
		}
		return snapshot
	})
	socket := filepath.Join(shortTemp(t), "comet.sock")
	listener, e := net.ListenUnix("unix", &net.UnixAddr{Name: socket, Net: "unix"})
	if e != nil {
		t.Fatal(e)
	}
	defer listener.Close()
	listener.SetDeadline(time.Now().Add(10 * time.Second))
	child := exec.Command(binary, "--comet-signer-addr", "unix://"+socket, "--trust-socket", path, "--chain-id", chain, "--priv-key", c.Key, "--priv-state", c.LegacyState, "--authority-root", c.Root, "--l1-chain-id", c.L1ChainID, "--l2-chain-id", c.L2ChainID, "--inbox", c.Inbox, "--generation", "2", "--enroll-legacy")
	if e = child.Start(); e != nil {
		t.Fatal(e)
	}
	defer func() { child.Process.Kill(); child.Wait() }()
	conn := acceptSigner(t, listener)
	pub := pv.Message{Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: chain}}}
	response := signerExchange(t, conn, pub)
	if response.GetPubKeyResponse() == nil || response.GetPubKeyResponse().Error != nil {
		t.Fatal("closed authority handshake failed")
	}
	if _, e = os.Stat(filepath.Join(c.Root, chain+".json")); !os.IsNotExist(e) {
		t.Fatal("handshake created new HRS")
	}
	ready.Store(true)
	req := pv.Message{Sum: &pv.Message_SignVoteRequest{SignVoteRequest: &pv.SignVoteRequest{ChainId: chain, Vote: authorityVote(7)}}}
	response = signerExchange(t, conn, req)
	signed := response.GetSignedVoteResponse()
	if signed == nil || signed.Error != nil || len(signed.Vote.Signature) != 65 {
		t.Fatal("ready authority signing failed", signed)
	}
	native, e := loadNativeKey(c.Key)
	if e != nil || !native.PubKey().VerifySignature(types.VoteSignBytes(chain, &signed.Vote), signed.Vote.Signature) {
		t.Fatal("invalid stock signature", e)
	}
	conn.Close()
	conn = acceptSigner(t, listener)
	response = signerExchange(t, conn, pub)
	if response.GetPubKeyResponse() == nil || response.GetPubKeyResponse().Error != nil {
		t.Fatal("reconnect pubkey failed")
	}
	response = signerExchange(t, conn, req)
	if response.GetSignedVoteResponse().Error == nil {
		t.Fatal("new closed session reused signature")
	}
	ready.Store(true)
	response = signerExchange(t, conn, req)
	retry := response.GetSignedVoteResponse()
	if retry.Error != nil || !bytes.Equal(signed.Vote.Signature, retry.Vote.Signature) {
		t.Fatal("fresh-session retry changed signature")
	}
	after, _ := os.ReadFile(c.LegacyState)
	if !bytes.Equal(before, after) {
		t.Fatal("native process modified legacy HRS")
	}
}
