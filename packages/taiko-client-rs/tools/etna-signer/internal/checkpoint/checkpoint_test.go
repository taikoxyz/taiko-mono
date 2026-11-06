package checkpoint

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"errors"
	"github.com/cometbft/cometbft/evidence"
	bs "github.com/cometbft/cometbft/store"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	pb "github.com/cometbft/cometbft/proto/tendermint/types"
	cmtversion "github.com/cometbft/cometbft/proto/tendermint/version"
	sm "github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/types"
	"github.com/cometbft/cometbft/version"
)

func fixture(t *testing.T) (*Package, Trust, *types.ValidatorSet) {
	t.Helper()
	key := secp256k1eth.PrivKey(bytes.Repeat([]byte{7}, 32))
	vals := types.NewValidatorSet([]*types.Validator{types.NewValidator(key.PubKey(), 10)})
	params := types.DefaultConsensusParams()
	params.Block.MaxBytes = 22020096
	params.Validator.PubKeyTypes = []string{"secp256k1eth"}
	params.Version.App = 1
	g := types.GenesisDoc{GenesisTime: time.Unix(100, 0).UTC(), ChainID: "etna-test", InitialHeight: 71, ConsensusParams: params, Validators: []types.GenesisValidator{{PubKey: key.PubKey(), Power: 10}}, AppHash: bytes.Repeat([]byte{1}, 32)}
	genesis, err := cmtjson.Marshal(g)
	if err != nil {
		t.Fatal(err)
	}
	txs := types.Txs{types.Tx("authenticated-envelope-by-rust")}
	b := &types.Block{Header: types.Header{Version: cmtversion.Consensus{Block: version.BlockProtocol, App: 1}, ChainID: g.ChainID, Height: 100001, Time: time.Unix(200, 0).UTC(), LastBlockID: types.BlockID{Hash: bytes.Repeat([]byte{2}, 32), PartSetHeader: types.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{3}, 32)}}, ValidatorsHash: vals.Hash(), NextValidatorsHash: vals.Hash(), ConsensusHash: params.Hash(), AppHash: bytes.Repeat([]byte{1}, 32), LastResultsHash: types.NewResults([]*abci.ExecTxResult{{}}).Hash(), ProposerAddress: vals.GetProposer().Address}, Data: types.Data{Txs: txs}, LastCommit: &types.Commit{Height: 100000, Round: 0, BlockID: types.BlockID{Hash: bytes.Repeat([]byte{2}, 32), PartSetHeader: types.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{3}, 32)}}, Signatures: []types.CommitSig{{BlockIDFlag: types.BlockIDFlagAbsent}}}}
	b.Header.LastCommitHash = b.LastCommit.Hash()
	b.Header.DataHash = b.Data.Hash()
	b.Header.EvidenceHash = b.Evidence.Hash()
	parts, err := b.MakePartSet(types.BlockPartSizeBytes)
	if err != nil {
		t.Fatal(err)
	}
	id := types.BlockID{Hash: b.Hash(), PartSetHeader: parts.Header()}
	vote := &types.Vote{Type: pb.PrecommitType, Height: b.Height, Round: 2, BlockID: id, Timestamp: b.Time, ValidatorAddress: vals.Validators[0].Address, ValidatorIndex: 0}
	vote.Signature, err = key.Sign(types.VoteSignBytes(g.ChainID, vote.ToProto()))
	if err != nil {
		t.Fatal(err)
	}
	commit := &types.Commit{Height: b.Height, Round: 2, BlockID: id, Signatures: []types.CommitSig{vote.CommitSig()}}
	pb, err := b.ToProto()
	if err != nil {
		t.Fatal(err)
	}
	bb, _ := pb.Marshal()
	cb, _ := commit.ToProto().Marshal()
	preimage := makePreimage(b.Height, vals, vals, 0, 0)
	p := &Package{Schema: 1, Genesis: json.RawMessage(genesis), Blocks: []Block{{Block: hexBytes(bb), Commit: hexBytes(cb), Validators: []Validator{{Key: hexBytes(key.PubKey().Bytes()), Power: 10}}}}, ValidatorState: hexBytes(preimage)}
	return p, Trust{CometHash: hexBytes(b.Hash()), ELHash: hexBytes(bytes.Repeat([]byte{9}, 32)), ValStateHash: hexBytes(keccak(preimage))}, vals
}
func makePreimage(h int64, a, b *types.ValidatorSet, pa, pb uint64) []byte {
	word := func(x uint64) []byte { v := make([]byte, 32); binary.BigEndian.PutUint64(v[24:], x); return v }
	out := make([]byte, 32)
	copy(out, []byte("ETNA_VAL_STATE_V1"))
	out = append(out, word(uint64(h))...)
	out = append(out, word(192)...)
	out = append(out, word(pa)...)
	out = append(out, word(uint64(192+32+128*len(a.Validators)))...)
	out = append(out, word(pb)...)
	for _, set := range []*types.ValidatorSet{a, b} {
		out = append(out, word(uint64(len(set.Validators)))...)
		for _, v := range set.Validators {
			key := v.PubKey.Bytes()
			out = append(out, word(uint64(key[0]))...)
			out = append(out, key[1:]...)
			out = append(out, word(uint64(v.VotingPower))...)
			p := word(uint64(v.ProposerPriority))
			if v.ProposerPriority < 0 {
				for i := 0; i < 24; i++ {
					p[i] = 255
				}
			}
			out = append(out, p...)
		}
	}
	return out
}
func TestNativeCommitAndOriginalIdentity(t *testing.T) {
	p, trust, _ := fixture(t)
	verified, err := Verify(p, trust)
	if err != nil {
		t.Fatal(err)
	}
	home := filepath.Join(realTemp(t), "comet")
	if err = Install(home, verified); err != nil {
		t.Fatal(err)
	}
	db, err := dbm.NewGoLevelDB("state", filepath.Join(home, "data"))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	state, err := sm.NewStore(db, sm.StoreOptions{}).Load()
	if err != nil {
		t.Fatal(err)
	}
	if state.InitialHeight != 71 || state.LastBlockHeight != 100001 || !bytes.Equal(state.AppHash, bytes.Repeat([]byte{9}, 32)) {
		t.Fatalf("wrong installed identity/state: %+v", state)
	}
	if !bytes.Equal(state.LastResultsHash, types.NewResults([]*abci.ExecTxResult{{}}).Hash()) {
		t.Fatal("invented results hash")
	}
}
func TestWrongTerminalTrustedHash(t *testing.T) {
	p, trust, _ := fixture(t)
	trust.CometHash = hexBytes(make([]byte, 32))
	if _, err := Verify(p, trust); err == nil {
		t.Fatal("accepted wrong trusted hash")
	}
}
func TestStoredProposerAtSwitch(t *testing.T) {
	p, trust, vals := fixture(t)
	key := secp256k1eth.PrivKey(bytes.Repeat([]byte{8}, 32))
	next := types.NewValidatorSet([]*types.Validator{types.NewValidator(vals.Validators[0].PubKey, 10), types.NewValidator(key.PubKey(), 20)})
	next.Validators[0].ProposerPriority = -200
	next.Validators[1].ProposerPriority = 200
	next.Proposer = next.Validators[0]
	preimage := makePreimage(100001, vals, next, 0, 0)
	p.ValidatorState = hexBytes(preimage)
	trust.ValStateHash = hexBytes(keccak(preimage))
	v, err := Verify(p, trust)
	if err != nil {
		t.Fatal(err)
	}
	home := filepath.Join(realTemp(t), "comet")
	if err = Install(home, v); err != nil {
		t.Fatal(err)
	}
	db, err := dbm.NewGoLevelDB("state", filepath.Join(home, "data"))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	s, err := sm.NewStore(db, sm.StoreOptions{}).Load()
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(s.NextValidators.Proposer.Address, next.Validators[0].Address) || s.NextValidators.Validators[0].ProposerPriority != -200 {
		t.Fatal("stored proposer or priorities were guessed")
	}
	// Stock's following-round proposer depends on the exact stored priorities, including
	// normalization of a wide spread. Compare the reopened set with the independent source.
	for round := 1; round <= 4; round++ {
		next.IncrementProposerPriority(1)
		s.NextValidators.IncrementProposerPriority(1)
		if !bytes.Equal(next.GetProposer().Address, s.NextValidators.GetProposer().Address) {
			t.Fatalf("H+2 round %d proposer", round)
		}
		for i, validator := range next.Validators {
			if validator.ProposerPriority != s.NextValidators.Validators[i].ProposerPriority {
				t.Fatalf("H+2 round %d priority %d", round, i)
			}
		}
	}
}

