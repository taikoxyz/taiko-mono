// Regenerates consensus byte/hash vectors using stock CometBFT v0.40.0.
// Invoke generate.sh; the fixture envelope is a deterministic Rust Etna v6 transaction.
package main

import (
	"bytes"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"math/rand/v2"
	"os"
	"strings"
	"time"

	"github.com/cometbft/cometbft/crypto"
	"github.com/cometbft/cometbft/crypto/secp256k1"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	cmtproto "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/types"
)

type vector struct {
	Name         string          `json:"name"`
	BlockRPC     json.RawMessage `json:"block_rpc"`
	CommitRPC    json.RawMessage `json:"commit_rpc"`
	BlockProto   string          `json:"block_proto"`
	EvidenceHash string          `json:"evidence_hash"`
	PartsHash    string          `json:"parts_hash"`
	PartsTotal   uint32          `json:"parts_total"`
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}

func key(seed byte) secp256k1eth.PrivKey {
	// Canonical nonzero secp256k1 scalar shared with the Rust fixture.
	return secp256k1eth.PrivKey(bytes.Repeat([]byte{seed}, 32))
}

func signVote(k secp256k1eth.PrivKey, id types.BlockID) *types.Vote {
	v := &types.Vote{
		Type: cmtproto.PrecommitType, Height: 1, Round: 0, BlockID: id,
		Timestamp: time.Unix(100, 0).UTC(), ValidatorAddress: k.PubKey().Address(),
		ValidatorIndex: 1,
	}
	var err error
	v.Signature, err = k.Sign(types.VoteSignBytes(chainID, v.ToProto()))
	must(err)
	return v
}

func commit(header types.Header, id types.BlockID, vals *types.ValidatorSet) *types.Commit {
	result := &types.Commit{Height: header.Height, Round: 0, BlockID: id}
	for index, v := range vals.Validators {
		k := key(1)
		if !bytes.Equal(k.PubKey().Bytes(), v.PubKey.Bytes()) {
			k = key(2)
		}
		vote := &types.Vote{
			Type: cmtproto.PrecommitType, Height: result.Height, Round: result.Round,
			BlockID: id, Timestamp: header.Time, ValidatorAddress: v.Address,
			ValidatorIndex: int32(index),
		}
		message := types.VoteSignBytes(header.ChainID, vote.ToProto())
		signature, err := k.Sign(message)
		must(err)
		result.Signatures = append(result.Signatures, types.CommitSig{
			BlockIDFlag: types.BlockIDFlagCommit, ValidatorAddress: v.Address,
			Timestamp: vote.Timestamp, Signature: signature,
		})
	}
	must(vals.VerifyCommit(header.ChainID, id, header.Height, result))
	return result
}

func block(evidence types.Evidence, envelope []byte, vals *types.ValidatorSet) vector {
	b := &types.Block{
		Header: types.Header{
			ChainID: chainID, Height: 1, Time: time.Unix(101, 0).UTC(),
			ValidatorsHash: vals.Hash(), NextValidatorsHash: vals.Hash(),
			ConsensusHash: bytes.Repeat([]byte{2}, 32), AppHash: make([]byte, 32),
			ProposerAddress: vals.Validators[0].Address,
		},
		Data:       types.Data{Txs: types.Txs{types.Tx(envelope)}},
		Evidence:   types.EvidenceData{Evidence: types.EvidenceList{evidence}},
		LastCommit: &types.Commit{},
	}
	b.Header.Version.Block = 11
	b.Header.Version.App = 1
	hash := b.Hash()
	parts, err := b.MakePartSet(65536)
	must(err)
	id := types.BlockID{Hash: hash, PartSetHeader: parts.Header()}
	c := commit(b.Header, id, vals)
	raw, err := b.ToProto()
	must(err)
	proto, err := raw.Marshal()
	must(err)
	blockJSON, err := cmtjson.Marshal(struct {
		BlockID types.BlockID `json:"block_id"`
		Block   *types.Block  `json:"block"`
	}{id, b})
	must(err)
	commitJSON, err := cmtjson.Marshal(struct {
		SignedHeader *types.SignedHeader `json:"signed_header"`
		Canonical    bool                `json:"canonical"`
	}{&types.SignedHeader{Header: &b.Header, Commit: c}, true})
	must(err)
	return vector{
		BlockRPC: blockJSON, CommitRPC: commitJSON, BlockProto: hex.EncodeToString(proto),
		EvidenceHash: hex.EncodeToString(b.EvidenceHash), PartsHash: hex.EncodeToString(id.PartSetHeader.Hash),
		PartsTotal: id.PartSetHeader.Total,
	}
}

