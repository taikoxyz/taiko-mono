package main

import (
	"bytes"
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
// default generation-zero process, including cached retries and its wire replies.
func TestLegacySignerWithholdsSignaturesUntilDirectorySync(t *testing.T) {
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
			child := exec.Command(binary, "--comet-signer-addr", "unix://"+socket, "--trust-socket", path, "--chain-id", chain, "--priv-key", key, "--priv-state", state)
			child.Stdout = logs
			child.Stderr = logs
			if err = child.Start(); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				child.Process.Signal(syscall.SIGTERM)
				done := make(chan error, 1)
				go func() { done <- child.Wait() }()
				select {
				case <-done:
				case <-time.After(3 * time.Second):
					child.Process.Kill()
					<-done
				}
			})
			conn := acceptSigner(t, listener)
			pubkey := pv.Message{Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: chain}}}
			if response := signerExchange(t, conn, pubkey); response.GetPubKeyResponse() == nil || response.GetPubKeyResponse().Error != nil {
				t.Fatal("initial pubkey failed")
			}
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
			for attempt := 0; attempt < 3; attempt++ {
				req := request()
				if attempt == 2 {
					if vote := req.GetSignVoteRequest(); vote != nil {
						vote.Vote.Timestamp = time.Unix(101, 0)
					} else {
						req.GetSignProposalRequest().Proposal.Timestamp = time.Unix(101, 0)
					}
				}
				response := signerExchange(t, conn, req)
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
			if err = os.Chmod(directory, 0700); err != nil {
				t.Fatal(err)
			}
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

func TestDurableFilePVWithholdsCallerSignatureWhenStateSyncFails(t *testing.T) {
	for _, family := range []string{"prevote", "precommit", "proposal"} {
		t.Run(family, func(t *testing.T) {
			_, key, state := filePV(t)
			signer := loadDurableFilePV(key, state)
			// Fail the post-sign open without changing the stock backend's state
			// location. This fault also works when tests run as root.
			signer.state = filepath.Join(t.TempDir(), "missing-state.json")
			for attempt := 0; attempt < 2; attempt++ {
				var err error
				if family == "proposal" {
					req := proposalRequest()
					proposal := req.GetSignProposalRequest().Proposal
					err = signer.SignProposal(chain, proposal)
					if len(proposal.Signature) != 0 {
						t.Fatal("unsynchronized signature published to caller")
					}
				} else {
					kind := tm.PrevoteType
					if family == "precommit" {
						kind = tm.PrecommitType
					}
					req := voteRequest(kind, 0, false)
					vote := req.GetSignVoteRequest().Vote
					err = signer.SignVote(chain, vote)
					if len(vote.Signature) != 0 || len(vote.ExtensionSignature) != 0 {
						t.Fatal("unsynchronized signatures published to caller")
					}
				}
				if !os.IsNotExist(err) {
					t.Fatalf("attempt %d accepted unavailable state: %v", attempt, err)
				}
			}
			// A synchronization fault must not discard the backend's HRS protection.
			signer.state = state
			if family == "proposal" {
				req := proposalRequest()
				proposal := req.GetSignProposalRequest().Proposal
				if err := signer.SignProposal(chain, proposal); err != nil || len(proposal.Signature) != 65 {
					t.Fatalf("durable cached proposal retry failed: %v", err)
				}
			} else {
				kind := tm.PrevoteType
				if family == "precommit" {
					kind = tm.PrecommitType
				}
				req := voteRequest(kind, 0, true)
				conflict := req.GetSignVoteRequest().Vote
				if err := signer.SignVote(chain, conflict); err == nil || len(conflict.Signature) != 0 {
					t.Fatal("synchronization failure lost double-sign protection")
				}
				req = voteRequest(kind, 0, false)
				vote := req.GetSignVoteRequest().Vote
				if err := signer.SignVote(chain, vote); err != nil || len(vote.Signature) != 65 {
					t.Fatalf("durable cached vote retry failed: %v", err)
				}
			}
		})
	}
}
