package cometsigned

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	ct "github.com/cometbft/cometbft/consensus/types"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	pb "github.com/cometbft/cometbft/proto/tendermint/types"
	cmt "github.com/cometbft/cometbft/types"
)

type point struct {
	PublicKey string `json:"public_key"`
	Signer    string `json:"signer"`
}

type spectator struct {
	Name      string `json:"name"`
	PublicKey string `json:"public_key"`
	Address   string `json:"ck_addr"`
}

type fields struct {
	Type       string `json:"voteType"`
	Height     string `json:"height"`
	Round      string `json:"round"`
	BlockHash  string `json:"blockHash"`
	PartsTotal string `json:"partsTotal"`
	PartsHash  string `json:"partsHash"`
	Seconds    string `json:"timestampSeconds"`
	SecondsU64 string `json:"timestampSecondsU64"`
	Nanos      string `json:"timestampNanos"`
	Generation string `json:"generation"`
}

type row struct {
	Name      string `json:"name"`
	ChainID   string `json:"chain_id"`
	SignBytes string `json:"sign_bytes"`
	Signature string `json:"signature"`
	Vote      fields `json:"vote"`
}

type fixture struct {
	Schema     string          `json:"schema"`
	Provenance json.RawMessage `json:"provenance"`
	Deployment json.RawMessage `json:"deployment"`
	Key        point           `json:"voteKey"`
	Cases      []row           `json:"voteCases"`
	Pairs      json.RawMessage `json:"votePairs"`
	Domains    json.RawMessage `json:"chainDomains"`
	Spectators []spectator     `json:"spectators"`
}

type observation map[string]any

func check(t *testing.T, condition bool, message string, args ...any) {
	t.Helper()
	if !condition {
		t.Fatalf(message, args...)
	}
}

func receipt(t *testing.T, data observation) {
	t.Helper()
	raw, err := json.Marshal(data)
	check(t, err == nil, "marshal receipt: %v", err)
	t.Logf("receipt=%s", raw)
}

func decodeHex(t *testing.T, text string) []byte {
	t.Helper()
	value, err := hex.DecodeString(strings.TrimPrefix(text, "0x"))
	check(t, err == nil && "0x"+hex.EncodeToString(value) == text, "invalid public hex input")
	return value
}

func presentHash(t *testing.T, text string) []byte {
	t.Helper()
	value := decodeHex(t, text)
	if bytes.Equal(value, make([]byte, 32)) {
		return nil
	}
	return value
}

func hexString(value []byte) string { return "0x" + hex.EncodeToString(value) }

func integer(t *testing.T, text string, bits int) int64 {
	t.Helper()
	value, err := strconv.ParseInt(text, 10, bits)
	check(t, err == nil, "invalid signed decimal field: %v", err)
	return value
}

func nat(t *testing.T, text string, bits int) uint64 {
	t.Helper()
	value, err := strconv.ParseUint(text, 10, bits)
	check(t, err == nil, "invalid unsigned decimal field: %v", err)
	return value
}

func key(t *testing.T, point point) secp256k1eth.PubKey {
	t.Helper()
	pub, err := secp256k1eth.NewPubKeyFromBytes(decodeHex(t, point.PublicKey))
	check(t, err == nil, "native public key construction: %v", err)
	check(t, hexString(pub.Bytes()) == point.PublicKey && hexString(pub.Address()) == point.Signer,
		"native public key or address differs")
	return pub
}

func nativeVote(t *testing.T, r row, pub secp256k1eth.PubKey, index int32) *cmt.Vote {
	t.Helper()
	f := r.Vote
	seconds := integer(t, f.Seconds, 64)
	nanos := integer(t, f.Nanos, 32)
	check(t, uint64(seconds) == nat(t, f.SecondsU64, 64), "timestamp bit pattern differs")
	ts := time.Unix(seconds, nanos).UTC()
	check(t, ts.Unix() == seconds && int64(ts.Nanosecond()) == nanos, "unexpected time normalization")
	return &cmt.Vote{
		Type: pb.SignedMsgType(nat(t, f.Type, 8)), Height: integer(t, f.Height, 64),
		Round: int32(integer(t, f.Round, 32)), Timestamp: ts,
		ValidatorAddress: pub.Address(), ValidatorIndex: index, Signature: decodeHex(t, r.Signature),
		BlockID: cmt.BlockID{
			Hash:          presentHash(t, f.BlockHash),
			PartSetHeader: cmt.PartSetHeader{Total: uint32(nat(t, f.PartsTotal, 32)), Hash: presentHash(t, f.PartsHash)},
		},
	}
}

