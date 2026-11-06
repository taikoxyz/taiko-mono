// Package checkpoint authenticates original Comet bytes and builds offline stock stores.
// L1 authentication, envelope/EL checks and committee derivation belong to the Rust caller.
package checkpoint

import (
	"bytes"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"strconv"
	"strings"
	"time"

	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	pb "github.com/cometbft/cometbft/proto/tendermint/types"
	sm "github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/types"
	secp "github.com/decred/dcrd/dcrec/secp256k1/v4"
	"golang.org/x/crypto/sha3"
)

// MaxPackageBytes bounds decoding memory; larger packages must use another offline resource profile.
const MaxPackageBytes int64 = 1 << 30
const maxValidators = 65536

// MaxValidatorStateBytes bounds the two canonical ABI arrays before decoding keys.
const MaxValidatorStateBytes = 192 + 2*(32+128*maxValidators)

// Package contains public consensus data only, never keys, WAL or signer state.
type Package struct {
	Schema         uint32          `json:"schema"`
	Genesis        json.RawMessage `json:"genesis"`
	Blocks         []Block         `json:"blocks"`
	ValidatorState string          `json:"validator_state"`
}

// Block retains original bytes and its signing committee. A nonterminal Commit
// must equal the successor block's embedded LastCommit byte for byte.
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

