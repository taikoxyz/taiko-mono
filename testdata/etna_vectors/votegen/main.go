// Command votegen signs Etna vote vectors with stock CometBFT v0.40.0.
//
// It reads {"key": hex32, "votes": [{"name", "chain_id", "vote": {...}}]} on stdin and writes
// {"public_key", "signer", "cases": [{"name", "sign_bytes", "signature"}]} on stdout. Sign bytes
// come from types.VoteSignBytes and signatures from the secp256k1eth key type, so the vectors
// reflect what a CometBFT validator signs. Vote integers are decimal strings; an all-zero 32-byte
// hash is an absent (empty) hash, as in the Etna spec's appendix A.
//
// generate.py runs it with `go run .` from this directory; no other module imports it.
package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	cmtproto "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/types"
)

type vote struct {
	VoteType         string `json:"voteType"`
	Height           string `json:"height"`
	Round            string `json:"round"`
	BlockHash        string `json:"blockHash"`
	PartsTotal       string `json:"partsTotal"`
	PartsHash        string `json:"partsHash"`
	TimestampSeconds string `json:"timestampSeconds"`
	TimestampNanos   string `json:"timestampNanos"`
	Generation       string `json:"generation"`
}

type input struct {
	Key   string `json:"key"`
	Votes []struct {
		Name    string `json:"name"`
		ChainID string `json:"chain_id"`
		Vote    vote   `json:"vote"`
	} `json:"votes"`
}

type outputCase struct {
	Name      string `json:"name"`
	SignBytes string `json:"sign_bytes"`
	Signature string `json:"signature"`
}

type output struct {
	PublicKey string       `json:"public_key"`
	Signer    string       `json:"signer"`
	Cases     []outputCase `json:"cases"`
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "votegen:", err)
		os.Exit(1)
	}
}

func run() error {
	dec := json.NewDecoder(os.Stdin)
	dec.DisallowUnknownFields()
	var in input
	if err := dec.Decode(&in); err != nil {
		return fmt.Errorf("decode input: %w", err)
	}
	keyBytes, err := decodeHex(in.Key, 32)
	if err != nil {
		return fmt.Errorf("key: %w", err)
	}
	key := secp256k1eth.PrivKey(keyBytes)
	pub := key.PubKey()

	out := output{
		PublicKey: "0x" + hex.EncodeToString(pub.Bytes()),
		Signer:    "0x" + hex.EncodeToString(pub.Address()),
		Cases:     make([]outputCase, 0, len(in.Votes)),
	}
	for _, item := range in.Votes {
		v, err := toProto(item.Vote)
		if err != nil {
			return fmt.Errorf("%s: %w", item.Name, err)
		}
		signBytes := types.VoteSignBytes(item.ChainID, v)
		sig, err := key.Sign(signBytes)
		if err != nil {
			return fmt.Errorf("%s: sign: %w", item.Name, err)
		}
		if !pub.VerifySignature(signBytes, sig) {
			return fmt.Errorf("%s: signature does not verify", item.Name)
		}
		out.Cases = append(out.Cases, outputCase{
			Name:      item.Name,
			SignBytes: "0x" + hex.EncodeToString(signBytes),
			Signature: "0x" + hex.EncodeToString(sig),
		})
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	return enc.Encode(out)
}

// toProto builds the cmtproto.Vote whose canonical form CometBFT signs.
func toProto(in vote) (*cmtproto.Vote, error) {
	voteType, err := strconv.ParseInt(in.VoteType, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("voteType: %w", err)
	}
	height, err := strconv.ParseInt(in.Height, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("height: %w", err)
	}
	round, err := strconv.ParseInt(in.Round, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("round: %w", err)
	}
	total, err := strconv.ParseUint(in.PartsTotal, 10, 32)
	if err != nil {
		return nil, fmt.Errorf("partsTotal: %w", err)
	}
	seconds, err := strconv.ParseInt(in.TimestampSeconds, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("timestampSeconds: %w", err)
	}
	nanos, err := strconv.ParseInt(in.TimestampNanos, 10, 64)
	if err != nil || nanos < 0 || nanos >= int64(time.Second) {
		return nil, fmt.Errorf("timestampNanos %q out of range", in.TimestampNanos)
	}
	blockHash, err := optionalHash(in.BlockHash)
	if err != nil {
		return nil, fmt.Errorf("blockHash: %w", err)
	}
	partsHash, err := optionalHash(in.PartsHash)
	if err != nil {
		return nil, fmt.Errorf("partsHash: %w", err)
	}
	return &cmtproto.Vote{
		Type:   cmtproto.SignedMsgType(voteType),
		Height: height,
		Round:  int32(round),
		BlockID: cmtproto.BlockID{
			Hash: blockHash,
			PartSetHeader: cmtproto.PartSetHeader{
				Total: uint32(total),
				Hash:  partsHash,
			},
		},
		Timestamp: time.Unix(seconds, nanos).UTC(),
	}, nil
}

// optionalHash decodes a 32-byte hash, mapping the all-zero hash to an empty (absent) one.
func optionalHash(s string) ([]byte, error) {
	b, err := decodeHex(s, 32)
	if err != nil {
		return nil, err
	}
	if bytes.Equal(b, make([]byte, 32)) {
		return []byte{}, nil
	}
	return b, nil
}

func decodeHex(s string, size int) ([]byte, error) {
	if !strings.HasPrefix(s, "0x") {
		return nil, fmt.Errorf("%q has no 0x prefix", s)
	}
	b, err := hex.DecodeString(s[2:])
	if err != nil {
		return nil, err
	}
	if len(b) != size {
		return nil, fmt.Errorf("%q is %d bytes, want %d", s, len(b), size)
	}
	return b, nil
}
