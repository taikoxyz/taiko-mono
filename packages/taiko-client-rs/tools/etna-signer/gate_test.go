package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/libs/log"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

const chain = "etna-test"

type recordingPV struct {
	*privval.FilePV
	calls atomic.Int64
}

func (p *recordingPV) SignVote(chain string, vote *tm.Vote) error {
	p.calls.Add(1)
	return p.FilePV.SignVote(chain, vote)
}
func (p *recordingPV) SignProposal(chain string, proposal *tm.Proposal) error {
	p.calls.Add(1)
	return p.FilePV.SignProposal(chain, proposal)
}

func shortTemp(t *testing.T) string {
	t.Helper()
	d, e := os.MkdirTemp("/tmp", "etna-signer-")
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() { os.RemoveAll(d) })
	return d
}

func control(t *testing.T, reply func(map[string]any) any) string {
	t.Helper()
	path := filepath.Join(shortTemp(t), "trust.sock")
	l, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	go func() {
		for {
			c, e := l.Accept()
			if e != nil {
				return
			}
			go func() {
				defer c.Close()
				var req map[string]any
				if json.NewDecoder(c).Decode(&req) == nil {
					json.NewEncoder(c).Encode(reply(req))
				}
			}()
		}
	}()
	return path
}
func snapshot(ready bool) map[string]any {
	hash := "0x" + strings.Repeat("b", 64)
	return map[string]any{"schema_version": 1, "session_id": "test:7", "chain_id": chain, "generation": 0, "trust_ready": ready, "syncing": !ready, "phase": map[bool]string{true: "ready", false: "catching_up"}[ready], "target": map[string]any{"l1_number": 10, "l1_hash": "0x" + strings.Repeat("a", 64), "height": 0, "hash": hash, "comet_hash": "0x" + strings.Repeat("c", 64), "generation": 0, "inbox": "0x" + strings.Repeat("1", 40)}, "committed_head": map[string]any{"height": 0, "hash": hash}, "trusted_consensus_head": map[string]any{"height": 0, "hash": hash}, "reason": nil}
}
func filePV(t *testing.T) (*privval.FilePV, string, string) {
	t.Helper()
	d := t.TempDir()
	key, state := filepath.Join(d, "key.json"), filepath.Join(d, "state.json")
	p := privval.NewFilePV(secp256k1eth.GenPrivKey(), key, state)
	p.Save()
	return p, key, state
}
func armed(path string) *gate {
	g := newGate(path, time.Second)
	session := "test:7"
	g.session.Store(&session)
	return g
}
func voteRequest(typ tm.SignedMsgType, round int32, nilBlock bool) pv.Message {
	vote := &tm.Vote{Type: typ, Height: 1, Round: round, Timestamp: time.Unix(100, 0)}
	if !nilBlock {
		vote.BlockID = tm.BlockID{Hash: bytes.Repeat([]byte{1}, 32), PartSetHeader: tm.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{2}, 32)}}
	}
	return pv.Message{Sum: &pv.Message_SignVoteRequest{SignVoteRequest: &pv.SignVoteRequest{ChainId: chain, Vote: vote}}}
}
func proposalRequest() pv.Message {
	return pv.Message{Sum: &pv.Message_SignProposalRequest{SignProposalRequest: &pv.SignProposalRequest{ChainId: chain, Proposal: &tm.Proposal{Type: tm.ProposalType, Height: 1, PolRound: -1, Timestamp: time.Unix(100, 0)}}}}
}
func TestClosedGateAllSigningFamilies(t *testing.T) {
	path := control(t, func(map[string]any) any { return snapshot(false) })
	gate := armed(path)
	backend, _, state := filePV(t)
	signer := &recordingPV{FilePV: backend}
	before, _ := os.ReadFile(state)
	requests := []pv.Message{voteRequest(tm.PrevoteType, 0, true), voteRequest(tm.PrecommitType, 0, true), voteRequest(tm.PrevoteType, 1, false), voteRequest(tm.PrecommitType, 1, false), proposalRequest(), proposalRequest()}
	for _, req := range requests {
		res, err := gate.handle(signer, req, chain)
		if err == nil {
			t.Fatal("closed signing succeeded")
		}
		if res.GetSignedVoteResponse() == nil && res.GetSignedProposalResponse() == nil {
			t.Fatal("missing protocol denial")
		}
	}
	after, _ := os.ReadFile(state)
	if !bytes.Equal(before, after) {
		t.Fatal("denial modified FilePV state")
	}
	if signer.calls.Load() != 0 {
		t.Fatal("closed gate invoked FilePV signing method")
	}
	for _, req := range []pv.Message{{Sum: &pv.Message_PingRequest{PingRequest: &pv.PingRequest{}}}, {Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: chain}}}} {
		if _, err := gate.handle(signer, req, chain); err != nil {
			t.Fatal(err)
		}
	}
}
func TestReadyIsFreshAndFilePVPersistsDoubleSignProtection(t *testing.T) {
	var ready atomic.Bool
	ready.Store(true)
	var checks atomic.Int64
	path := control(t, func(map[string]any) any { checks.Add(1); return snapshot(ready.Load()) })
	g := armed(path)
	signer, key, state := filePV(t)
	req := voteRequest(tm.PrecommitType, 0, false)
	res, err := g.handle(signer, req, chain)
	if err != nil || res.GetSignedVoteResponse().Error != nil {
		t.Fatalf("ready: %v %v", res, err)
	}
	signed := res.GetSignedVoteResponse().Vote.Signature
	if len(signed) != 65 {
		t.Fatal("no official signature")
	}
	signer = privval.LoadFilePV(key, state)
	retry, _ := g.handle(signer, voteRequest(tm.PrecommitType, 0, false), chain)
	if !bytes.Equal(signed, retry.GetSignedVoteResponse().Vote.Signature) {
		t.Fatal("same HRS retry changed signature")
	}
	conflicting := voteRequest(tm.PrecommitType, 0, true)
	res, _ = g.handle(signer, conflicting, chain)
	if res.GetSignedVoteResponse().Error == nil {
		t.Fatal("double sign allowed")
	}
	before, _ := os.ReadFile(state)
	ready.Store(false)
	res, err = g.handle(signer, voteRequest(tm.PrecommitType, 0, false), chain)
	if err == nil || res.GetSignedVoteResponse().Error == nil {
		t.Fatal("cached Ready accepted")
	}
	after, _ := os.ReadFile(state)
	if !bytes.Equal(before, after) {
		t.Fatal("denial mutated state")
	}
	if checks.Load() != 4 {
		t.Fatal("missing fresh check")
	}
}
func TestControlFailuresDeny(t *testing.T) {
	for _, test := range []string{"version", "session", "chain", "null_sync", "missing", "generation", "target", "trusted", "unknown", "auth_error", "app_dead"} {
		t.Run(test, func(t *testing.T) {
			path := control(t, func(req map[string]any) any {
				r := snapshot(true)
				switch test {
				case "version":
					r["schema_version"] = 2
				case "session":
					r["session_id"] = "other:1"
				case "chain":
					r["chain_id"] = "wrong"
				case "null_sync":
					r["syncing"] = nil
				case "missing":
					delete(r, "syncing")
				case "generation":
					r["generation"] = nil
				case "target":
					r["target"] = nil
				case "trusted":
					r["trusted_consensus_head"] = nil
				case "unknown":
					r["future"] = true
				case "auth_error":
					return map[string]any{"error": "unauthorized"}
				}
				return r
			})
			if test == "app_dead" {
				path = filepath.Join(t.TempDir(), "absent.sock")
			}
			g := armed(path)
			signer, _, state := filePV(t)
			before, _ := os.ReadFile(state)
			res, err := g.handle(signer, proposalRequest(), chain)
			if err == nil || res.GetSignedProposalResponse().Error == nil {
				t.Fatal("bad trust accepted")
			}
			after, _ := os.ReadFile(state)
			if !bytes.Equal(before, after) {
				t.Fatal("state changed")
			}
		})
	}
}
func TestMalformedAndTimeoutBounded(t *testing.T) {
	encoded, _ := json.Marshal(snapshot(true))
	duplicate := strings.Replace(string(encoded), `"trust_ready":true`, `"trust_ready":false,"trust_ready":true`, 1) + "\n"
	for _, payload := range []string{"{bad}\n", duplicate, strings.Repeat("x", maxControlFrame+1) + "\n", ""} {
		t.Run(string(rune(len(payload))), func(t *testing.T) {
			path := filepath.Join(shortTemp(t), "s")
			l, _ := net.Listen("unix", path)
			defer l.Close()
			go func() {
				c, e := l.Accept()
				if e != nil {
					return
				}
				defer c.Close()
				if payload == "" {
					time.Sleep(200 * time.Millisecond)
				} else {
					c.Write([]byte(payload))
				}
			}()
			g := armed(path)
			g.timeout = 30 * time.Millisecond
			start := time.Now()
			if err := g.authorize(chain); err == nil {
				t.Fatal("malformed/timeout accepted")
			}
			if time.Since(start) > time.Second {
				t.Fatal("unbounded timeout")
			}
		})
	}
}
func TestDialBeginsEachTransportAndRearmsAppRestart(t *testing.T) {
	var begins atomic.Int64
	path := control(t, func(req map[string]any) any {
		r := snapshot(false)
		if req["op"] == "begin_session" {
			begins.Add(1)
		}
		return r
	})
	g := newGate(path, time.Second)
	var peers []net.Conn
	defer func() {
		for _, p := range peers {
			p.Close()
		}
	}()
	dial := g.dialer(func() (net.Conn, error) { a, b := net.Pipe(); peers = append(peers, b); return a, nil })
	for range 2 {
		c, err := dial()
		if err != nil {
			t.Fatal(err)
		}
		c.Close()
	}
	if begins.Load() != 2 {
		t.Fatal("transport did not rearm")
	}
	old := "previous-process:7"
	g.session.Store(&old)
	if err := g.authorize(chain); err == nil {
		t.Fatal("old session accepted")
	}
	if begins.Load() != 3 || g.session.Load() == nil || *g.session.Load() != "test:7" {
		t.Fatal("app restart did not rearm")
	}
}
func TestNilAndWrongChainRequests(t *testing.T) {
	g := armed("missing")
	signer, _, _ := filePV(t)
	for _, req := range []pv.Message{{Sum: &pv.Message_SignVoteRequest{}}, {Sum: &pv.Message_SignProposalRequest{}}, {Sum: &pv.Message_SignVoteRequest{SignVoteRequest: &pv.SignVoteRequest{ChainId: "wrong", Vote: &tm.Vote{}}}}} {
		if _, err := g.handle(signer, req, chain); err == nil {
			t.Fatal("invalid request accepted")
		}
	}
}