func main() {
	input, err := os.ReadFile(os.Args[1])
	must(err)
	envelope, err := base64.StdEncoding.DecodeString(string(bytes.TrimSpace(input)))
	must(err)
	vals := types.NewValidatorSet([]*types.Validator{
		types.NewValidator(key(1).PubKey(), 10), types.NewValidator(key(2).PubKey(), 30),
	})
	id := func(value byte) types.BlockID {
		return types.BlockID{Hash: bytes.Repeat([]byte{value}, 32), PartSetHeader: types.PartSetHeader{
			Total: 1, Hash: bytes.Repeat([]byte{value + 1}, 32),
		}}
	}
	dve, err := types.NewDuplicateVoteEvidence(signVote(key(1), id(3)), signVote(key(1), id(5)), time.Unix(100, 0).UTC(), vals)
	must(err)
	nilDve, err := types.NewDuplicateVoteEvidence(signVote(key(1), types.BlockID{}), signVote(key(1), id(5)), time.Unix(100, 0).UTC(), vals)
	must(err)
	// Vote signatures do not cover extensions, so anyone can attach one to a double-signed
	// precommit; CometBFT verifies and commits such evidence, and its JSON carries base64 bytes.
	// Evidence never checks the extension signature, whose length may be anything up to
	// MaxSignatureSize, with or without an extension.
	extendedDve := func(extension []byte, signature int) *types.DuplicateVoteEvidence {
		extended := signVote(key(1), id(3))
		extended.Extension = extension
		extended.ExtensionSignature = bytes.Repeat([]byte{9}, signature)
		evidence, err := types.NewDuplicateVoteEvidence(extended, signVote(key(1), id(5)), time.Unix(100, 0).UTC(), vals)
		must(err)
		must(evidence.ValidateBasic())
		return evidence
	}
	conflicting := types.Header{
		ChainID: chainID, Height: 2, Time: time.Unix(102, 0).UTC(),
		ValidatorsHash: vals.Hash(), NextValidatorsHash: vals.Hash(),
		ConsensusHash: bytes.Repeat([]byte{2}, 32), AppHash: bytes.Repeat([]byte{7}, 32),
		ProposerAddress: vals.Validators[0].Address,
	}
	conflicting.Version.Block = 11
	conflicting.Version.App = 1
	conflictingID := id(8)
	conflictingID.Hash = conflicting.Hash()
	lca := &types.LightClientAttackEvidence{
		ConflictingBlock: &types.LightBlock{
			SignedHeader: &types.SignedHeader{Header: &conflicting, Commit: commit(conflicting, conflictingID, vals)},
			ValidatorSet: vals,
		},
		CommonHeight: 1, ByzantineValidators: []*types.Validator{vals.Validators[1]},
		TotalVotingPower: 40, Timestamp: time.Unix(100, 0).UTC(),
	}
	var result []vector
	for _, item := range []struct {
		name     string
		evidence types.Evidence
	}{{"duplicate_vote", dve}, {"duplicate_vote_nil", nilDve}, {"duplicate_vote_extension", extendedDve([]byte{1, 2, 3}, 64)},
		{"duplicate_vote_extension_signature_65", extendedDve([]byte{1, 2, 3}, 65)},
		{"duplicate_vote_extension_signature_only_96", extendedDve(nil, 96)},
		{"light_client_attack", lca}} {
		v := block(item.evidence, envelope, vals)
		v.Name = item.name
		result = append(result, v)
	}
	output, err := json.MarshalIndent(struct {
		Provenance string   `json:"provenance"`
		Vectors    []vector `json:"vectors"`
	}{"github.com/cometbft/cometbft v0.40.0; secp256k1eth; Go 1.27.2; generate.sh", result}, "", "  ")
	must(err)
	must(os.WriteFile(os.Args[2], append(output, '\n'), 0644))
	differentialOutput, err := json.MarshalIndent(struct {
		Provenance string               `json:"provenance"`
		Vectors    []differentialVector `json:"vectors"`
	}{"github.com/cometbft/cometbft v0.40.0; secp256k1eth; Go 1.27.2; generate.sh; seeded PCG(22280, 2026)", differentialVectors(envelope)}, "", "  ")
	must(err)
	must(os.WriteFile(os.Args[3], append(differentialOutput, '\n'), 0644))
}

