package main

import (
	"bytes"
	"errors"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// The state directory remains writable/searchable, so stock FilePV can replace
// its HRS file, but opening the directory for fsync must fail. Exercise the actual
// default generation-zero process, including cached retries and its wire replies:
// once a synchronization failed, the process signs nothing more even after the
// directory recovers, and only a restarted process resumes (RECOV-8.2-3).
func TestLegacySignerStopsSigningAfterDirectorySyncFails(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root bypasses the directory-read permission fault")
	}
	binary := buildSigner(t)
	for _, family := range []string{"prevote", "precommit", "proposal"} {
		t.Run(family, func(t *testing.T) {
			_, key, state := filePV(t)
			directory := filepath.Dir(state)
			path := control(t, func(req map[string]any) any { return snapshot(req["op"] != "begin_session") })
			socket := filepath.Join(shortTemp(t), "comet.sock")
			raw, err := net.ListenUnix("unix", &net.UnixAddr{Name: socket, Net: "unix"})
			if err != nil {
				t.Fatal(err)
			}
			listener := privval.NewUnixListener(raw)
			defer listener.Close()
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
			start := func() (stop func(), conn net.Conn) {
				child := exec.Command(binary, "--comet-signer-addr", "unix://"+socket, "--trust-socket", path, "--chain-id", chain, "--priv-key", key, "--priv-state", state)
				child.Stdout = logs
				child.Stderr = logs
				if err := child.Start(); err != nil {
					t.Fatal(err)
				}
				stopped := false
				stop = func() {
					if stopped {
						return
					}
					stopped = true
					child.Process.Signal(syscall.SIGTERM)
					done := make(chan error, 1)
					go func() { done <- child.Wait() }()
					select {
					case <-done:
					case <-time.After(3 * time.Second):
						child.Process.Kill()
						<-done
					}
				}
				t.Cleanup(stop)
				conn = acceptSigner(t, listener)
				pubkey := pv.Message{Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: chain}}}
				if response := signerExchange(t, conn, pubkey); response.GetPubKeyResponse() == nil || response.GetPubKeyResponse().Error != nil {
					t.Fatal("initial pubkey failed")
				}
				return stop, conn
			}
			stop, conn := start()
			if err = os.Chmod(directory, 0300); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { os.Chmod(directory, 0700) })
			if f, e := os.Open(directory); e == nil {
				f.Close()
				t.Fatal("directory fault did not prevent opening it for synchronization")
			}
			request := func() pv.Message {
				switch family {
				case "prevote":
					return voteRequest(tm.PrevoteType, 0, false)
				case "precommit":
					return voteRequest(tm.PrecommitType, 0, false)
				default:
					return proposalRequest()
				}
			}
			withheld := func(attempt int, response pv.Message) {
				t.Helper()
				if family == "proposal" {
					signed := response.GetSignedProposalResponse()
					if signed == nil || signed.Error == nil || len(signed.Proposal.Signature) != 0 {
						t.Fatalf("attempt %d released proposal before directory sync: %v", attempt, response)
					}
				} else {
					signed := response.GetSignedVoteResponse()
					if signed == nil || signed.Error == nil || len(signed.Vote.Signature) != 0 || len(signed.Vote.ExtensionSignature) != 0 {
						t.Fatalf("attempt %d released vote before directory sync: %v", attempt, response)
					}
				}
			}
			for attempt := 0; attempt < 3; attempt++ {
				req := request()
				if attempt == 2 {
					if vote := req.GetSignVoteRequest(); vote != nil {
						vote.Vote.Timestamp = time.Unix(101, 0)
					} else {
						req.GetSignProposalRequest().Proposal.Timestamp = time.Unix(101, 0)
					}
				}
				withheld(attempt, signerExchange(t, conn, req))
			}
			if err = os.Chmod(directory, 0700); err != nil {
				t.Fatal(err)
			}
			// The directory recovered, but the failed synchronization latched.
			withheld(3, signerExchange(t, conn, request()))
			stop()
			_, conn = start()
			response := signerExchange(t, conn, request())
			var signature []byte
			if family == "proposal" {
				signed := response.GetSignedProposalResponse()
				if signed == nil || signed.Error != nil {
					t.Fatalf("durable proposal retry failed: %v", response)
				}
				signature = signed.Proposal.Signature
			} else {
				signed := response.GetSignedVoteResponse()
				if signed == nil || signed.Error != nil {
					t.Fatalf("durable vote retry failed: %v", response)
				}
				signature = signed.Vote.Signature
			}
			persisted := privval.LoadFilePV(key, state)
			if len(signature) != 65 || !bytes.Equal(signature, persisted.LastSignState.Signature) || persisted.LastSignState.Height != 1 {
				t.Fatal("successful reply did not match persisted HRS/signature")
			}
		})
	}
}