func realTemp(t *testing.T) string {
	t.Helper()
	p, e := filepath.EvalSymlinks(t.TempDir())
	if e != nil {
		t.Fatal(e)
	}
	return p
}

func TestStrictInputAndPreimage(t *testing.T) {
	p, trust, _ := fixture(t)
	raw, _ := json.Marshal(p)
	for _, input := range []string{string(raw) + "{}", strings.Replace(string(raw), `"schema":1`, `"schema":1,"publisher_authority":true`, 1), `{"schema":1.0}`, string(raw[:len(raw)-1])} {
		if _, e := Read(strings.NewReader(input)); e == nil {
			t.Fatal("accepted malformed/trailing input")
		}
	}
	if _, e := ReadBounded(bytes.NewReader(raw), int64(len(raw)-1)); e == nil {
		t.Fatal("accepted oversized input")
	}
	preimage, _ := decodeHex(p.ValidatorState, 1<<20)
	for _, at := range []int{0, 32, 64, 96, 128, 160, 192, 224, 288, 320} {
		bad := bytes.Clone(preimage)
		bad[at] ^= 1
		p.ValidatorState = hexBytes(bad)
		trust.ValStateHash = hexBytes(keccak(bad))
		if _, e := Verify(p, trust); e == nil {
			t.Fatalf("accepted malformed preimage at %d", at)
		}
	}
}
func TestExportRoundTripAndFreshHome(t *testing.T) {
	p, trust, _ := fixture(t)
	v, e := Verify(p, trust)
	if e != nil {
		t.Fatal(e)
	}
	home := filepath.Join(realTemp(t), "comet")
	if e = Install(home, v); e != nil {
		t.Fatal(e)
	}
	if e = Install(home, v); e == nil {
		t.Fatal("overwrote existing home")
	}
	preimage, _ := decodeHex(p.ValidatorState, 1<<20)
	out, e := Export(home, 100001, 100001, preimage)
	if e != nil {
		t.Fatal(e)
	}
	again, e := Verify(out, trust)
	if e != nil {
		t.Fatal(e)
	}
	if again.Report() != v.Report() {
		t.Fatalf("changed package on round trip: %+v != %+v", again.Report(), v.Report())
	}
}
func TestEvidenceAgeBoundaries(t *testing.T) {
	now := time.Unix(1000000, 0).UTC()
	for _, tc := range []struct {
		blocks  int64
		age     time.Duration
		expired bool
	}{{100000, 48*time.Hour + time.Nanosecond, false}, {100001, 48 * time.Hour, false}, {100001, 48*time.Hour + time.Nanosecond, true}, {1, 100 * time.Hour, false}, {200000, time.Second, false}} {
		if got := EvidenceExpired(300000, now, 300000-tc.blocks, now.Add(-tc.age)); got != tc.expired {
			t.Fatalf("wrong expiry at %+v", tc)
		}
	}
}
func TestAuthenticatedContradictionClass(t *testing.T) {
	p, trust, vals := fixture(t)
	next := vals.Copy()
	next.Validators[0].VotingPower = 11
	pre := makePreimage(100001, next, next, 0, 0)
	p.ValidatorState = hexBytes(pre)
	trust.ValStateHash = hexBytes(keccak(pre))
	_, e := Verify(p, trust)
	var contradiction *ContradictionError
	if !errors.As(e, &contradiction) {
		t.Fatalf("missing typed contradiction: %v", e)
	}
	r := contradiction.Receipt()
	encoded, _ := json.Marshal(p)
	if r.Schema != 1 || r.Kind != "authenticated_contradiction" || r.Reason != "validator_state_next_hash_mismatch" || r.Height != 100001 || r.CometHash != trust.CometHash || r.ELHash != trust.ELHash || r.ValStateHash != trust.ValStateHash || r.PackageHash != hexBytes(keccak(encoded)) {
		t.Fatalf("contradiction receipt lost authenticated identity: %+v", r)
	}
}