func signatureResult(err error) string {
	switch {
	case err == nil:
		return "accept"
	case errors.Is(err, cmt.ErrVoteInvalidSignature):
		return "signature"
	case errors.Is(err, cmt.ErrVoteInvalidValidatorAddress):
		return "address"
	case errors.Is(err, cmt.ErrVoteInvalidValidatorIndex):
		return "index"
	case errors.Is(err, cmt.ErrVoteUnexpectedStep):
		return "step"
	case errors.Is(err, cmt.ErrVoteNonDeterministicSignature):
		return "nondeterministic"
	default:
		var conflict *cmt.ErrVoteConflictingVotes
		if errors.As(err, &conflict) {
			return "conflict"
		}
		return err.Error()
	}
}

func wireCase(t *testing.T, r row, pub secp256k1eth.PubKey) {
	vote := nativeVote(t, r, pub, 0)
	actual := cmt.VoteSignBytes(r.ChainID, vote.ToProto())
	verify := vote.Verify(r.ChainID, pub)
	err := vote.ValidateBasic()
	basic := "accept"
	if err != nil {
		check(t, strings.HasPrefix(err.Error(), "blockID must be either empty or complete, got: "),
			"unexpected ValidateBasic branch: %v", err)
		basic = "incomplete-block-id"
	}
	receipt(t, observation{
		"address": hexString(vote.ValidatorAddress), "key": hexString(pub.Bytes()), "chain": r.ChainID,
		"height": vote.Height, "round": vote.Round, "type": vote.Type, "index": vote.ValidatorIndex,
		"signBytes": hexString(actual), "signature": hexString(vote.Signature),
		"validateBasic": basic, "verify": signatureResult(verify),
	})
	check(t, bytes.Equal(actual, decodeHex(t, r.SignBytes)), "published native sign bytes differ")
	check(t, verify == nil, "published native signature refused: %v", verify)
	want := "accept"
	if r.Name == "partial_block_id" || r.Name == "hash_only_block_id" {
		want = "incomplete-block-id"
	}
	check(t, basic == want, "ValidateBasic got %s want %s", basic, want)
}

type setup struct {
	signer     secp256k1eth.PubKey
	spectators []spectator
	rows       map[string]row
}

func (s setup) validators(t *testing.T, signerPower int64, spectatorPowers ...int64) *cmt.ValidatorSet {
	t.Helper()
	list := []*cmt.Validator{cmt.NewValidator(s.signer, signerPower)}
	for i, power := range spectatorPowers {
		sp := s.spectators[i]
		pub := key(t, point{PublicKey: sp.PublicKey, Signer: sp.Address})
		list = append(list, cmt.NewValidator(pub, power))
	}
	return cmt.NewValidatorSet(list)
}

func slotPower(vals *cmt.ValidatorSet) []observation {
	slots := make([]observation, 0, vals.Size())
	for index := 0; index < vals.Size(); index++ {
		address, validator := vals.GetByIndex(int32(index))
		slots = append(slots, observation{
			"address": hexString(address), "power": validator.VotingPower,
		})
	}
	return slots
}

func setFor(r row, vote *cmt.Vote, vals *cmt.ValidatorSet) *cmt.VoteSet {
	return cmt.NewVoteSet(r.ChainID, vote.Height, vote.Round, vote.Type, vals)
}

func voteInput(chain string, vote *cmt.Vote) observation {
	signBytes := cmt.VoteSignBytes(chain, vote.ToProto())
	digest := sha256.Sum256(signBytes)
	return observation{
		"chain": chain, "height": vote.Height, "round": vote.Round, "type": vote.Type,
		"index": vote.ValidatorIndex, "address": hexString(vote.ValidatorAddress),
		"signBytesSha256": hex.EncodeToString(digest[:]), "signature": hexString(vote.Signature),
	}
}