var errInjectedSync = errors.New("injected fsync failure")

// A failing fsync withholds the signature and latches: the same signer refuses every
// later request, cached HRS retries included, even once the disk recovers. Only a
// restarted signer, which rereads the state, resumes, and it still refuses a conflict.
func TestDurableFilePVStopsSigningAfterStateSyncFails(t *testing.T) {
	for _, family := range []string{"prevote", "precommit", "proposal"} {
		t.Run(family, func(t *testing.T) {
			_, key, state := filePV(t)
			sign := func(signer *durableFilePV, conflict bool) ([]byte, error) {
				if family == "proposal" {
					req := proposalRequest()
					proposal := req.GetSignProposalRequest().Proposal
					if conflict {
						proposal.BlockID = tm.BlockID{Hash: bytes.Repeat([]byte{1}, 32), PartSetHeader: tm.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{2}, 32)}}
					}
					err := signer.SignProposal(chain, proposal)
					return proposal.Signature, err
				}
				kind := tm.PrevoteType
				if family == "precommit" {
					kind = tm.PrecommitType
				}
				req := voteRequest(kind, 0, conflict)
				vote := req.GetSignVoteRequest().Vote
				err := signer.SignVote(chain, vote)
				if err != nil && len(vote.ExtensionSignature) != 0 {
					t.Fatal("unsynchronized extension signature published to caller")
				}
				return vote.Signature, err
			}
			signer := loadDurableFilePV(key, state)
			signer.syncFile = func(*os.File) error { return errInjectedSync }
			if signature, err := sign(signer, false); !errors.Is(err, errStateUncertain) || !errors.Is(err, errInjectedSync) || len(signature) != 0 {
				t.Fatalf("failed fsync released a signature: %v", err)
			}
			signer.syncFile = (*os.File).Sync
			for _, conflict := range []bool{false, true} {
				if signature, err := sign(signer, conflict); !errors.Is(err, errStateUncertain) || len(signature) != 0 {
					t.Fatalf("signed after a failed synchronization (conflict %v): %v", conflict, err)
				}
			}
			restarted := loadDurableFilePV(key, state)
			if signature, err := sign(restarted, true); err == nil || errors.Is(err, errStateUncertain) || len(signature) != 0 {
				t.Fatalf("restart lost double-sign protection: %v", err)
			}
			signature, err := sign(restarted, false)
			persisted := privval.LoadFilePV(key, state)
			if err != nil || len(signature) != 65 || !bytes.Equal(signature, persisted.LastSignState.Signature) {
				t.Fatalf("restarted cached retry failed: %v", err)
			}
		})
	}
}

// Authority mode reloads the domain state for every request, so a failed
// synchronization latches on the authority: neither the handle nor a fresh
// authorization signs again until a restart.
func TestAuthorityStopsSigningAfterStateSyncFails(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root bypasses the directory-read permission fault")
	}
	c := authorityFixture(t)
	a, err := openAuthority(c)
	if err != nil {
		t.Fatal(err)
	}
	domain, r := readyDomain(t, c, 0)
	signer, err := a.authorize(domain, r)
	if err != nil {
		t.Fatal(err)
	}
	directory := filepath.Dir(signer.(*authorizedPV).domain.State)
	if err = os.Chmod(directory, 0300); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chmod(directory, 0700) })
	vote := authorityVote(5)
	if err = signer.SignVote(domain, vote); !errors.Is(err, errStateUncertain) || len(vote.Signature) != 0 {
		t.Fatalf("failed directory sync released a signature: %v", err)
	}
	if err = os.Chmod(directory, 0700); err != nil {
		t.Fatal(err)
	}
	vote = authorityVote(5)
	if err = signer.SignVote(domain, vote); err == nil || len(vote.Signature) != 0 {
		t.Fatal("authority signed after a failed synchronization")
	}
	if _, err = a.authorize(domain, r); err == nil {
		t.Fatal("authority authorized a domain after a failed synchronization")
	}
	a.Close()
	a, err = openAuthority(c)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	if signer, err = a.authorize(domain, r); err != nil {
		t.Fatal(err)
	}
	conflict := authorityVote(5)
	conflict.BlockID = tm.BlockID{Hash: bytes.Repeat([]byte{1}, 32), PartSetHeader: tm.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{2}, 32)}}
	if err = signer.SignVote(domain, conflict); err == nil || len(conflict.Signature) != 0 {
		t.Fatal("restart lost double-sign protection")
	}
	vote = authorityVote(5)
	if err = signer.SignVote(domain, vote); err != nil || len(vote.Signature) != 65 {
		t.Fatalf("restarted cached retry failed: %v", err)
	}
}