// differentialVector is one stock-encoded block and certificate for byte-for-byte comparison:
// the Rust lander must read the JSON both RPCs serve back into exactly these protobufs.
type differentialVector struct {
	Name         string          `json:"name"`
	Height       int64           `json:"height"`
	Powers       string          `json:"powers"`
	BlockRPC     json.RawMessage `json:"block_rpc"`
	CommitRPC    json.RawMessage `json:"commit_rpc"`
	BlockProto   string          `json:"block_proto"`
	CommitProto  string          `json:"commit_proto"`
	EvidenceHash string          `json:"evidence_hash"`
	PartsHash    string          `json:"parts_hash"`
	PartsTotal   uint32          `json:"parts_total"`
}

// Schema-4 chain_domains[0]: L1=1, L2=167001, Inbox=0x1111...1111, generation=0.
const chainID = "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"

var epoch = time.Unix(0, 0).UTC()

// joinPowers lists powers comma-separated: a string the repository's JSON formatter never
// rewraps, unlike a long number array.
func joinPowers(powers []int64) string {
	fields := make([]string, len(powers))
	for i, power := range powers {
		fields[i] = fmt.Sprint(power)
	}
	return strings.Join(fields, ",")
}

// validatorSet assigns powers[i] to key(i+1).
func validatorSet(powers []int64) *types.ValidatorSet {
	validators := make([]*types.Validator, len(powers))
	for i, power := range powers {
		validators[i] = types.NewValidator(key(byte(i+1)).PubKey(), power)
	}
	return types.NewValidatorSet(validators)
}

// secpKey is the one secp256k1 fixture key, for a light-client attack's lunatic validator set.
var secpKey = secp256k1.GenPrivKeySecp256k1([]byte("lander differential secp256k1"))

// keyOf is the fixture key whose public key is v's.
func keyOf(v *types.Validator) crypto.PrivKey {
	if bytes.Equal(secpKey.PubKey().Bytes(), v.PubKey.Bytes()) {
		return secpKey
	}
	for seed := 1; seed <= 255; seed++ {
		if bytes.Equal(key(byte(seed)).PubKey().Bytes(), v.PubKey.Bytes()) {
			return key(byte(seed))
		}
	}
	panic("validator without a fixture key")
}

// sigSpec is one validator's entry in a commit: its flag and its signed vote time.
type sigSpec struct {
	flag types.BlockIDFlag
	time time.Time
}

// signedCommit signs every validator's precommit for `id` (or nil) at its own time; absent
// entries carry Go's zero time, as CometBFT requires.
func signedCommit(height int64, round int32, id types.BlockID, vals *types.ValidatorSet, specs []sigSpec) *types.Commit {
	result := &types.Commit{Height: height, Round: round, BlockID: id}
	for index, v := range vals.Validators {
		spec := specs[index]
		if spec.flag == types.BlockIDFlagAbsent {
			result.Signatures = append(result.Signatures, types.NewCommitSigAbsent())
			continue
		}
		voted := id
		if spec.flag == types.BlockIDFlagNil {
			voted = types.BlockID{}
		}
		vote := &types.Vote{
			Type: cmtproto.PrecommitType, Height: height, Round: round, BlockID: voted,
			Timestamp: spec.time, ValidatorAddress: v.Address, ValidatorIndex: int32(index),
		}
		signature, err := keyOf(v).Sign(types.VoteSignBytes(chainID, vote.ToProto()))
		must(err)
		result.Signatures = append(result.Signatures, types.CommitSig{
			BlockIDFlag: spec.flag, ValidatorAddress: v.Address, Timestamp: spec.time, Signature: signature,
		})
	}
	must(result.ValidateBasic())
	return result
}