func observeAddVote(set *cmt.VoteSet, vote *cmt.Vote) (bool, error, observation) {
	input := voteInput(set.ChainID(), vote)
	added, err := set.AddVote(vote)
	return added, err, input
}

func voteSetStep(set *cmt.VoteSet) observation {
	return observation{"chain": set.ChainID(), "height": set.GetHeight(), "round": set.GetRound(), "type": set.Type()}
}

func blockID(id cmt.BlockID) observation {
	return observation{"hash": hexString(id.Hash), "parts": hexString(id.PartSetHeader.Hash), "total": id.PartSetHeader.Total}
}

func voteSetState(set *cmt.VoteSet, valCount int) observation {
	majority, hasMajority := set.TwoThirdsMajority()
	slots := make([]bool, valCount)
	for i := range slots {
		slots[i] = set.BitArray().GetIndex(i)
	}
	return observation{
		"count": len(set.List()), "slots": slots, "nativePower": set.LogString(),
		"majority": hasMajority, "majorityBlock": blockID(majority),
		"anyQuorum": set.HasTwoThirdsAny(),
	}
}

type commitCase struct {
	name            string
	signerPower     int64
	spectatorPowers []int64
	index           int32
	nilVote         bool
	wrongSignature  bool
	wrongSlot       bool
	want            string
	got             int64
	needed          int64
}

func (s setup) commitCase(t *testing.T, test commitCase) {
	vals := s.validators(t, test.signerPower, test.spectatorPowers...)
	signerIndex, validator := vals.GetByAddress(s.signer.Address())
	check(t, validator != nil && signerIndex == test.index && validator.VotingPower == test.signerPower,
		"unexpected native signer index or power")
	base := s.rows["precommit_a"]
	target := nativeVote(t, base, s.signer, signerIndex)
	r := base
	if test.nilVote {
		r = s.rows["precommit_nil"]
	}
	vote := nativeVote(t, r, s.signer, signerIndex)
	if test.wrongSignature {
		// Keep the genuine A signature bytes unchanged and present a nil vote body.
		vote.Signature = decodeHex(t, base.Signature)
	}
	set := setFor(r, vote, vals)
	added, addErr, voteAttempt := observeAddVote(set, vote)
	addCode := signatureResult(addErr)
	check(t, added == !test.wrongSignature && (test.wrongSignature && addCode == "signature" || !test.wrongSignature && addErr == nil),
		"unexpected VoteSet addition: %t %v", added, addErr)

	slots := make([]cmt.CommitSig, vals.Size())
	for i := range slots {
		slots[i] = cmt.NewCommitSigAbsent()
	}
	commitIndex := signerIndex
	if test.wrongSlot {
		commitIndex = 1
	}
	slots[commitIndex] = vote.CommitSig()
	commit := &cmt.Commit{Height: vote.Height, Round: vote.Round, BlockID: target.BlockID, Signatures: slots}
	check(t, commit.ValidateBasic() == nil, "invalid basic test commit shape")
	chain := base.ChainID
	check(t, bytes.Equal(commit.VoteSignBytes(chain, commitIndex), decodeHex(t, r.SignBytes)),
		"commit signature slot canonicalization differs")
	commitAttempt := voteInput(chain, commit.GetVote(commitIndex))
	err := vals.VerifyCommit(chain, target.BlockID, target.Height, commit)
	result := signatureResult(err)
	var got, needed int64
	var insufficient cmt.ErrNotEnoughVotingPowerSigned
	switch {
	case errors.As(err, &insufficient):
		result, got, needed = "insufficient-power", insufficient.Got, insufficient.Needed
	case err != nil && strings.HasPrefix(err.Error(), "wrong signature (#0): "):
		check(t, err.Error() == "wrong signature (#0): "+strings.ToUpper(hex.EncodeToString(vote.Signature)),
			"commit signature diagnostic differs")
		result = "signature"
	case err != nil && strings.HasPrefix(err.Error(), "validator address mismatch at index 1:"):
		address, _ := vals.GetByIndex(commitIndex)
		check(t, err.Error() == "validator address mismatch at index 1: expected "+
			strings.ToUpper(hex.EncodeToString(address))+", got "+
			strings.ToUpper(hex.EncodeToString(vote.ValidatorAddress)), "commit address diagnostic differs")
		result = "address"
	}

	flags := make([]int, 0, len(slots))
	for _, slot := range slots {
		flags = append(flags, int(slot.BlockIDFlag))
	}
	receipt(t, observation{
		"added": added, "addResult": addCode, "commit": result, "got": got, "needed": needed,
		"commitFlags": flags, "validators": slotPower(vals), "index": signerIndex,
		"target": blockID(commit.BlockID), "state": voteSetState(set, vals.Size()),
		"voteInput": voteAttempt, "voteSetStep": voteSetStep(set), "commitInput": commitAttempt,
		"verifyHeight": target.Height, "verifyTarget": blockID(target.BlockID),
	})
	if test.name == "commit-exact-two-thirds" && err == nil {
		t.Error("signed-commit-threshold id=commit-exact-two-thirds expected=insufficient-power got=accept wantGot=2 wantNeeded=2")
		return
	}
	if test.name == "commit-valid-nil" && err == nil {
		t.Error("signed-commit-nil id=commit-valid-nil expected=insufficient-power got=accept wantGot=0 wantNeeded=2")
		return
	}
	check(t, result == test.want && got == test.got && needed == test.needed, "commit result %s %d/%d: %v", result, got, needed, err)
}

