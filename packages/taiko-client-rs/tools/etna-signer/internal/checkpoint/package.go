// Package checkpoint installs an authenticated checkpoint window into fresh offline stock
// CometBFT stores. The Rust caller's authenticate_import is the only window authentication
// (DATA-5.4-2): it checks L1, envelopes, EL links, committees, commits and links. This package
// decodes the window, writes the stores and reopens them (DATA-5.4-3/4/5).
package checkpoint

import (
	"bytes"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	pb "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/types"
	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
)

const maxValidators = 65536

// MaxValidatorStateBytes bounds the two canonical ABI arrays before decoding keys.
const MaxValidatorStateBytes = 192 + 2*(32+128*maxValidators)

// Block is one blocks.jsonl line, the Rust WindowBlock shape: the original block bytes, its
// own-height commit bytes and the keys and powers that signed it.
type Block struct {
	Block      string      `json:"block"`
	Commit     string      `json:"commit"`
	Validators []Validator `json:"validators"`
}

// Validator supplies compressed SEC1 bytes and positive Comet voting power.
type Validator struct {
	Key   string `json:"key"`
	Power int64  `json:"power"`
}

// BlockID reports the full terminal identity, including the canonical part set.
type BlockID struct {
	Hash  string  `json:"hash"`
	Parts PartSet `json:"parts"`
}

// PartSet is the canonical stock block-part header.
type PartSet struct {
	Total uint32 `json:"total"`
	Hash  string `json:"hash"`
}

// Report names the installed window; the caller compares it with what it authenticated.
type Report struct {
	FirstHeight int64   `json:"first_height"`
	LastHeight  int64   `json:"last_height"`
	BlockID     BlockID `json:"block_id"`
}

// blockRecord is one decoded window height.
type blockRecord struct {
	block  *types.Block
	commit *types.Commit
	set    *types.ValidatorSet
	parts  *types.PartSet
	id     types.BlockID
}

func hexBytes(b []byte) string { return "0x" + hex.EncodeToString(b) }
func decodeHex(s string, max int) ([]byte, error) {
	if !strings.HasPrefix(s, "0x") || len(s)%2 != 0 || len(s) < 2 || len(s) > 2+2*max {
		return nil, errors.New("invalid or oversized 0x bytes")
	}
	return hex.DecodeString(s[2:])
}
func fixedParams(p types.ConsensusParams) bool {
	return p.Block.MaxBytes == 22020096 && p.Block.MaxGas == -1 && p.Evidence.MaxAgeNumBlocks == 100000 && p.Evidence.MaxAgeDuration == 48*time.Hour && p.Evidence.MaxBytes == 1048576 && len(p.Validator.PubKeyTypes) == 1 && p.Validator.PubKeyTypes[0] == "secp256k1eth" && p.Version.App == 1 && p.ABCI.VoteExtensionsEnableHeight == 0
}
func validatorSet(input []Validator) (*types.ValidatorSet, error) {
	if len(input) == 0 || len(input) > maxValidators {
		return nil, errors.New("invalid validator count")
	}
	vals := make([]*types.Validator, len(input))
	seen := map[string]bool{}
	var total int64
	for i, v := range input {
		k, e := decodeHex(v.Key, 33)
		if e != nil || len(k) != 33 || (k[0] != 2 && k[0] != 3) {
			return nil, errors.New("invalid compressed key")
		}
		if _, e = secp.ParsePubKey(k); e != nil {
			return nil, e
		}
		if v.Power <= 0 || v.Power > types.MaxTotalVotingPower-total {
			return nil, errors.New("invalid voting power")
		}
		total += v.Power
		pk := secp256k1eth.PubKey(k)
		addr := string(pk.Address())
		if seen[addr] {
			return nil, errors.New("duplicate validator")
		}
		seen[addr] = true
		vals[i] = types.NewValidator(pk, v.Power)
	}
	return types.NewValidatorSet(vals), nil
}