// blockOption adjusts a differential block before it is hashed, or the round of its commit.
type blockOption struct {
	round int32
	app   uint64
}

// differential builds a block at `height` over `last` (nil at height 1) carrying `evidence`,
// certifies it with `own`, checks it with stock validation and exports it as CometBFT's RPC
// serves a stored block and commit (decoded from their protobufs).
func differential(name string, height int64, at time.Time, powers []int64, last *types.Commit, evidence []types.Evidence, own []sigSpec, envelope []byte, options ...blockOption) differentialVector {
	var option blockOption
	if len(options) > 0 {
		option = options[0]
	}
	vals := validatorSet(powers)
	b := &types.Block{
		Header: types.Header{
			ChainID: chainID, Height: height, Time: at,
			ValidatorsHash: vals.Hash(), NextValidatorsHash: vals.Hash(),
			ConsensusHash: bytes.Repeat([]byte{2}, 32), AppHash: make([]byte, 32),
			ProposerAddress: vals.Validators[0].Address,
		},
		Data:       types.Data{Txs: types.Txs{types.Tx(envelope)}},
		Evidence:   types.EvidenceData{Evidence: evidence},
		LastCommit: &types.Commit{},
	}
	b.Header.Version.Block = 11
	b.Header.Version.App = 1
	if option.app != 0 {
		b.Header.Version.App = option.app
	}
	if last != nil {
		b.LastCommit = last
		b.Header.LastBlockID = last.BlockID
	}
	hash := b.Hash()
	must(b.ValidateBasic())
	parts, err := b.MakePartSet(65536)
	must(err)
	id := types.BlockID{Hash: hash, PartSetHeader: parts.Header()}
	c := signedCommit(height, option.round, id, vals, own)
	must(vals.VerifyCommit(chainID, id, height, c))
	raw, err := b.ToProto()
	must(err)
	blockProto, err := raw.Marshal()
	must(err)
	commitProto, err := c.ToProto().Marshal()
	must(err)
	// The RPC serves blocks and commits loaded from the store, i.e. decoded from protobufs:
	// empty lists then encode as [] rather than null.
	stored, err := types.BlockFromProto(raw)
	must(err)
	storedCommit, err := types.CommitFromProto(c.ToProto())
	must(err)
	blockJSON, err := cmtjson.Marshal(struct {
		BlockID types.BlockID `json:"block_id"`
		Block   *types.Block  `json:"block"`
	}{id, stored})
	must(err)
	commitJSON, err := cmtjson.Marshal(struct {
		SignedHeader *types.SignedHeader `json:"signed_header"`
		Canonical    bool                `json:"canonical"`
	}{&types.SignedHeader{Header: &stored.Header, Commit: storedCommit}, true})
	must(err)
	return differentialVector{
		Name: name, Height: height, Powers: joinPowers(powers), BlockRPC: blockJSON, CommitRPC: commitJSON,
		BlockProto: hex.EncodeToString(blockProto), CommitProto: hex.EncodeToString(commitProto),
		EvidenceHash: hex.EncodeToString(b.EvidenceHash), PartsHash: hex.EncodeToString(id.PartSetHeader.Hash),
		PartsTotal: id.PartSetHeader.Total,
	}
}

// fuzz draws the random parts of differential vectors from one seeded generator.
type fuzz struct{ *rand.Rand }

// time picks the Unix epoch (which tendermint-proto's JSON reads as absent), Go's zero time,
// an ordinary time or any time CometBFT can encode, with nanoseconds.
func (f fuzz) time() time.Time {
	switch f.IntN(10) {
	case 0, 1:
		return epoch
	case 2:
		return time.Time{}.UTC()
	case 3, 4, 5:
		return time.Unix(100+f.Int64N(1_000_000), 0).UTC()
	default:
		return time.Unix(f.Int64N(253_402_300_799+62_135_596_800)-62_135_596_800, f.Int64N(1_000_000_000)).UTC()
	}
}

func (f fuzz) bytes(n int) []byte {
	out := make([]byte, n)
	for i := range out {
		out[i] = byte(f.UintN(256))
	}
	return out
}