type replayCase struct {
	name string
	row  string
	want string
}

func (s setup) replayCase(t *testing.T, test replayCase) {
	r := s.rows["precommit_a"]
	first := nativeVote(t, r, s.signer, 0)
	second := nativeVote(t, s.rows[test.row], s.signer, 0)
	vals := s.validators(t, 2, 1)
	set := setFor(r, first, vals)
	check(t, first.Verify(set.ChainID(), s.signer) == nil, "first genuine replay vote refused")
	check(t, second.Verify(set.ChainID(), s.signer) == nil, "second genuine replay vote refused")
	added, err, firstInput := observeAddVote(set, first)
	check(t, added && err == nil, "initial vote addition: %v", err)
	before := voteSetState(set, vals.Size())
	added, err, secondInput := observeAddVote(set, second)
	code := signatureResult(err)
	check(t, !added && code == test.want, "wrong replay result %t %v", added, err)
	if code == "conflict" {
		var conflict *cmt.ErrVoteConflictingVotes
		check(t, errors.As(err, &conflict) && conflict.VoteA == first && conflict.VoteB == second, "wrong conflict votes")
	}
	retained := set.GetByIndex(0)
	check(t, retained == first, "original vote slot changed")
	receipt(t, observation{
		"added": added, "result": code, "before": before, "after": voteSetState(set, vals.Size()),
		"first": blockID(first.BlockID), "second": blockID(second.BlockID),
		"trackedSecondBlock": set.BitArrayByBlockID(second.BlockID) != nil,
		"retained":           hexString(retained.Signature),
		"firstInput":         firstInput, "secondInput": secondInput, "voteSetStep": voteSetStep(set),
	})
}