// Use the same official protobuf endpoint and SecretConnection as a real Comet
// process. Closed nil/locked/retained messages must receive protocol denials.
func TestOfficialSignerWire(t *testing.T) {
	for _, transport := range []string{"unix", "tcp"} {
		t.Run(transport, func(t *testing.T) {
			var ready atomic.Bool
			path := control(t, func(req map[string]any) any {
				if req["op"] == "begin_session" {
					return snapshot(false)
				}
				return snapshot(ready.Load())
			})
			g := newGate(path, time.Second)
			signer, _, state := filePV(t)
			before, _ := os.ReadFile(state)
			var listener net.Listener
			var dial privval.SocketDialer
			var err error
			if transport == "unix" {
				addr := filepath.Join(shortTemp(t), "comet.sock")
				raw, e := net.Listen("unix", addr)
				if e != nil {
					t.Fatal(e)
				}
				listener = privval.NewUnixListener(raw)
				dial = privval.DialUnixFn(addr)
			} else {
				raw, e := net.Listen("tcp", "127.0.0.1:0")
				if e != nil {
					t.Fatal(e)
				}
				listener = privval.NewTCPListener(raw, ed25519.GenPrivKey())
				dial = privval.DialTCPFn(raw.Addr().String(), time.Second, ed25519.GenPrivKey())
			}
			endpoint := privval.NewSignerListenerEndpoint(log.NewNopLogger(), listener)
			client, err := privval.NewSignerClient(endpoint, chain)
			if err != nil {
				t.Fatal(err)
			}
			server := privval.NewSignerServer(privval.NewSignerDialerEndpoint(log.NewNopLogger(), g.dialer(dial)), chain, signer)
			server.SetRequestHandler(g.handle)
			if err = server.Start(); err != nil {
				t.Fatal(err)
			}
			defer func() { server.Stop(); endpoint.Stop() }()
			if err = client.WaitForConnection(3 * time.Second); err != nil {
				t.Fatal(err)
			}
			if _, err = client.GetPubKey(); err != nil {
				t.Fatal(err)
			}
			for _, typ := range []tm.SignedMsgType{tm.PrevoteType, tm.PrecommitType} {
				for _, nilBlock := range []bool{true, false} {
					request := voteRequest(typ, 0, nilBlock)
					vote := request.GetSignVoteRequest().Vote
					if err = client.SignVote(chain, vote); err == nil {
						t.Fatal("closed vote signed on wire")
					}
				}
			}
			for range 2 {
				request := proposalRequest()
				if err = client.SignProposal(chain, request.GetSignProposalRequest().Proposal); err == nil {
					t.Fatal("retained proposal signed")
				}
			}
			after, _ := os.ReadFile(state)
			if !bytes.Equal(before, after) {
				t.Fatal("wire denial changed FilePV")
			}
			ready.Store(true)
			request := voteRequest(tm.PrecommitType, 0, false)
			vote := request.GetSignVoteRequest().Vote
			if err = client.SignVote(chain, vote); err != nil || len(vote.Signature) != 65 {
				t.Fatalf("ready official signing: %v", err)
			}
			ready.Store(false)
			if err = client.SignVote(chain, vote); err == nil {
				t.Fatal("repeat signature bypassed closed gate")
			}
		})
	}
}