func (f fuzz) blockID() types.BlockID {
	return types.BlockID{Hash: f.bytes(32), PartSetHeader: types.PartSetHeader{Total: 1 + uint32(f.UintN(4)), Hash: f.bytes(32)}}
}

func (f fuzz) powers() []int64 {
	powers := make([]int64, 1+f.IntN(6))
	for i := range powers {
		powers[i] = 1 + f.Int64N(100)
	}
	return powers
}

// specs certifies with more than 2/3 of the power at commit flags; the rest vote nil or are
// absent. Every entry may carry any time.
func (f fuzz) specs(vals *types.ValidatorSet) []sigSpec {
	for {
		specs := make([]sigSpec, vals.Size())
		committed := int64(0)
		for i, v := range vals.Validators {
			switch f.IntN(4) {
			case 0:
				specs[i] = sigSpec{flag: types.BlockIDFlagAbsent}
			case 1:
				specs[i] = sigSpec{flag: types.BlockIDFlagNil, time: f.time()}
			default:
				specs[i] = sigSpec{flag: types.BlockIDFlagCommit, time: f.time()}
				committed += v.VotingPower
			}
		}
		if committed*3 > vals.TotalVotingPower()*2 {
			return specs
		}
	}
}

// vote signs a vote of validator `v` with random fields; a non-nil precommit may carry an
// extension and an extension signature of any length evidence allows.
func (f fuzz) vote(v *types.Validator, index int32, height int64, round int32, voteType cmtproto.SignedMsgType, id types.BlockID) *types.Vote {
	vote := &types.Vote{
		Type: voteType, Height: height, Round: round, BlockID: id, Timestamp: f.time(),
		ValidatorAddress: v.Address, ValidatorIndex: index,
	}
	signature, err := keyOf(v).Sign(types.VoteSignBytes(chainID, vote.ToProto()))
	must(err)
	vote.Signature = signature
	if voteType == cmtproto.PrecommitType && !id.IsZero() && f.IntN(2) == 0 {
		vote.ExtensionSignature = f.bytes(1 + f.IntN(100))
		if f.IntN(2) == 0 {
			vote.Extension = f.bytes(f.IntN(40))
		}
	}
	return vote
}

func (f fuzz) duplicateVote(vals *types.ValidatorSet) types.Evidence {
	index := f.IntN(vals.Size())
	v := vals.Validators[index]
	voteType := cmtproto.PrevoteType
	if f.IntN(2) == 0 {
		voteType = cmtproto.PrecommitType
	}
	height, round := 1+f.Int64N(1_000_000), int32(f.IntN(10))
	a := f.blockID()
	if f.IntN(4) == 0 {
		a = types.BlockID{}
	}
	voteA := f.vote(v, int32(index), height, round, voteType, a)
	voteB := f.vote(v, int32(index), height, round, voteType, f.blockID())
	evidence, err := types.NewDuplicateVoteEvidence(voteA, voteB, f.time(), vals)
	must(err)
	must(evidence.ValidateBasic())
	return evidence
}

func (f fuzz) lightClientAttack(vals *types.ValidatorSet) types.Evidence {
	conflictingVals := vals
	if f.IntN(3) == 0 {
		conflictingVals = validatorSet(f.powers())
	}
	height := 2 + f.Int64N(1_000_000)
	header := types.Header{
		ChainID: chainID, Height: height, Time: f.time(),
		ValidatorsHash: conflictingVals.Hash(), NextValidatorsHash: conflictingVals.Hash(),
		ConsensusHash: f.bytes(32), AppHash: f.bytes(32), ProposerAddress: conflictingVals.Validators[0].Address,
	}
	header.Version.Block = 11
	header.Version.App = 1
	id := f.blockID()
	id.Hash = header.Hash()
	byzantine := []*types.Validator{vals.Validators[f.IntN(vals.Size())]}
	evidence := &types.LightClientAttackEvidence{
		ConflictingBlock: &types.LightBlock{
			SignedHeader: &types.SignedHeader{Header: &header, Commit: signedCommit(height, int32(f.IntN(5)), id, conflictingVals, f.specs(conflictingVals))},
			ValidatorSet: conflictingVals,
		},
		CommonHeight: 1 + f.Int64N(height-1), ByzantineValidators: byzantine,
		TotalVotingPower: vals.TotalVotingPower(), Timestamp: f.time(),
	}
	must(evidence.ValidateBasic())
	return evidence
}