func (s setup) rejectedVote(t *testing.T, name string) {
	r := s.rows["precommit_a"]
	vote := nativeVote(t, r, s.signer, 0)
	vals := s.validators(t, 3, 1)
	original := setFor(r, vote, vals)
	direct, expected := "signature", "step"
	chain := r.ChainID
	switch name {
	case "vote-wrong-generation":
		chain, expected = s.rows["gen1_precommit_a"].ChainID, "signature"
	case "vote-wrong-inbox":
		chain, expected = s.rows["other_inbox_precommit_b"].ChainID, "signature"
	case "vote-address":
		vote.ValidatorAddress, direct, expected = decodeHex(t, s.spectators[0].Address), "address", "address"
	case "vote-index-outside":
		vote.ValidatorIndex, direct, expected = int32(vals.Size()), "accept", "index"
	case "vote-index-mismatch":
		vote.ValidatorIndex, direct, expected = 1, "accept", "address"
	case "vote-height":
		vote.Height++
	case "vote-round":
		vote.Round++
	case "vote-type":
		vote.Type = pb.PrevoteType
	default:
		t.Fatalf("unknown refusal case %s", name)
	}
	if chain != r.ChainID {
		original = cmt.NewVoteSet(chain, vote.Height, vote.Round, vote.Type, vals)
	}
	check(t, vote.ValidateBasic() == nil, "refusal shape ValidateBasic rejected")
	directCode := signatureResult(vote.Verify(original.ChainID(), s.signer))
	added, err, input := observeAddVote(original, vote)
	addCode := signatureResult(err)
	check(t, !added && direct == directCode && expected == addCode,
		"native refusal id=%s direct=%s add=%t/%v", name, directCode, added, err)
	var matchedCode string
	var matchedStep, matchedInput observation
	if expected == "step" {
		matched := setFor(r, vote, vals)
		matchedAdded, matchedErr, attempt := observeAddVote(matched, vote)
		matchedCode = signatureResult(matchedErr)
		matchedStep, matchedInput = voteSetStep(matched), attempt
		check(t, !matchedAdded && matchedCode == "signature" && len(matched.List()) == 0,
			"signed metadata mismatch did not reach native signature refusal: %v", matchedErr)
	}
	receipt(t, observation{
		"added": added, "voteSet": addCode, "verify": directCode, "matchingStepVoteSet": matchedCode,
		"state": voteSetState(original, vals.Size()), "input": input,
		"voteSetStep": voteSetStep(original), "matchingStep": matchedStep, "matchingStepInput": matchedInput,
	})
}

func pol(set *ct.HeightVoteSet) observation {
	round, id := set.POLInfo()
	return observation{"round": round, "block": blockID(id)}
}

func observeAddPOLVote(set *ct.HeightVoteSet, vote *cmt.Vote) (bool, error, observation) {
	// The round buckets share the height set's chain ID. Even a type that
	// cannot reach a bucket has a well-defined submitted canonical encoding.
	round := set.Round()
	input := observation{
		"vote":   voteInput(set.Prevotes(round).ChainID(), vote),
		"height": set.Height(), "round": round,
	}
	added, err := set.AddVote(vote, "", false)
	return added, err, input
}

func (s setup) polCase(t *testing.T, power int64) {
	vals := s.validators(t, power, 1)
	r1, r2 := s.rows["prevote_a_r1"], s.rows["prevote_b_r2"]
	a := nativeVote(t, r1, s.signer, 0)
	b := nativeVote(t, r2, s.signer, 0)
	hvs := ct.NewHeightVoteSet(r1.ChainID, a.Height, vals)
	hvs.SetRound(1)
	added, err, round1Input := observeAddPOLVote(hvs, a)
	check(t, added && err == nil, "round 1 prevote admission: %v", err)
	before := pol(hvs)
	first := voteSetState(hvs.Prevotes(1), vals.Size())
	hvs.SetRound(2)
	added, err, round2Input := observeAddPOLVote(hvs, b)
	check(t, added && err == nil, "round 2 prevote admission: %v", err)
	check(t, hvs.Prevotes(1).GetByIndex(0) == a && hvs.Prevotes(2).GetByIndex(0) == b, "genuine prevotes not retained")
	receipt(t, observation{
		"afterRound1": before, "afterRound2": pol(hvs), "round1Before": first,
		"round1After": voteSetState(hvs.Prevotes(1), vals.Size()), "round2": voteSetState(hvs.Prevotes(2), vals.Size()),
		"round1Input": round1Input, "round2Input": round2Input,
	})
}

