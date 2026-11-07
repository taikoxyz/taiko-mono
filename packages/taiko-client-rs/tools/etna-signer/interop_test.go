package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"math/big"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/types"
	"github.com/decred/dcrd/dcrec/secp256k1/v4/ecdsa"
)

// Exercise the guarded FilePV boundary against independent pinned wire/signature
// vectors, including nil votes, generation/domain changes and signed timestamps.
func TestGuardedFilePVMatchesCanonicalVoteVectors(t *testing.T) {
	raw, err := os.ReadFile("../../../../testdata/etna_vectors/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		Votes struct {
			Key struct {
				Private string `json:"private_key"`
				Public  string `json:"public_key"`
				Signer  string `json:"signer"`
			} `json:"key"`
			Cases []struct {
				Name      string            `json:"name"`
				Chain     string            `json:"chain_id"`
				Vote      map[string]string `json:"vote"`
				SignBytes string            `json:"sign_bytes"`
				Signature string            `json:"signature"`
			} `json:"cases"`
		} `json:"votes"`
	}
	if err = json.Unmarshal(raw, &fixture); err != nil {
		t.Fatal(err)
	}
	if len(fixture.Votes.Cases) != 23 {
		t.Fatal("missing vote fixtures")
	}
	for _, c := range fixture.Votes.Cases {
		t.Run(c.Name, func(t *testing.T) {
			number := func(field string) int64 {
				v, e := strconv.ParseInt(c.Vote[field], 10, 64)
				if e != nil {
					t.Fatal(e)
				}
				return v
			}
			vote := &tm.Vote{Type: tm.SignedMsgType(number("voteType")), Height: number("height"), Round: int32(number("round")), Timestamp: time.Unix(number("timestampSeconds"), number("timestampNanos"))}
			// The pinned oracle maps its all-zero fixture hashes to absent proto bytes.
			optionalHash := func(field string) []byte {
				raw := fromHex(t, c.Vote[field])
				if bytes.Equal(raw, make([]byte, 32)) {
					return nil
				}
				return raw
			}
			vote.BlockID = tm.BlockID{Hash: optionalHash("blockHash"), PartSetHeader: tm.PartSetHeader{Total: uint32(number("partsTotal")), Hash: optionalHash("partsHash")}}

			if !bytes.Equal(types.VoteSignBytes(c.Chain, vote), fromHex(t, c.SignBytes)) {
				t.Fatal("canonical Comet sign bytes mismatch")
			}
			dir := t.TempDir()
			key, state := filepath.Join(dir, "key"), filepath.Join(dir, "state")
			signer := privval.NewFilePV(secp256k1eth.PrivKey(fromHex(t, fixture.Votes.Key.Private)), key, state)
			signer.Save()
			path := control(t, func(map[string]any) any { r := snapshot(true); r["chain_id"] = c.Chain; return r })
			req := pv.Message{Sum: &pv.Message_SignVoteRequest{SignVoteRequest: &pv.SignVoteRequest{ChainId: c.Chain, Vote: vote}}}
			response, err := armed(path).handle(signer, req, c.Chain)
			if err != nil {
				t.Fatal(err)
			}
			signed := response.GetSignedVoteResponse()
			if signed.Error != nil || "0x"+hex.EncodeToString(signed.Vote.Signature) != c.Signature {
				t.Fatal("native FilePV signature differs from pinned stock vector")
			}
			if "0x"+hex.EncodeToString(signer.Key.PubKey.Bytes()) != fixture.Votes.Key.Public || "0x"+hex.EncodeToString(signer.Key.Address) != fixture.Votes.Key.Signer {
				t.Fatal("native identity mismatch")
			}
		})
	}
}

// Pin the stock verifier's inclusive half-order boundary. Recovering each
// synthetic signature's own key isolates scalar canonicality from signer match.
func TestNativeFilePVPublicKeyLowSInteropBoundary(t *testing.T) {
	dir := t.TempDir()
	key, state := filepath.Join(dir, "key"), filepath.Join(dir, "state")
	private := make(secp256k1eth.PrivKey, 32)
	private[31] = 0xa1
	privval.NewFilePV(private, key, state).Save()
	native, err := loadNativeKey(key)
	if err != nil {
		t.Fatal(err)
	}
	msg := []byte("Etna stock low-s boundary")
	signed, err := native.Sign(msg)
	if err != nil {
		t.Fatal(err)
	}
	order, _ := new(big.Int).SetString("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141", 16)
	half, _ := new(big.Int).SetString("7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0", 16)
	for _, c := range []struct {
		name string
		s    *big.Int
		want bool
	}{{"one", big.NewInt(1), true}, {"half", half, true}, {"half_plus_one", new(big.Int).Add(half, big.NewInt(1)), false}, {"high_s_twin", new(big.Int).Sub(order, new(big.Int).SetBytes(signed[32:64])), false}} {
		t.Run(c.name, func(t *testing.T) {
			sig := append([]byte(nil), signed...)
			c.s.FillBytes(sig[32:64])
			pub, _, err := ecdsa.RecoverCompact(append([]byte{sig[64] + 27}, sig[:64]...), testKeccak(msg))
			if err != nil {
				t.Fatal(err)
			}
			// Use the same concrete stock public-key type persisted by our bootstrap.
			if got := secp256k1eth.PubKey(pub.SerializeCompressed()).VerifySignature(msg, sig); got != c.want {
				t.Fatalf("low-s boundary accepted=%v want=%v", got, c.want)
			}
		})
	}
	for _, s := range []*big.Int{big.NewInt(0), order} {
		sig := append([]byte(nil), signed...)
		s.FillBytes(sig[32:64])
		if native.PubKey().VerifySignature(msg, sig) {
			t.Fatal("zero/order S accepted")
		}
	}
}

func TestRuntimeNeverRecreatesMissingStateForExistingNativeKey(t *testing.T) {
	binary := buildSigner(t)
	_, key, state := filePV(t)
	before, err := os.ReadFile(key)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.Remove(state); err != nil {
		t.Fatal(err)
	}
	args := []string{"--comet-signer-addr", "bad://transport", "--trust-socket", "/absent", "--chain-id", chain, "--priv-key", key, "--priv-state", state}
	if out, err := exec.Command(binary, args...).CombinedOutput(); err == nil || !strings.Contains(string(out), "existing signing file") {
		t.Fatalf("missing state accepted: %v %s", err, out)
	}
	if _, err = os.Stat(state); !os.IsNotExist(err) {
		t.Fatal("runtime initialized missing HRS")
	}
	after, _ := os.ReadFile(key)
	if !bytes.Equal(before, after) {
		t.Fatal("runtime modified authoritative key")
	}
}