func TestPubKeyAndPingWithAbsentAppAndNoSession(t *testing.T) {
	g := newGate("/absent-trust.sock", time.Second)
	signer, _, _ := filePV(t)
	for _, req := range []pv.Message{{Sum: &pv.Message_PingRequest{PingRequest: &pv.PingRequest{}}}, {Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: chain}}}} {
		if _, err := g.handle(signer, req, chain); err != nil {
			t.Fatal(err)
		}
	}
}

func TestMalformedReadyRequestsNeverReachFilePV(t *testing.T) {
	path := control(t, func(map[string]any) any { return snapshot(true) })
	g := armed(path)
	backend, _, state := filePV(t)
	signer := &recordingPV{FilePV: backend}
	before, _ := os.ReadFile(state)
	invalidVote := voteRequest(tm.PrevoteType, 0, true)
	invalidVote.GetSignVoteRequest().Vote.Type = tm.UnknownType
	malformedBlock := voteRequest(tm.PrevoteType, 0, false)
	malformedBlock.GetSignVoteRequest().Vote.BlockID.Hash = []byte{1}
	invalidProposal := proposalRequest()
	invalidProposal.GetSignProposalRequest().Proposal.Type = tm.UnknownType
	for _, request := range []pv.Message{invalidVote, malformedBlock, invalidProposal} {
		if _, err := g.handle(signer, request, chain); err == nil {
			t.Fatal("malformed request accepted")
		}
	}
	after, _ := os.ReadFile(state)
	if signer.calls.Load() != 0 || !bytes.Equal(before, after) {
		t.Fatal("malformed Ready request reached FilePV")
	}
}