// Trust is supplied separately by the own-finalized-L1 verifier, never read from Package.
type Trust struct {
	CometHash    string
	ELHash       string
	ValStateHash string
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

// Report is deterministic verification output; it grants no admission or signing authority.
type Report struct {
	Schema             uint32    `json:"schema"`
	FirstHeight        int64     `json:"first_height"`
	LastHeight         int64     `json:"last_height"`
	BlockID            BlockID   `json:"block_id"`
	TerminalTime       time.Time `json:"terminal_time"`
	ChainID            string    `json:"chain_id"`
	InitialHeight      int64     `json:"initial_height"`
	ValidatorsHash     string    `json:"validators_hash"`
	NextValidatorsHash string    `json:"next_validators_hash"`
	PackageHash        string    `json:"package_hash"`
}

// Verified keeps installable values private; disk-backed windows have bounded memory.
type Verified struct {
	report     Report
	genesisRaw []byte
	genesis    *types.GenesisDoc
	state      sm.State
	walk       func(func(*blockRecord) error) error
	cleanup    func() error
}
type blockRecord struct {
	block  *types.Block
	commit *types.Commit
	set    *types.ValidatorSet
	id     types.BlockID
}

// Close removes only this verification's private spool, if one was created.
func (v *Verified) Close() error {
	if v.cleanup != nil {
		return v.cleanup()
	}
	return nil
}

// Report returns the public, nonauthorizing verification summary.
func (v *Verified) Report() Report { return v.report }

// ContradictionError means authenticated bytes contradict the authenticated landing.
// Callers must durably safety-halt rather than retry another publisher.
type ContradictionError struct{ Reason string }

func (e *ContradictionError) Error() string { return "authenticated contradiction: " + e.Reason }
func hexBytes(b []byte) string              { return "0x" + hex.EncodeToString(b) }
func keccak(b []byte) []byte                { h := sha3.NewLegacyKeccak256(); _, _ = h.Write(b); return h.Sum(nil) }
func decodeHex(s string, max int) ([]byte, error) {
	if !strings.HasPrefix(s, "0x") || len(s)%2 != 0 || len(s) < 2 || len(s) > 2+2*max {
		return nil, errors.New("invalid or oversized 0x bytes")
	}
	return hex.DecodeString(s[2:])
}
func hashInput(s string) ([]byte, error) {
	b, e := decodeHex(s, 32)
	if e != nil || len(b) != 32 {
		return nil, errors.New("trusted hash must have 32 bytes")
	}
	return b, nil
}

// Read decodes one strict JSON object with an explicit byte bound and no trailing material.
func Read(r io.Reader) (*Package, error) { return ReadBounded(r, MaxPackageBytes) }

// ReadBounded accepts an operator resource limit no greater than the supported profile.
func ReadBounded(r io.Reader, limit int64) (*Package, error) {
	if limit <= 0 || limit > MaxPackageBytes {
		return nil, errors.New("invalid package byte limit")
	}
	raw, err := io.ReadAll(io.LimitReader(r, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(raw)) > limit {
		return nil, errors.New("package byte limit exceeded")
	}
	var p Package
	if err = strictDecode(raw, &p); err != nil {
		return nil, err
	}
	return &p, nil
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

// Verify checks original canonical bytes, hashes, committees and every height's own commit.
// The first retained LastCommit and historical evidence receive basic structural
// validation only; later LastCommits are verified against the retained predecessor.
func Verify(p *Package, trust Trust) (*Verified, error) {
	if p == nil {
		return nil, errors.New("missing package")
	}
	encoded, e := json.Marshal(p)
	if e != nil {
		return nil, e
	}
	return verifySource(p, trust, func(visit func(Block) error) error {
		for _, item := range p.Blocks {
			if e := visit(item); e != nil {
				return e
			}
		}
		return nil
	}, hexBytes(keccak(encoded)), true)
}
func verifyItem(g *types.GenesisDoc, item Block, previous *blockRecord) (*blockRecord, error) {
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
	if e = b.ValidateBasic(); e != nil {
		return nil, e
	}
	if e = c.ValidateBasic(); e != nil {
		return nil, e
	}
	if b.ChainID != g.ChainID || b.Height < g.InitialHeight || b.Height > math.MaxInt64-2 || len(b.Data.Txs) != 1 || b.Version.App != 1 || !bytes.Equal(b.ConsensusHash, g.ConsensusParams.Hash()) {
		return nil, errors.New("block identity, params or transaction shape mismatch")
	}
	if previous != nil && (b.Height != previous.block.Height+1 || !b.LastBlockID.Equals(previous.id) || !b.Time.After(previous.block.Time)) {
		return nil, errors.New("broken original window chain")
	}
	set, e := validatorSet(item.Validators)
	if e != nil {
		return nil, e
	}
	if !bytes.Equal(set.Hash(), b.ValidatorsHash) {
		return nil, errors.New("signing validator hash mismatch")
	}
	parts, e := b.MakePartSet(types.BlockPartSizeBytes)
	if e != nil {
		return nil, e
	}
	id := types.BlockID{Hash: b.Hash(), PartSetHeader: parts.Header()}
	if !c.BlockID.Equals(id) {
		return nil, errors.New("commit full BlockID mismatch")
	}
	if e = set.VerifyCommit(g.ChainID, id, b.Height, c); e != nil {
		return nil, e
	}
	if previous != nil {
		// This embedded commit, not merely the redundant package field, becomes C:h.
		if e = previous.set.VerifyCommit(g.ChainID, previous.id, previous.block.Height, b.LastCommit); e != nil {
			return nil, fmt.Errorf("invalid successor LastCommit at %d: %w", b.Height, e)
		}
		embedded, e := b.LastCommit.ToProto().Marshal()
		if e != nil {
			return nil, e
		}
		redundant, e := previous.commit.ToProto().Marshal()
		if e != nil {
			return nil, e
		}
		if !bytes.Equal(embedded, redundant) {
			return nil, errors.New("nonterminal commit differs from successor LastCommit")
		}
	}
	if previous != nil && !bytes.Equal(previous.block.NextValidatorsHash, b.ValidatorsHash) {
		return nil, errors.New("next validator linkage mismatch")
	}
	return &blockRecord{block: b, commit: c, set: set, id: id}, nil
}
func verifySource(p *Package, trust Trust, source func(func(Block) error) error, packageHash string, retain bool) (out *Verified, err error) {
	defer func() {
		if r := recover(); r != nil {
			out = nil
			err = fmt.Errorf("invalid stock package: %v", r)
		}
	}()
	if p == nil || p.Schema != 1 {
		return nil, errors.New("unsupported or empty package")
	}
	comet, e := hashInput(trust.CometHash)
	if e != nil {
		return nil, e
	}
	el, e := hashInput(trust.ELHash)
	if e != nil {
		return nil, e
	}
	vh, e := hashInput(trust.ValStateHash)
	if e != nil {
		return nil, e
	}
	var identity struct {
		InitialHeight string `json:"initial_height"`
	}
	if e = json.Unmarshal(p.Genesis, &identity); e != nil {
		return nil, e
	}
	originalHeight, e := strconv.ParseInt(identity.InitialHeight, 10, 64)
	if e != nil || originalHeight < 1 {
		return nil, errors.New("missing or nonpositive original InitialHeight")
	}
	g, e := types.GenesisDocFromJSON(p.Genesis)
	if e != nil {
		return nil, e
	}
	if g.InitialHeight != originalHeight || g.InitialHeight < 1 || g.InitialHeight > math.MaxInt64-2 || g.ConsensusParams == nil || !fixedParams(*g.ConsensusParams) {
		return nil, errors.New("unsupported genesis parameters")
	}
	raw, e := decodeHex(p.ValidatorState, MaxValidatorStateBytes)
	if e != nil {
		return nil, e
	}
	if !bytes.Equal(keccak(raw), vh) {
		return nil, errors.New("validator-state hash mismatch")
	}
	height, current, next, e := DecodeValState(raw)
	if e != nil {
		return nil, e
	}
	v := &Verified{genesisRaw: bytes.Clone(p.Genesis), genesis: g}
	var previous *blockRecord
	var firstHeight int64
	var retained []*blockRecord
	err = source(func(item Block) error {
		record, e := verifyItem(g, item, previous)
		if e != nil {
			return e
		}
		if previous == nil {
			firstHeight = record.block.Height
		}
		previous = record
		if retain {
			retained = append(retained, record)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	if previous == nil {
		return nil, errors.New("empty consensus window")
	}
	terminal := previous.block
	lastID := previous.id
	if terminal.Height != height || !bytes.Equal(lastID.Hash, comet) {
		return nil, errors.New("terminal trusted Comet hash or height mismatch")
	}
	if !bytes.Equal(current.Hash(), terminal.NextValidatorsHash) {
		return nil, &ContradictionError{Reason: "landed state contradicts next_validators_hash"}
	}
	s, e := sm.MakeGenesisState(g)
	if e != nil {
		return nil, e
	}
	s.Version.Consensus.App = 1
	s.LastBlockHeight = height
	s.LastBlockID = lastID
	s.LastBlockTime = terminal.Time
	s.LastValidators = previous.set.Copy()
	s.Validators = current
	s.NextValidators = next
	s.LastHeightValidatorsChanged = height + 2
	s.LastHeightConsensusParamsChanged = height + 1
	s.LastResultsHash = types.NewResults([]*abci.ExecTxResult{{}}).Hash()
	s.AppHash = el
	v.state = s
	if retain {
		v.walk = func(visit func(*blockRecord) error) error {
			for _, r := range retained {
				if e := visit(r); e != nil {
					return e
				}
			}
			return nil
		}
	} else {
		v.walk = func(visit func(*blockRecord) error) error {
			var prev *blockRecord
			return source(func(item Block) error {
				record, e := verifyItem(g, item, prev)
				if e != nil {
					return e
				}
				prev = record
				return visit(record)
			})
		}
	}
	v.report = Report{Schema: 1, FirstHeight: firstHeight, LastHeight: height, BlockID: BlockID{Hash: hexBytes(lastID.Hash), Parts: PartSet{Total: lastID.PartSetHeader.Total, Hash: hexBytes(lastID.PartSetHeader.Hash)}}, TerminalTime: terminal.Time, ChainID: g.ChainID, InitialHeight: g.InitialHeight, ValidatorsHash: hexBytes(current.Hash()), NextValidatorsHash: hexBytes(next.Hash()), PackageHash: packageHash}
	return v, nil
}