// differentialVectors are named Unix-epoch cases, then seeded random blocks and certificates.
func differentialVectors(envelope []byte) []differentialVector {
	two := []int64{10, 30}
	vals := validatorSet(two)
	at := func(t time.Time, flag types.BlockIDFlag) sigSpec { return sigSpec{flag: flag, time: t} }
	normal := time.Unix(101, 0).UTC()
	// key(1) (power 10 of 40) signs at the Unix epoch; the commit still certifies, and the
	// power-weighted median time is key(2)'s.
	epochCommit := []sigSpec{at(normal, types.BlockIDFlagCommit), at(epoch, types.BlockIDFlagCommit)}
	epochNil := []sigSpec{at(normal, types.BlockIDFlagCommit), at(epoch, types.BlockIDFlagNil)}
	honest := []sigSpec{at(normal, types.BlockIDFlagCommit), at(normal, types.BlockIDFlagCommit)}
	if !bytes.Equal(vals.Validators[1].PubKey.Bytes(), key(1).PubKey().Bytes()) {
		panic("key(1) must be the lighter validator")
	}
	lastID := types.BlockID{Hash: bytes.Repeat([]byte{4}, 32), PartSetHeader: types.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{5}, 32)}}
	f := fuzz{rand.New(rand.NewPCG(22280, 2026))}
	epochVote := func(id types.BlockID) *types.Vote {
		vote := &types.Vote{
			Type: cmtproto.PrecommitType, Height: 1, Round: 0, BlockID: id, Timestamp: epoch,
			ValidatorAddress: key(1).PubKey().Address(), ValidatorIndex: 1,
		}
		var err error
		vote.Signature, err = key(1).Sign(types.VoteSignBytes(chainID, vote.ToProto()))
		must(err)
		return vote
	}
	epochDve, err := types.NewDuplicateVoteEvidence(epochVote(lastID), epochVote(f.blockID()), epoch, vals)
	must(err)
	vectors := []differentialVector{
		differential("own_commit_sig_at_unix_epoch", 1, normal, two, nil, nil, epochCommit, envelope),
		differential("own_nil_sig_at_unix_epoch", 1, normal, two, nil, nil, epochNil, envelope),
		differential("last_commit_sig_at_unix_epoch", 2, normal, two, signedCommit(1, 0, lastID, vals, epochCommit), nil, honest, envelope),
		differential("last_commit_nil_sig_at_unix_epoch", 2, normal, two, signedCommit(1, 0, lastID, vals, epochNil), nil, honest, envelope),
		differential("duplicate_votes_at_unix_epoch", 1, normal, two, nil, []types.Evidence{epochDve}, honest, envelope),
		differential("header_at_unix_epoch", 1, epoch, two, nil, nil, honest, envelope),
		differential("duplicate_vote_int32_extremes", 1, normal, two, nil, []types.Evidence{extremeDuplicateVote(vals)}, honest, envelope),
		differential("commit_rounds_int32_max", 2, normal, two, signedCommit(1, math.MaxInt32, lastID, vals, honest), nil, honest, envelope, blockOption{round: math.MaxInt32}),
		differential("app_version_7", 1, normal, two, nil, nil, honest, envelope, blockOption{app: 7}),
		differential("light_client_attack_nil_signature_65", 1, normal, two, nil, []types.Evidence{oddLightClientAttack(vals, false)}, honest, envelope),
		differential("light_client_attack_lunatic_secp256k1", 1, normal, two, nil, []types.Evidence{oddLightClientAttack(vals, true)}, honest, envelope),
	}
	many := make([]int64, 120)
	for i := range many {
		many[i] = 1 + f.Int64N(100)
	}
	manyVals := validatorSet(many)
	vectors = append(vectors, differential("validators_120", 2, normal, many, signedCommit(1, 0, lastID, manyVals, f.specs(manyVals)), nil, f.specs(manyVals), envelope))
	for i := 0; i < 48; i++ {
		powers := f.powers()
		vals := validatorSet(powers)
		height := int64(1)
		if f.IntN(4) != 0 {
			height = 2 + f.Int64N(1_000_000)
		}
		var last *types.Commit
		if height > 1 {
			last = signedCommit(height-1, int32(f.IntN(5)), f.blockID(), vals, f.specs(vals))
		}
		var evidence []types.Evidence
		for range f.IntN(4) {
			if f.IntN(2) == 0 {
				evidence = append(evidence, f.duplicateVote(vals))
			} else {
				evidence = append(evidence, f.lightClientAttack(vals))
			}
		}
		vectors = append(vectors, differential(fmt.Sprintf("random_%02d", i), height, f.time(), powers, last, evidence, f.specs(vals), envelope))
	}
	return vectors
}

