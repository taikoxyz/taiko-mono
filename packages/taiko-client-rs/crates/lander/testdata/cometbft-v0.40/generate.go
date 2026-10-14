// Regenerates consensus byte/hash vectors using stock CometBFT v0.40.0.
// Invoke generate.sh; the fixture envelope is a deterministic Rust Etna v4 transaction.
package main

import (
	"bytes"
	stded25519 "crypto/ed25519"
	"crypto/sha512"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"os"
	"time"

	"github.com/cometbft/cometbft/crypto/ed25519"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	cmtproto "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/types"
	"github.com/oasisprotocol/curve25519-voi/curve"
	"github.com/oasisprotocol/curve25519-voi/curve/scalar"
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

func key(seed byte) ed25519.PrivKey {
	// Match ed25519-dalek::SigningKey::from_bytes([seed; 32]).
	return ed25519.PrivKey(stded25519.NewKeyFromSeed(bytes.Repeat([]byte{seed}, 32)))
}

func signVote(k ed25519.PrivKey, id types.BlockID) *types.Vote {
	v := &types.Vote{
		Type: cmtproto.PrecommitType, Height: 1, Round: 0, BlockID: id,
		Timestamp: time.Unix(100, 0).UTC(), ValidatorAddress: k.PubKey().Address(),
		ValidatorIndex: 1,
	}
	var err error
	v.Signature, err = k.Sign(types.VoteSignBytes("taiko-etna-167001-g0", v.ToProto()))
	must(err)
	return v
}

// Torsion in the nonce is accepted under ZIP215 for an ordinary prime-order public key.
func torsionSignature(k ed25519.PrivKey, message []byte) []byte {
	secret := sha512.Sum512(k[:32])
	secret[0] &= 248
	secret[31] &= 63
	secret[31] |= 64
	a, err := new(scalar.Scalar).SetBytesModOrder(secret[:32])
	must(err)
	nonce := new(scalar.Scalar).SetUint64(7)
	r := new(curve.EdwardsPoint).MulBasepoint(curve.ED25519_BASEPOINT_TABLE, nonce)
	r.Add(r, curve.EIGHT_TORSION[1])
	if r.IsTorsionFree() || r.IsSmallOrder() {
		panic("fixture nonce must have nontrivial torsion without small order")
	}
	rBytes, err := r.MarshalBinary()
	must(err)
	hash := sha512.New()
	hash.Write(rBytes)
	hash.Write(k.PubKey().Bytes())
	hash.Write(message)
	challenge, err := new(scalar.Scalar).SetBytesModOrderWide(hash.Sum(nil))
	must(err)
	s := new(scalar.Scalar).Mul(challenge, a)
	s.Add(s, nonce)
	sBytes, err := s.MarshalBinary()
	must(err)
	signature := append(rBytes, sBytes...)
	if !k.PubKey().VerifySignature(message, signature) {
		panic("stock CometBFT rejected the ZIP215 fixture")
	}
	return signature
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
		if bytes.Equal(k.PubKey().Bytes(), key(1).PubKey().Bytes()) {
			signature = torsionSignature(k, message)
		}
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
			ChainID: "taiko-etna-167001-g0", Height: 1, Time: time.Unix(101, 0).UTC(),
			ValidatorsHash: vals.Hash(), NextValidatorsHash: vals.Hash(),
			ConsensusHash: bytes.Repeat([]byte{2}, 32), AppHash: make([]byte, 32),
			ProposerAddress: vals.Validators[0].Address,
		},
		Data:       types.Data{Txs: types.Txs{types.Tx(envelope)}},
		Evidence:   types.EvidenceData{Evidence: types.EvidenceList{evidence}},
		LastCommit: &types.Commit{},
	}
	b.Header.Version.Block = 11
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
		ChainID: "taiko-etna-167001-g0", Height: 2, Time: time.Unix(102, 0).UTC(),
		ValidatorsHash: vals.Hash(), NextValidatorsHash: vals.Hash(),
		ConsensusHash: bytes.Repeat([]byte{2}, 32), AppHash: bytes.Repeat([]byte{7}, 32),
		ProposerAddress: vals.Validators[0].Address,
	}
	conflicting.Version.Block = 11
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
	}{"github.com/cometbft/cometbft v0.40.0; generate.sh", result}, "", "  ")
	must(err)
	must(os.WriteFile(os.Args[2], append(output, '\n'), 0644))
}