func (s setup) polControls(t *testing.T) {
	vals := s.validators(t, 3, 1)
	r := s.rows["prevote_a_r1"]
	vote := nativeVote(t, r, s.signer, 0)
	hvs := ct.NewHeightVoteSet(r.ChainID, vote.Height, vals)
	hvs.SetRound(1)

	wrongHeight := *vote
	wrongHeight.Height++
	heightAdded, heightErr, heightInput := observeAddPOLVote(hvs, &wrongHeight)
	invalidType := *vote
	invalidType.Type = pb.UnknownType
	typeAdded, typeErr, typeInput := observeAddPOLVote(hvs, &invalidType)
	wrongRoundSignature := nativeVote(t, s.rows["prevote_b_r2"], s.signer, 0)
	wrongRoundSignature.Round = 1
	rebound, reboundErr, reboundInput := observeAddPOLVote(hvs, wrongRoundSignature)
	precommit := nativeVote(t, s.rows["precommit_b_r1"], s.signer, 0)
	precommitAdded, precommitErr, precommitInput := observeAddPOLVote(hvs, precommit)
	receipt(t, observation{
		"heightAdded": heightAdded, "heightResult": signatureResult(heightErr),
		"invalidTypeAdded": typeAdded, "invalidTypeResult": signatureResult(typeErr),
		"reboundRoundAdded": rebound, "reboundRoundResult": signatureResult(reboundErr),
		"precommitAdded": precommitAdded, "precommitResult": signatureResult(precommitErr),
		"pol": pol(hvs), "prevotes": voteSetState(hvs.Prevotes(1), vals.Size()),
		"precommits":  voteSetState(hvs.Precommits(1), vals.Size()),
		"heightInput": heightInput, "invalidTypeInput": typeInput,
		"reboundRoundInput": reboundInput, "precommitInput": precommitInput,
	})
}

func TestCometSigned(t *testing.T) {
	raw, err := os.ReadFile("public-votes.json")
	check(t, err == nil, "load public votes: %v", err)
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	var fixture fixture
	err = decoder.Decode(&fixture)
	check(t, err == nil, "decode public fixture: %v", err)
	check(t, decoder.Decode(new(any)) == io.EOF, "additional JSON after public fixture")
	check(t, fixture.Schema == "etna-public-votes-1" && len(fixture.Cases) == 23 && len(fixture.Spectators) == 3,
		"unexpected public fixture schema or count")
	s := setup{key(t, fixture.Key), fixture.Spectators, make(map[string]row, len(fixture.Cases))}
	for _, value := range fixture.Cases {
		r := value
		s.rows[r.Name] = r
		t.Run(r.Name, func(t *testing.T) { wireCase(t, r, s.signer) })
	}
	for _, test := range []commitCase{
		{name: "commit-exact-two-thirds", signerPower: 2, spectatorPowers: []int64{1}, want: "insufficient-power", got: 2, needed: 2},
		{name: "commit-above", signerPower: 3, spectatorPowers: []int64{1}, want: "accept"},
		{name: "commit-below", signerPower: 2, spectatorPowers: []int64{1, 1, 1}, want: "insufficient-power", got: 2, needed: 3},
		{name: "commit-nonzero-index", signerPower: 1, spectatorPowers: []int64{2}, index: 1, want: "insufficient-power", got: 1, needed: 2},
		{name: "commit-valid-nil", signerPower: 3, spectatorPowers: []int64{1}, nilVote: true, want: "insufficient-power", needed: 2},
		{name: "commit-invalid-nil", signerPower: 3, spectatorPowers: []int64{1}, nilVote: true, wrongSignature: true, want: "signature"},
		{name: "commit-wrong-slot", signerPower: 3, spectatorPowers: []int64{1}, wrongSlot: true, want: "address"},
	} {
		t.Run(test.name, func(t *testing.T) { s.commitCase(t, test) })
	}
	for _, test := range []replayCase{
		{"duplicate", "precommit_a", "accept"},
		{"conflict-same-block-later", "precommit_a_late", "nondeterministic"},
		{"conflict-a-b", "precommit_b", "conflict"},
		{"conflict-a-nil", "precommit_nil", "conflict"},
	} {
		t.Run(test.name, func(t *testing.T) { s.replayCase(t, test) })
	}
	for _, name := range []string{"vote-wrong-generation", "vote-wrong-inbox", "vote-address", "vote-index-outside",
		"vote-index-mismatch", "vote-height", "vote-round", "vote-type"} {
		t.Run(name, func(t *testing.T) { s.rejectedVote(t, name) })
	}
	t.Run("pol-above", func(t *testing.T) { s.polCase(t, 3) })
	t.Run("pol-exact", func(t *testing.T) { s.polCase(t, 2) })
	t.Run("pol-controls", s.polControls)
}