// extremeDuplicateVote double-signs at the largest height, round and validator index stock
// validation allows (no signature covers the index), with large extension fields.
func extremeDuplicateVote(vals *types.ValidatorSet) types.Evidence {
	v := vals.Validators[1]
	vote := func(id types.BlockID) *types.Vote {
		vote := &types.Vote{
			Type: cmtproto.PrecommitType, Height: 1 << 62, Round: math.MaxInt32, BlockID: id,
			Timestamp: time.Unix(100, 0).UTC(), ValidatorAddress: v.Address, ValidatorIndex: math.MaxInt32,
		}
		signature, err := keyOf(v).Sign(types.VoteSignBytes(chainID, vote.ToProto()))
		must(err)
		vote.Signature = signature
		vote.Extension = bytes.Repeat([]byte{7}, 5_000)
		vote.ExtensionSignature = bytes.Repeat([]byte{9}, types.MaxSignatureSize)
		return vote
	}
	evidence, err := types.NewDuplicateVoteEvidence(
		vote(types.BlockID{Hash: bytes.Repeat([]byte{3}, 32), PartSetHeader: types.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{4}, 32)}}),
		vote(types.BlockID{Hash: bytes.Repeat([]byte{5}, 32), PartSetHeader: types.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{6}, 32)}}),
		time.Unix(100, 0).UTC(), vals)
	must(err)
	must(evidence.ValidateBasic())
	return evidence
}

// oddLightClientAttack is a light-client attack whose conflicting commit carries a 65-byte nil
// signature (stock CometBFT never verifies nil signatures there) or whose lunatic validator set
// includes a secp256k1 key.
func oddLightClientAttack(vals *types.ValidatorSet, secp bool) types.Evidence {
	conflicting := vals
	if secp {
		conflicting = types.NewValidatorSet([]*types.Validator{
			types.NewValidator(secpKey.PubKey(), 50), types.NewValidator(key(3).PubKey(), 10),
		})
	}
	header := types.Header{
		ChainID: chainID, Height: 5, Time: time.Unix(105, 0).UTC(),
		ValidatorsHash: conflicting.Hash(), NextValidatorsHash: conflicting.Hash(),
		ConsensusHash: bytes.Repeat([]byte{2}, 32), AppHash: bytes.Repeat([]byte{7}, 32),
		ProposerAddress: conflicting.Validators[0].Address,
	}
	header.Version.Block = 11
	header.Version.App = 1
	id := types.BlockID{Hash: header.Hash(), PartSetHeader: types.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{8}, 32)}}
	specs := make([]sigSpec, conflicting.Size())
	for i := range specs {
		specs[i] = sigSpec{flag: types.BlockIDFlagCommit, time: time.Unix(105, 0).UTC()}
	}
	if !secp {
		// The lighter validator votes nil; its signature is never verified.
		specs[1].flag = types.BlockIDFlagNil
	}
	commit := signedCommit(5, 0, id, conflicting, specs)
	if !secp {
		commit.Signatures[1].Signature = bytes.Repeat([]byte{9}, 65)
		must(commit.ValidateBasic())
	}
	evidence := &types.LightClientAttackEvidence{
		ConflictingBlock: &types.LightBlock{
			SignedHeader: &types.SignedHeader{Header: &header, Commit: commit},
			ValidatorSet: conflicting,
		},
		CommonHeight: 1, ByzantineValidators: []*types.Validator{vals.Validators[0]},
		TotalVotingPower: vals.TotalVotingPower(), Timestamp: time.Unix(100, 0).UTC(),
	}
	must(evidence.ValidateBasic())
	return evidence
}