// DecodeValState strictly reads appendix A, retaining signed priorities and stored proposers.
func DecodeValState(raw []byte) (int64, *types.ValidatorSet, *types.ValidatorSet, error) {
	bad := func() (int64, *types.ValidatorSet, *types.ValidatorSet, error) {
		return 0, nil, nil, errors.New("noncanonical validator-state preimage")
	}
	if len(raw) < 256 || len(raw)%32 != 0 || len(raw) > MaxValidatorStateBytes {
		return bad()
	}
	tag := make([]byte, 32)
	copy(tag, "ETNA_VAL_STATE_V1")
	if !bytes.Equal(raw[:32], tag) {
		return bad()
	}
	word := func(at int) (uint64, bool) {
		b := raw[at : at+32]
		return binary.BigEndian.Uint64(b[24:]), bytes.Equal(b[:24], make([]byte, 24))
	}
	h, ok := word(32)
	if !ok || h == 0 || h > math.MaxInt64-2 {
		return bad()
	}
	off, ok := word(64)
	if !ok || off != 192 {
		return bad()
	}
	pa, ok := word(96)
	if !ok {
		return bad()
	}
	off2, ok := word(128)
	if !ok {
		return bad()
	}
	pbIndex, ok := word(160)
	if !ok {
		return bad()
	}
	pos := 192
	sets := make([]*types.ValidatorSet, 0, 2)
	for idx, proposer := range []uint64{pa, pbIndex} {
		if pos+32 > len(raw) || (idx == 1 && uint64(pos) != off2) {
			return bad()
		}
		count, ok := word(pos)
		pos += 32
		if !ok || count == 0 || count > maxValidators || count > uint64((len(raw)-pos)/128) || proposer >= count {
			return bad()
		}
		input := make([]Validator, int(count))
		priorities := make([]int64, int(count))
		for i := range input {
			prefix, ok := word(pos)
			if !ok || (prefix != 2 && prefix != 3) {
				return bad()
			}
			key := append([]byte{byte(prefix)}, raw[pos+32:pos+64]...)
			power, ok := word(pos + 64)
			if !ok || power > math.MaxInt64 {
				return bad()
			}
			input[i] = Validator{Key: hexBytes(key), Power: int64(power)}
			priority := int64(binary.BigEndian.Uint64(raw[pos+120 : pos+128]))
			fill := byte(0)
			if priority < 0 {
				fill = 255
			}
			if !bytes.Equal(raw[pos+96:pos+120], bytes.Repeat([]byte{fill}, 24)) {
				return bad()
			}
			priorities[i] = priority
			pos += 128
		}
		set, e := validatorSet(input)
		if e != nil {
			return bad()
		}
		for i, v := range set.Validators {
			if hexBytes(v.PubKey.Bytes()) != input[i].Key {
				return bad()
			}
			v.ProposerPriority = priorities[i]
		}
		set.Proposer = set.Validators[int(proposer)].Copy()
		sets = append(sets, set)
	}
	if pos != len(raw) {
		return bad()
	}
	return int64(h), sets[0], sets[1], nil
}

// decodeGenesis reads the original GenesisDoc. Stock parsing turns InitialHeight 0 into 1,
// so the original value is read first and must already be positive.
func decodeGenesis(raw []byte) (*types.GenesisDoc, error) {
	var identity struct {
		InitialHeight string `json:"initial_height"`
	}
	if e := json.Unmarshal(raw, &identity); e != nil {
		return nil, e
	}
	originalHeight, e := strconv.ParseInt(identity.InitialHeight, 10, 64)
	if e != nil || originalHeight < 1 {
		return nil, errors.New("missing or nonpositive original InitialHeight")
	}
	g, e := types.GenesisDocFromJSON(raw)
	if e != nil {
		return nil, e
	}
	if g.InitialHeight != originalHeight || g.InitialHeight > math.MaxInt64-2 || g.ConsensusParams == nil || !fixedParams(*g.ConsensusParams) {
		return nil, errors.New("unsupported genesis parameters")
	}
	return g, nil
}

// decodeBlock decodes one line's canonical protobufs and computes the block's full ID. It
// checks no commit, link or block rule: authenticate_import already did (DATA-5.4-3).
func decodeBlock(g *types.GenesisDoc, item Block) (*blockRecord, error) {
	bb, e := decodeHex(item.Block, int(g.ConsensusParams.Block.MaxBytes))
	if e != nil {
		return nil, e
	}
	cb, e := decodeHex(item.Commit, 16<<20)
	if e != nil {
		return nil, e
	}
	var bp pb.Block
	var cp pb.Commit
	if e = bp.Unmarshal(bb); e != nil {
		return nil, e
	}
	canonical, e := bp.Marshal()
	if e != nil || !bytes.Equal(bb, canonical) {
		return nil, errors.New("noncanonical block protobuf")
	}
	if e = cp.Unmarshal(cb); e != nil {
		return nil, e
	}
	canonical, e = cp.Marshal()
	if e != nil || !bytes.Equal(cb, canonical) {
		return nil, errors.New("noncanonical commit protobuf")
	}
	b, e := types.BlockFromProto(&bp)
	if e != nil {
		return nil, e
	}
	c, e := types.CommitFromProto(&cp)
	if e != nil {
		return nil, e
	}
	// Stock SaveBlock stores the converted values, so they must keep the original bytes.
	stockBlock, e := b.ToProto()
	if e != nil {
		return nil, e
	}
	stockBytes, e := stockBlock.Marshal()
	if e != nil || !bytes.Equal(stockBytes, bb) {
		return nil, errors.New("block conversion changed original bytes")
	}
	stockBytes, e = c.ToProto().Marshal()
	if e != nil || !bytes.Equal(stockBytes, cb) {
		return nil, errors.New("commit conversion changed original bytes")
	}
	set, e := validatorSet(item.Validators)
	if e != nil {
		return nil, e
	}
	parts, e := b.MakePartSet(types.BlockPartSizeBytes)
	if e != nil {
		return nil, e
	}
	return &blockRecord{block: b, commit: c, set: set, parts: parts, id: types.BlockID{Hash: b.Hash(), PartSetHeader: parts.Header()}}, nil
}