func TestMandatoryCanonicalCometCheckpointHash(t *testing.T) {
	for _, value := range []any{nil, json.RawMessage("null"), "", "0x01", "0x" + strings.Repeat("A", 64), "0x" + strings.Repeat("0", 64)} {
		t.Run(fmt.Sprint(value), func(t *testing.T) {
			path := control(t, func(map[string]any) any {
				r := snapshot(true)
				target := r["target"].(map[string]any)
				if value == nil {
					delete(target, "comet_hash")
				} else {
					target["comet_hash"] = value
				}
				return r
			})
			signer, _, state := filePV(t)
			before, _ := os.ReadFile(state)
			_, err := armed(path).handle(signer, proposalRequest(), chain)
			// The all-zero genesis Comet hash is canonical and is accepted.
			valid := value == "0x"+strings.Repeat("0", 64)
			if (err == nil) != valid {
				t.Fatalf("comet hash acceptance: %v", err)
			}
			after, _ := os.ReadFile(state)
			if !valid && !bytes.Equal(before, after) {
				t.Fatal("invalid comet hash modified HRS")
			}
		})
	}
}

// A timeout must be observable even when the app never published a closed state.
func TestDenialSignalIncludesTimeoutWithoutChangingHRS(t *testing.T) {
	path := control(t, func(map[string]any) any { time.Sleep(100 * time.Millisecond); return snapshot(true) })
	g := armed(path)
	g.timeout = 10 * time.Millisecond
	g.denialPath = filepath.Join(t.TempDir(), "denial.json")
	signer, _, state := filePV(t)
	before, _ := os.ReadFile(state)
	for sequence := uint64(1); sequence <= 2; sequence++ {
		_, err := g.handle(signer, voteRequest(tm.PrevoteType, 0, true), chain)
		if err == nil {
			t.Fatal("timeout authorized a signature")
		}
		data, err := os.ReadFile(g.denialPath)
		if err != nil {
			t.Fatalf("timeout must publish denial before returning: %v", err)
		}
		var event struct {
			Sequence uint64 `json:"sequence"`
		}
		if err := json.Unmarshal(data, &event); err != nil || event.Sequence != sequence {
			t.Fatalf("denial sequence: %s %v", data, err)
		}
	}
	after, _ := os.ReadFile(state)
	if !bytes.Equal(before, after) {
		t.Fatal("timeout changed authoritative HRS")
	}
}