func duplicateEvidence(t *testing.T, h int64, at time.Time, vals *types.ValidatorSet) *types.DuplicateVoteEvidence {
	t.Helper()
	key := secp256k1eth.PrivKey(bytes.Repeat([]byte{7}, 32))
	index, _ := vals.GetByAddress(key.PubKey().Address())
	votes := make([]*types.Vote, 2)
	for i := range votes {
		v := &types.Vote{Type: pb.PrecommitType, Height: h, Round: 0, Timestamp: at, ValidatorIndex: index, ValidatorAddress: key.PubKey().Address(), BlockID: types.BlockID{Hash: bytes.Repeat([]byte{byte(4 + i)}, 32), PartSetHeader: types.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{6}, 32)}}}
		var e error
		v.Signature, e = key.Sign(types.VoteSignBytes("etna-test", v.ToProto()))
		if e != nil {
			t.Fatal(e)
		}
		votes[i] = v
	}
	ev, e := types.NewDuplicateVoteEvidence(votes[0], votes[1], at, vals)
	if e != nil {
		t.Fatal(e)
	}
	return ev
}
func addEvidence(t *testing.T, p *Package, trust *Trust, ev types.Evidence) {
	t.Helper()
	raw, _ := decodeHex(p.Blocks[0].Block, 32<<20)
	var bp pb.Block
	if e := bp.Unmarshal(raw); e != nil {
		t.Fatal(e)
	}
	b, e := types.BlockFromProto(&bp)
	if e != nil {
		t.Fatal(e)
	}
	b.Evidence = types.EvidenceData{Evidence: types.EvidenceList{ev}}
	b.EvidenceHash = b.Evidence.Hash()
	parts, e := b.MakePartSet(types.BlockPartSizeBytes)
	if e != nil {
		t.Fatal(e)
	}
	id := types.BlockID{Hash: b.Hash(), PartSetHeader: parts.Header()}
	key := secp256k1eth.PrivKey(bytes.Repeat([]byte{7}, 32))
	vote := &types.Vote{Type: pb.PrecommitType, Height: b.Height, Round: 0, Timestamp: b.Time, BlockID: id, ValidatorAddress: key.PubKey().Address(), ValidatorIndex: 0}
	vote.Signature, e = key.Sign(types.VoteSignBytes(b.ChainID, vote.ToProto()))
	if e != nil {
		t.Fatal(e)
	}
	c := &types.Commit{Height: b.Height, Round: 0, BlockID: id, Signatures: []types.CommitSig{vote.CommitSig()}}
	bp2, e := b.ToProto()
	if e != nil {
		t.Fatal(e)
	}
	bb, _ := bp2.Marshal()
	cb, _ := c.ToProto().Marshal()
	p.Blocks[0].Block = hexBytes(bb)
	p.Blocks[0].Commit = hexBytes(cb)
	trust.CometHash = hexBytes(b.Hash())
}
func TestEvidenceBelowWindowCommittedMarkerAndNewEvidence(t *testing.T) {
	p, trust, vals := fixture(t)
	below := duplicateEvidence(t, 99990, time.Unix(150, 0).UTC(), vals)
	addEvidence(t, p, &trust, below)
	v, e := Verify(p, trust)
	if e != nil {
		t.Fatal(e)
	}
	home := filepath.Join(realTemp(t), "comet")
	if e = Install(home, v); e != nil {
		t.Fatal(e)
	}
	sd, e := dbm.NewGoLevelDB("state", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	defer sd.Close()
	bd, e := dbm.NewGoLevelDB("blockstore", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	defer bd.Close()
	ed, e := dbm.NewGoLevelDB("evidence", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	defer ed.Close()
	store := sm.NewStore(sd, sm.StoreOptions{})
	blocks := bs.NewBlockStore(bd)
	pool, e := evidence.NewPool(ed, store, blocks)
	if e != nil {
		t.Fatal(e)
	}
	if blocks.LoadBlockMeta(99990) != nil {
		t.Fatal("invented below-window block")
	}
	if e = pool.CheckEvidence(types.EvidenceList{below}); e == nil || !strings.Contains(e.Error(), "already committed") {
		t.Fatalf("missing committed duplicate marker: %v", e)
	}
	fresh := duplicateEvidence(t, 100001, time.Unix(200, 0).UTC(), vals)
	if e = pool.CheckEvidence(types.EvidenceList{fresh}); e != nil {
		t.Fatalf("stock rejected new evidence after import: %v", e)
	}
	if e = pool.CheckEvidence(types.EvidenceList{fresh, fresh}); e == nil {
		t.Fatal("stock accepted duplicate evidence")
	}
}

func TestStreamingPackageAndExportMatchMemoryVerification(t *testing.T) {
	p, trust, _ := fixture(t)
	raw, e := json.Marshal(p)
	if e != nil {
		t.Fatal(e)
	}
	want, e := Verify(p, trust)
	if e != nil {
		t.Fatal(e)
	}
	got, e := VerifyStream(bytes.NewReader(raw), trust, realTemp(t), int64(len(raw)))
	if e != nil {
		t.Fatal(e)
	}
	defer got.Close()
	if got.Report() != want.Report() {
		t.Fatalf("stream report differs: %+v", got.Report())
	}
	home := filepath.Join(realTemp(t), "comet")
	if e = Install(home, got); e != nil {
		t.Fatal(e)
	}
	pre, _ := decodeHex(p.ValidatorState, 1<<20)
	var out bytes.Buffer
	if e = ExportTo(&out, home, 100001, 100001, pre); e != nil {
		t.Fatal(e)
	}
	round, e := VerifyStream(&out, trust, realTemp(t), 1<<20)
	if e != nil {
		t.Fatal(e)
	}
	defer round.Close()
	if round.Report() != want.Report() {
		t.Fatal("stream export changed original package")
	}
}
func TestStreamingRejectsDuplicatesOversizeAndTrailing(t *testing.T) {
	p, trust, _ := fixture(t)
	raw, _ := json.Marshal(p)
	for _, input := range []string{string(raw) + "{}", strings.Replace(string(raw), `"schema":1`, `"schema":1,"schema":1`, 1), strings.Replace(string(raw), `"power":10`, `"power":10,"power":10`, 1), strings.Replace(string(raw), `"blocks":[`, `"blocks":[,`, 1), string(raw[:len(raw)-1])} {
		if v, e := VerifyStream(strings.NewReader(input), trust, realTemp(t), 1<<20); e == nil {
			v.Close()
			t.Fatal("accepted malformed streaming package")
		}
	}
	if v, e := VerifyStream(bytes.NewReader(raw), trust, realTemp(t), int64(len(raw)-1)); e == nil {
		v.Close()
		t.Fatal("accepted oversized stream")
	}
}

func TestTerminalCommitUsesStockKeysWithoutSuccessorBlock(t *testing.T) {
	p, trust, _ := fixture(t)
	v, e := Verify(p, trust)
	if e != nil {
		t.Fatal(e)
	}
	home := filepath.Join(realTemp(t), "comet")
	if e = Install(home, v); e != nil {
		t.Fatal(e)
	}
	db, e := dbm.NewGoLevelDB("blockstore", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	blocks := bs.NewBlockStore(db)
	// A stock node at state s has SC:s but no C:s, so stock evidence's
	// signed-header lookup at height s must fail here too.
	if blocks.LoadBlockCommit(100001) != nil {
		t.Fatal("installed C:s that a stock node at state s does not have")
	}
	seen := blocks.LoadSeenCommit(100001)
	if seen == nil || hexBytes(seen.BlockID.Hash) != trust.CometHash {
		t.Fatal("terminal seen commit missing")
	}
	if blocks.LoadBlock(100002) != nil {
		t.Fatal("invented successor block")
	}
	raw, e := seen.ToProto().Marshal()
	if e != nil {
		t.Fatal(e)
	}
	if e = db.SetSync([]byte("C:100001"), raw); e != nil {
		t.Fatal(e)
	}
	if e = db.Close(); e != nil {
		t.Fatal(e)
	}
	if e = verifyReopened(filepath.Join(home, "data"), v); e == nil {
		t.Fatal("reopen accepted a terminal C:s that stock does not write")
	}
}

func windowFixture(t *testing.T) (*Package, Trust, []*types.ValidatorSet) {
	t.Helper()
	p, trust, old := fixture(t)
	key1 := secp256k1eth.PrivKey(bytes.Repeat([]byte{7}, 32))
	key2 := secp256k1eth.PrivKey(bytes.Repeat([]byte{8}, 32))
	changed := types.NewValidatorSet([]*types.Validator{types.NewValidator(key1.PubKey(), 10), types.NewValidator(key2.PubKey(), 20)})
	sets := []*types.ValidatorSet{old, old, old, changed, old}
	template, _ := decodeHex(p.Blocks[0].Block, 32<<20)
	var bp pb.Block
	if e := bp.Unmarshal(template); e != nil {
		t.Fatal(e)
	}
	base, e := types.BlockFromProto(&bp)
	if e != nil {
		t.Fatal(e)
	}
	var previous *types.Commit
	p.Blocks = nil
	for i, set := range sets {
		b := *base
		b.Header = base.Header
		b.Height = 99999 + int64(i)
		b.Time = time.Unix(200+int64(i), 0).UTC()
		b.ValidatorsHash = set.Hash()
		next := set
		if i+1 < len(sets) {
			next = sets[i+1]
		}
		b.NextValidatorsHash = next.Hash()
		b.ProposerAddress = set.Proposer.Address
		if previous != nil {
			b.LastCommit = previous
			b.LastBlockID = previous.BlockID
		}
		b.LastCommitHash = b.LastCommit.Hash()
		parts, e := b.MakePartSet(types.BlockPartSizeBytes)
		if e != nil {
			t.Fatal(e)
		}
		id := types.BlockID{Hash: b.Hash(), PartSetHeader: parts.Header()}
		c := &types.Commit{Height: b.Height, Round: 0, BlockID: id}
		item := Block{}
		for index, val := range set.Validators {
			key := key1
			if bytes.Equal(val.PubKey.Bytes(), key2.PubKey().Bytes()) {
				key = key2
			}
			vote := &types.Vote{Type: pb.PrecommitType, Height: b.Height, Round: 0, BlockID: id, Timestamp: b.Time, ValidatorAddress: val.Address, ValidatorIndex: int32(index)}
			vote.Signature, e = key.Sign(types.VoteSignBytes(b.ChainID, vote.ToProto()))
			if e != nil {
				t.Fatal(e)
			}
			c.Signatures = append(c.Signatures, vote.CommitSig())
			item.Validators = append(item.Validators, Validator{Key: hexBytes(val.PubKey.Bytes()), Power: val.VotingPower})
		}
		bp, e := b.ToProto()
		if e != nil {
			t.Fatal(e)
		}
		bb, _ := bp.Marshal()
		cb, _ := c.ToProto().Marshal()
		item.Block = hexBytes(bb)
		item.Commit = hexBytes(cb)
		p.Blocks = append(p.Blocks, item)
		previous = c
		trust.CometHash = hexBytes(b.Hash())
	}
	pre := makePreimage(99999+int64(len(sets))-1, old, old, 0, 0)
	p.ValidatorState = hexBytes(pre)
	trust.ValStateHash = hexBytes(keccak(pre))
	return p, trust, sets
}
func TestHistoricalValidatorLookupsAtChangesAndPeriodicCheckpoints(t *testing.T) {
	p, trust, sets := windowFixture(t)
	raw, _ := json.Marshal(p)
	v, e := VerifyStream(bytes.NewReader(raw), trust, realTemp(t), 1<<20)
	if e != nil {
		t.Fatal(e)
	}
	defer v.Close()
	home := filepath.Join(realTemp(t), "comet")
	if e = Install(home, v); e != nil {
		t.Fatal(e)
	}
	sd, e := dbm.NewGoLevelDB("state", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	defer sd.Close()
	store := sm.NewStore(sd, sm.StoreOptions{})
	bd, e := dbm.NewGoLevelDB("blockstore", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	defer bd.Close()
	ed, e := dbm.NewGoLevelDB("evidence", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	defer ed.Close()
	pool, e := evidence.NewPool(ed, store, bs.NewBlockStore(bd))
	if e != nil {
		t.Fatal(e)
	}
	for i, want := range sets {
		h := 99999 + int64(i)
		got, e := store.LoadValidators(h)
		if e != nil || !bytes.Equal(got.Hash(), want.Hash()) {
			t.Fatalf("lookup at %d failed: %v", h, e)
		}
		fresh := duplicateEvidence(t, h, time.Unix(200+int64(i), 0).UTC(), want)
		if e = pool.CheckEvidence(types.EvidenceList{fresh}); e != nil {
			t.Fatalf("stock evidence at boundary %d: %v", h, e)
		}
	}
	if _, e = store.LoadValidators(99998); e == nil {
		t.Fatal("fabricated pre-window validators")
	}
}

func TestRejectsGenesisHeightNormalizationAndAliasedExportGenesis(t *testing.T) {
	p, trust, _ := fixture(t)
	p.Genesis = bytes.Replace(p.Genesis, []byte(`"initial_height":"71"`), []byte(`"initial_height":"0"`), 1)
	if _, e := Verify(p, trust); e == nil {
		t.Fatal("normalized original InitialHeight=0 into another identity")
	}
	p, trust, _ = fixture(t)
	v, e := Verify(p, trust)
	if e != nil {
		t.Fatal(e)
	}
	home := filepath.Join(realTemp(t), "comet")
	if e = Install(home, v); e != nil {
		t.Fatal(e)
	}
	path := filepath.Join(home, "config", "genesis.json")
	target := filepath.Join(realTemp(t), "genesis")
	if e = os.Rename(path, target); e != nil {
		t.Fatal(e)
	}
	if e = os.Symlink(target, path); e != nil {
		t.Fatal(e)
	}
	pre, _ := decodeHex(p.ValidatorState, 1<<20)
	if _, e = Export(home, 100001, 100001, pre); e == nil {
		t.Fatal("export followed aliased genesis")
	}
}

func TestCLIProcessVerifyInstallAndContradictionExit(t *testing.T) {
	dir := realTemp(t)
	binaryPath := filepath.Join(dir, "etna-comet-import")
	build := exec.Command("go", "build", "-mod=readonly", "-o", binaryPath, "../../cmd/etna-comet-import")
	if output, e := build.CombinedOutput(); e != nil {
		t.Fatalf("build helper: %v %s", e, output)
	}
	p, trust, vals := fixture(t)
	path := filepath.Join(dir, "package.json")
	write := func() {
		raw, _ := json.Marshal(p)
		if e := os.WriteFile(path, raw, 0600); e != nil {
			t.Fatal(e)
		}
	}
	write()
	args := []string{"verify", "--package", path, "--trusted-comet-hash", trust.CometHash, "--trusted-el-hash", trust.ELHash, "--trusted-val-state-hash", trust.ValStateHash}
	output, e := exec.Command(binaryPath, args...).CombinedOutput()
	if e != nil {
		t.Fatalf("verify: %v %s", e, output)
	}
	var report Report
	if e = json.Unmarshal(output, &report); e != nil || report.InitialHeight != 71 {
		t.Fatalf("invalid verify report: %s", output)
	}
	args[0] = "install"
	args = append(args, "--home", filepath.Join(dir, "comet"))
	if output, e = exec.Command(binaryPath, args...).CombinedOutput(); e != nil {
		t.Fatalf("install: %v %s", e, output)
	}
	// Same certified input and trust; only the local fresh-install destination is occupied.
	if output, e = exec.Command(binaryPath, args...).Output(); e == nil || e.(*exec.ExitError).ExitCode() != 3 || len(output) != 0 {
		t.Fatalf("storage error must exit unavailable: %v %s", e, output)
	}
	changed := vals.Copy()
	changed.Validators[0].VotingPower = 11
	pre := makePreimage(100001, changed, changed, 0, 0)
	p.ValidatorState = hexBytes(pre)
	trust.ValStateHash = hexBytes(keccak(pre))
	write()
	args = []string{"verify", "--package", path, "--trusted-comet-hash", trust.CometHash, "--trusted-el-hash", trust.ELHash, "--trusted-val-state-hash", trust.ValStateHash}
	output, e = exec.Command(binaryPath, args...).Output()
	var exit *exec.ExitError
	if !errors.As(e, &exit) || exit.ExitCode() != 2 {
		t.Fatalf("contradiction exit: %v %s", e, output)
	}
	var contradiction ContradictionReceipt
	raw, _ := json.Marshal(p)
	if e := strictDecode(output, &contradiction); e != nil || contradiction.Schema != 1 || contradiction.Kind != "authenticated_contradiction" || contradiction.Reason != "validator_state_next_hash_mismatch" || contradiction.Height != 100001 || contradiction.CometHash != trust.CometHash || contradiction.ELHash != trust.ELHash || contradiction.ValStateHash != trust.ValStateHash || contradiction.PackageHash != hexBytes(keccak(raw)) {
		t.Fatalf("native contradiction has no matching receipt: %v %s", e, output)
	}
	args[len(args)-1] = hexBytes(make([]byte, 32))
	output, e = exec.Command(binaryPath, args...).Output()
	if !errors.As(e, &exit) || exit.ExitCode() != 1 || len(output) != 0 {
		t.Fatalf("candidate-rejection exit: %v %s", e, output)
	}
}

func TestRejectsBadNativeSignatureAndHistoricalSigningSet(t *testing.T) {
	p, trust, _ := fixture(t)
	raw, _ := decodeHex(p.Blocks[0].Commit, 1<<20)
	var commit pb.Commit
	if e := commit.Unmarshal(raw); e != nil {
		t.Fatal(e)
	}
	commit.Signatures[0].Signature[0] ^= 1
	raw, _ = commit.Marshal()
	p.Blocks[0].Commit = hexBytes(raw)
	if _, e := Verify(p, trust); e == nil {
		t.Fatal("accepted bad secp256k1eth commit")
	}
	p, trust, _ = fixture(t)
	p.Blocks[0].Validators[0].Power = 11
	if _, e := Verify(p, trust); e == nil {
		t.Fatal("accepted wrong own-height committee")
	}
}
func TestStreamingAcceptsFieldOrderWithoutChangingPackageHash(t *testing.T) {
	p, trust, _ := fixture(t)
	raw, e := json.Marshal(map[string]any{"schema": p.Schema, "genesis": p.Genesis, "blocks": p.Blocks, "validator_state": p.ValidatorState})
	if e != nil {
		t.Fatal(e)
	}
	v, e := VerifyStream(bytes.NewReader(raw), trust, realTemp(t), 1<<20)
	if e != nil {
		t.Fatal(e)
	}
	defer v.Close()
	want, e := Verify(p, trust)
	if e != nil {
		t.Fatal(e)
	}
	if want.Report() != v.Report() {
		t.Fatal("JSON field order changed verification")
	}
}

// linkedPackage changes the successor's embedded commit before authenticating that
// successor and updating the trusted terminal hash; the redundant commit stays valid.
func linkedPackage(t *testing.T, mutate func(*types.Commit)) (*Package, Trust, *types.ValidatorSet) {
	t.Helper()
	p, trust, vals := fixture(t)
	raw, _ := decodeHex(p.Blocks[0].Block, 32<<20)
	var bp pb.Block
	if e := bp.Unmarshal(raw); e != nil {
		t.Fatal(e)
	}
	raw, _ = decodeHex(p.Blocks[0].Commit, 16<<20)
	var cp pb.Commit
	if e := cp.Unmarshal(raw); e != nil {
		t.Fatal(e)
	}
	previous, e := types.CommitFromProto(&cp)
	if e != nil {
		t.Fatal(e)
	}
	previousID := previous.BlockID
	mutate(previous)
	bp.Header.Height++
	bp.Header.Time = bp.Header.Time.Add(time.Second)
	bp.Header.LastBlockId = previousID.ToProto()
	bp.LastCommit = previous.ToProto()
	bp.Header.LastCommitHash = previous.Hash()
	b, e := types.BlockFromProto(&bp)
	if e != nil {
		t.Fatal(e)
	}
	parts, e := b.MakePartSet(types.BlockPartSizeBytes)
	if e != nil {
		t.Fatal(e)
	}
	id := types.BlockID{Hash: b.Hash(), PartSetHeader: parts.Header()}
	key := secp256k1eth.PrivKey(bytes.Repeat([]byte{7}, 32))
	vote := &types.Vote{Type: pb.PrecommitType, Height: b.Height, Round: 0, BlockID: id, Timestamp: b.Time, ValidatorAddress: key.PubKey().Address(), ValidatorIndex: 0}
	vote.Signature, e = key.Sign(types.VoteSignBytes(b.ChainID, vote.ToProto()))
	if e != nil {
		t.Fatal(e)
	}
	commit := &types.Commit{Height: b.Height, Round: 0, BlockID: id, Signatures: []types.CommitSig{vote.CommitSig()}}
	bb, _ := bp.Marshal()
	cb, _ := commit.ToProto().Marshal()
	p.Blocks = append(p.Blocks, Block{Block: hexBytes(bb), Commit: hexBytes(cb), Validators: p.Blocks[0].Validators})
	pre := makePreimage(b.Height, vals, vals, 0, 0)
	p.ValidatorState = hexBytes(pre)
	trust.ValStateHash = hexBytes(keccak(pre))
	trust.CometHash = hexBytes(b.Hash())
	return p, trust, vals
}
func TestRejectsInvalidSuccessorLastCommit(t *testing.T) {
	for _, tc := range []struct {
		name   string
		mutate func(*types.Commit)
	}{{"signature", func(c *types.Commit) { c.Signatures[0].Signature[0] ^= 1 }}, {"full_block_id", func(c *types.Commit) {
		c.BlockID.PartSetHeader.Hash = bytes.Clone(c.BlockID.PartSetHeader.Hash)
		c.BlockID.PartSetHeader.Hash[0] ^= 1
	}}} {
		t.Run(tc.name, func(t *testing.T) {
			p, trust, _ := linkedPackage(t, tc.mutate)
			if _, e := Verify(p, trust); e == nil {
				t.Fatal("accepted successor LastCommit that would populate invalid stock C:h")
			}
			raw, _ := json.Marshal(p)
			if v, e := VerifyStream(bytes.NewReader(raw), trust, realTemp(t), 1<<20); e == nil {
				v.Close()
				t.Fatal("stream accepted invalid successor LastCommit")
			}
		})
	}
}
func TestRejectsDifferentValidRedundantNonterminalCommit(t *testing.T) {
	p, trust, _ := linkedPackage(t, func(c *types.Commit) {
		c.Round = 3
		key := secp256k1eth.PrivKey(bytes.Repeat([]byte{7}, 32))
		vote := &types.Vote{Type: pb.PrecommitType, Height: c.Height, Round: c.Round, BlockID: c.BlockID, Timestamp: c.Signatures[0].Timestamp, ValidatorAddress: key.PubKey().Address(), ValidatorIndex: 0}
		var e error
		vote.Signature, e = key.Sign(types.VoteSignBytes("etna-test", vote.ToProto()))
		if e != nil {
			t.Fatal(e)
		}
		c.Signatures[0] = vote.CommitSig()
	})
	if _, e := Verify(p, trust); e == nil {
		t.Fatal("accepted different original commit representations for nonterminal height")
	}
}
func TestReopensActualSuccessorCommitsAndPreservesMultiblockExport(t *testing.T) {
	p, trust, vals := linkedPackage(t, func(*types.Commit) {})
	v, e := Verify(p, trust)
	if e != nil {
		t.Fatal(e)
	}
	home := filepath.Join(realTemp(t), "comet")
	if e = Install(home, v); e != nil {
		t.Fatal(e)
	}
	db, e := dbm.NewGoLevelDB("blockstore", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	blocks := bs.NewBlockStore(db)
	for _, item := range p.Blocks {
		raw, _ := decodeHex(item.Block, 32<<20)
		var bp pb.Block
		if e = bp.Unmarshal(raw); e != nil {
			t.Fatal(e)
		}
		b, e := types.BlockFromProto(&bp)
		if e != nil {
			t.Fatal(e)
		}
		parts, e := b.MakePartSet(types.BlockPartSizeBytes)
		if e != nil {
			t.Fatal(e)
		}
		id := types.BlockID{Hash: b.Hash(), PartSetHeader: parts.Header()}
		stored := blocks.LoadBlockCommit(b.Height)
		if b.Height == 100002 {
			// Stock keeps the terminal commit only as SC:s until s+1 is saved.
			if stored != nil {
				t.Fatal("installed terminal C:s")
			}
			stored = blocks.LoadSeenCommit(b.Height)
		}
		if stored == nil {
			t.Fatal("missing actual stored commit")
		}
		if e = vals.VerifyCommit(b.ChainID, id, b.Height, stored); e != nil {
			t.Fatalf("invalid reopened C:%d: %v", b.Height, e)
		}
		raw, e = stored.ToProto().Marshal()
		if e != nil || hexBytes(raw) != item.Commit {
			t.Fatal("stored commit changed original representation")
		}
	}
	if e = db.Close(); e != nil {
		t.Fatal(e)
	}
	pre, _ := decodeHex(p.ValidatorState, 1<<20)
	out, e := Export(home, 100001, 100002, pre)
	if e != nil {
		t.Fatal(e)
	}
	wantRaw, _ := json.Marshal(p)
	gotRaw, _ := json.Marshal(out)
	if !bytes.Equal(wantRaw, gotRaw) {
		t.Fatal("multiblock import/export changed original bytes")
	}
	// Reopen verification must check the actual stock C:h record, independently
	// of valid block bytes, the redundant package commit and terminal seen commit.
	db, e = dbm.NewGoLevelDB("blockstore", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	stored := bs.NewBlockStore(db).LoadBlockCommit(100001)
	stored.Signatures[0].Signature[0] ^= 1
	corrupt, e := stored.ToProto().Marshal()
	if e != nil {
		t.Fatal(e)
	}
	if e = db.SetSync([]byte("C:100001"), corrupt); e != nil {
		t.Fatal(e)
	}
	if e = db.Close(); e != nil {
		t.Fatal(e)
	}
	if e = verifyReopened(filepath.Join(home, "data"), v); e == nil {
		t.Fatal("reopen accepted corrupted actual nonterminal C:h commit")
	}
}
func TestStrictSchemaRejectsCaseAliases(t *testing.T) {
	p, trust, _ := fixture(t)
	raw, _ := json.Marshal(p)
	for _, input := range []string{strings.Replace(string(raw), `"power":10`, `"Power":10`, 1), strings.Replace(string(raw), `"power":10`, `"power":10,"Power":10`, 1), strings.Replace(string(raw), `"blocks":[{"block":`, `"blocks":[{"Block":`, 1)} {
		if _, e := Read(strings.NewReader(input)); e == nil {
			t.Fatal("small reader accepted schema case alias")
		}
		if v, e := VerifyStream(strings.NewReader(input), trust, realTemp(t), 1<<20); e == nil {
			v.Close()
			t.Fatal("stream accepted schema case alias")
		}
	}
}

// observedHistoricalStore retains the real pinned stock implementation but makes
// any accidental historical priority-replay call fail immediately, without timing.
type observedHistoricalStore struct {
	sm.Store
	fastCalls int
	slowCalls int
}

func (s *observedHistoricalStore) LoadValidators(height int64) (*types.ValidatorSet, error) {
	s.slowCalls++
	return nil, errors.New("slow historical proposer-priority replay is forbidden")
}
func (s *observedHistoricalStore) LoadValidatorsFast(height int64) (*types.ValidatorSet, error) {
	s.fastCalls++
	return s.Store.(interface {
		LoadValidatorsFast(int64) (*types.ValidatorSet, error)
	}).LoadValidatorsFast(height)
}
func TestBulkHistoricalKeysAndPowersUseFastStockLookup(t *testing.T) {
	p, trust, sets := windowFixture(t)
	v, e := Verify(p, trust)
	if e != nil {
		t.Fatal(e)
	}
	home := filepath.Join(realTemp(t), "comet")
	if e = Install(home, v); e != nil {
		t.Fatal(e)
	}
	db, e := dbm.NewGoLevelDB("state", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	defer db.Close()
	observed := &observedHistoricalStore{Store: sm.NewStore(db, sm.StoreOptions{})}
	load, e := historicalValidatorLookup(observed)
	if e != nil {
		t.Fatal(e)
	}
	for i := 0; i < 1024; i++ {
		index := i % len(sets)
		got, e := load(99999 + int64(index))
		if e != nil || !bytes.Equal(got.Hash(), sets[index].Hash()) {
			t.Fatalf("bulk keys/powers mismatch at %d: %v", index, e)
		}
	}
	if observed.fastCalls != 1024 || observed.slowCalls != 0 {
		t.Fatalf("bulk lookup paths: fast=%d slow=%d", observed.fastCalls, observed.slowCalls)
	}
	if _, e = historicalValidatorLookup(struct{ sm.Store }{observed.Store}); e == nil {
		t.Fatal("missing fast capability silently accepted")
	}
}

// A fresh offline installation must fail even if the verified logical rows are all present
// when a final durability barrier encounters an unexpected inode after reopen.
func TestFreshInstallRequiresFinalStockFileSync(t *testing.T) {
	p, trust, _ := fixture(t)
	v, err := Verify(p, trust)
	if err != nil {
		t.Fatal(err)
	}
	home := filepath.Join(realTemp(t), "comet")
	calls := 0
	err = installFresh(home, v, func(path string) error {
		calls++
		if calls == 2 {
			if err := os.Symlink(filepath.Join(path, "config", "genesis.json"), filepath.Join(path, "data", "evidence.db", "unexpected")); err != nil {
				t.Fatal(err)
			}
		}
		return syncStockTree(path)
	})
	var unavailable *StorageError
	if calls != 2 || !errors.As(err, &unavailable) {
		t.Fatalf("final storage barrier must refuse with a repairable storage error: calls=%d err=%v", calls, err)
	}
	// A real verified/reopened image still cannot complete when fsync itself reports an
	// exhausted storage device at the final barrier. Preserve the typed cause for the CLI.
	full := errors.New("injected final filesystem sync failure")
	calls = 0
	err = installFresh(filepath.Join(realTemp(t), "comet"), v, func(path string) error {
		calls++
		if calls == 2 {
			return full
		}
		return syncStockTree(path)
	})
	if calls != 2 || !errors.As(err, &unavailable) || !errors.Is(err, full) {
		t.Fatalf("lost final sync classification: %v", err)
	}

}
