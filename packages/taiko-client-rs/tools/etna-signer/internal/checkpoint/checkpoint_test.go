package checkpoint

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/evidence"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	pb "github.com/cometbft/cometbft/proto/tendermint/types"
	cmtversion "github.com/cometbft/cometbft/proto/tendermint/version"
	sm "github.com/cometbft/cometbft/state"
	bs "github.com/cometbft/cometbft/store"
	"github.com/cometbft/cometbft/types"
	"github.com/cometbft/cometbft/version"
)

// stockPackage is one stock dir held in memory: the files the Rust caller writes after
// authenticate_import accepted the window.
type stockPackage struct {
	Genesis        json.RawMessage
	Blocks         []Block
	ValidatorState []byte
}

// terminal is the fixture's post-s identity: the full terminal BlockID and ELHash(s).
type terminal struct {
	id      types.BlockID
	appHash []byte
}

func fixture(t *testing.T) (*stockPackage, terminal, *types.ValidatorSet) {
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
	p := &stockPackage{Genesis: json.RawMessage(genesis), Blocks: []Block{{Block: hexBytes(bb), Commit: hexBytes(cb), Validators: []Validator{{Key: hexBytes(key.PubKey().Bytes()), Power: 10}}}}, ValidatorState: makePreimage(b.Height, vals, vals, 0, 0)}
	return p, terminal{id: id, appHash: bytes.Repeat([]byte{9}, 32)}, vals
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

// writeStockDir writes p as genesis.json, validator-state.bin and one blocks.jsonl line per block.
func writeStockDir(t *testing.T, p *stockPackage) string {
	t.Helper()
	dir := t.TempDir()
	var lines bytes.Buffer
	for _, block := range p.Blocks {
		raw, err := json.Marshal(block)
		if err != nil {
			t.Fatal(err)
		}
		lines.Write(raw)
		lines.WriteByte('\n')
	}
	for name, raw := range map[string][]byte{genesisFile: p.Genesis, validatorStateFile: p.ValidatorState, blocksFile: lines.Bytes()} {
		if err := os.WriteFile(filepath.Join(dir, name), raw, 0600); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

// install writes p as a stock dir and installs it into a new home.
func install(t *testing.T, p *stockPackage, term terminal) (home, dir string) {
	t.Helper()
	dir = writeStockDir(t, p)
	home = filepath.Join(t.TempDir(), "comet")
	if _, err := Install(home, dir, term.appHash); err != nil {
		t.Fatal(err)
	}
	return home, dir
}

// reopen runs the installer's own read-only reopen check against an installed home.
func reopen(t *testing.T, home, dir string, term terminal) error {
	t.Helper()
	in, err := readStock(dir, term.appHash)
	if err != nil {
		t.Fatal(err)
	}
	return verifyReopened(home, in)
}

// loadState reads the installed post-s state through the stock state store.
func loadState(t *testing.T, home string) sm.State {
	t.Helper()
	db, err := dbm.NewGoLevelDB("state", filepath.Join(home, "data"))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	s, err := sm.NewStore(db, sm.StoreOptions{}).Load()
	if err != nil {
		t.Fatal(err)
	}
	return s
}

// The helper reports the installed terminal and installs the DATA-5.4-4 post-s state.
func TestInstallCLIReportsStockTerminalIdentity(t *testing.T) {
	work := t.TempDir()
	binaryPath := filepath.Join(work, "etna-comet-import")
	build := exec.Command("go", "build", "-mod=readonly", "-o", binaryPath, "../../cmd/etna-comet-import")
	if output, e := build.CombinedOutput(); e != nil {
		t.Fatalf("build helper: %v %s", e, output)
	}
	p, term, sets := windowFixture(t)
	dir := writeStockDir(t, p)
	home := filepath.Join(work, "comet")
	args := []string{"install", "--home", home, "--stock-dir", dir, "--app-hash", hexBytes(term.appHash)}
	output, e := exec.Command(binaryPath, args...).Output()
	if e != nil {
		t.Fatalf("install: %v %s", e, output)
	}
	var report Report
	decoder := json.NewDecoder(bytes.NewReader(output))
	decoder.DisallowUnknownFields()
	if e = decoder.Decode(&report); e != nil {
		t.Fatalf("invalid install report: %v %s", e, output)
	}
	s := int64(99999 + len(sets) - 1)
	want := Report{FirstHeight: 99999, LastHeight: s, BlockID: BlockID{Hash: hexBytes(term.id.Hash), Parts: PartSet{Total: term.id.PartSetHeader.Total, Hash: hexBytes(term.id.PartSetHeader.Hash)}}}
	if report != want {
		t.Fatalf("report %+v, want the fixture terminal %+v", report, want)
	}
	state := loadState(t, home)
	if state.LastBlockHeight != s || !bytes.Equal(state.AppHash, term.appHash) || state.LastHeightValidatorsChanged != s+2 || state.LastHeightConsensusParamsChanged != s+1 || state.InitialHeight != 71 {
		t.Fatalf("wrong installed post-s state: %+v", state)
	}
	if !state.LastBlockID.Equals(term.id) || !bytes.Equal(state.LastResultsHash, types.NewResults([]*abci.ExecTxResult{{}}).Hash()) {
		t.Fatal("installed terminal identity or results hash differs from the window")
	}
	// The home must be absent: the same input into the now existing home fails with no report.
	output, e = exec.Command(binaryPath, args...).Output()
	var exit *exec.ExitError
	if !errors.As(e, &exit) || exit.ExitCode() != 1 || len(output) != 0 {
		t.Fatalf("second install into the same home: %v %s", e, output)
	}
}

func TestStoredProposerAtSwitch(t *testing.T) {
	p, term, vals := fixture(t)
	key := secp256k1eth.PrivKey(bytes.Repeat([]byte{8}, 32))
	next := types.NewValidatorSet([]*types.Validator{types.NewValidator(vals.Validators[0].PubKey, 10), types.NewValidator(key.PubKey(), 20)})
	next.Validators[0].ProposerPriority = -200
	next.Validators[1].ProposerPriority = 200
	next.Proposer = next.Validators[0]
	p.ValidatorState = makePreimage(100001, vals, next, 0, 0)
	home, _ := install(t, p, term)
	s := loadState(t, home)
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
func addEvidence(t *testing.T, p *stockPackage, term *terminal, ev types.Evidence) {
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
	term.id = id
}
func TestEvidenceBelowWindowCommittedMarkerAndNewEvidence(t *testing.T) {
	p, term, vals := fixture(t)
	below := duplicateEvidence(t, 99990, time.Unix(150, 0).UTC(), vals)
	addEvidence(t, p, &term, below)
	home, _ := install(t, p, term)
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

func TestTerminalCommitUsesStockKeysWithoutSuccessorBlock(t *testing.T) {
	p, term, _ := fixture(t)
	home, dir := install(t, p, term)
	if e := reopen(t, home, dir, term); e != nil {
		t.Fatalf("reopen rejected the installed stores: %v", e)
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
	if seen == nil || !seen.BlockID.Equals(term.id) {
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
	if e = reopen(t, home, dir, term); e == nil || !strings.Contains(e.Error(), "terminal C:s diverges from stock") {
		t.Fatalf("reopen accepted a terminal C:s that stock does not write: %v", e)
	}
}

// lightClientAttackVerdict runs stock CheckEvidence at state s on an
// equivocation LightClientAttackEvidence whose common height is s.
func lightClientAttackVerdict(t *testing.T, data string, vals *types.ValidatorSet) error {
	t.Helper()
	bd, e := dbm.NewGoLevelDB("blockstore", data)
	if e != nil {
		t.Fatal(e)
	}
	defer bd.Close()
	sd, e := dbm.NewGoLevelDB("state", data)
	if e != nil {
		t.Fatal(e)
	}
	defer sd.Close()
	ed, e := dbm.NewGoLevelDB("evidence", data)
	if e != nil {
		t.Fatal(e)
	}
	defer ed.Close()
	blocks := bs.NewBlockStore(bd)
	pool, e := evidence.NewPool(ed, sm.NewStore(sd, sm.StoreOptions{}), blocks)
	if e != nil {
		t.Fatal(e)
	}
	meta, seen := blocks.LoadBlockMeta(100001), blocks.LoadSeenCommit(100001)
	if meta == nil || seen == nil {
		t.Fatal("terminal block or seen commit missing")
	}
	// Same round as the terminal commit and a validly derived header, so this
	// is equivocation, not amnesia or lunatic.
	conflicting := meta.Header
	conflicting.DataHash = bytes.Repeat([]byte{0xab}, 32)
	id := types.BlockID{Hash: conflicting.Hash(), PartSetHeader: types.PartSetHeader{Total: 1, Hash: bytes.Repeat([]byte{4}, 32)}}
	key := secp256k1eth.PrivKey(bytes.Repeat([]byte{7}, 32))
	vote := &types.Vote{Type: pb.PrecommitType, Height: conflicting.Height, Round: seen.Round, BlockID: id, Timestamp: conflicting.Time, ValidatorAddress: key.PubKey().Address(), ValidatorIndex: 0}
	if vote.Signature, e = key.Sign(types.VoteSignBytes(conflicting.ChainID, vote.ToProto())); e != nil {
		t.Fatal(e)
	}
	commit := &types.Commit{Height: conflicting.Height, Round: seen.Round, BlockID: id, Signatures: []types.CommitSig{vote.CommitSig()}}
	ev := &types.LightClientAttackEvidence{
		ConflictingBlock:    &types.LightBlock{SignedHeader: &types.SignedHeader{Header: &conflicting, Commit: commit}, ValidatorSet: vals},
		CommonHeight:        100001,
		ByzantineValidators: vals.Validators,
		TotalVotingPower:    vals.TotalVotingPower(),
		Timestamp:           meta.Header.Time,
	}
	if e = ev.ValidateBasic(); e != nil {
		t.Fatal(e)
	}
	return pool.CheckEvidence(types.EvidenceList{ev})
}

func TestLightClientAttackAtTerminalHeightMatchesStock(t *testing.T) {
	p, term, vals := fixture(t)
	home, _ := install(t, p, term)
	data := filepath.Join(home, "data")
	// A stock node at state s has no C:s, so its signed-header lookup at
	// common height s fails. The imported node must give the same verdict.
	if e := lightClientAttackVerdict(t, data, vals); e == nil || !strings.Contains(e.Error(), "don't have commit at height #100001") {
		t.Fatalf("imported verdict at state s differs from stock: %v", e)
	}
	// Control: with a C:s row the same evidence verifies, so only the key
	// layout decides the verdict above.
	db, e := dbm.NewGoLevelDB("blockstore", data)
	if e != nil {
		t.Fatal(e)
	}
	raw, e := bs.NewBlockStore(db).LoadSeenCommit(100001).ToProto().Marshal()
	if e != nil {
		t.Fatal(e)
	}
	if e = db.SetSync([]byte("C:100001"), raw); e != nil {
		t.Fatal(e)
	}
	if e = db.Close(); e != nil {
		t.Fatal(e)
	}
	if e = lightClientAttackVerdict(t, data, vals); e != nil {
		t.Fatalf("control evidence rejected with C:s present: %v", e)
	}
}

func windowFixture(t *testing.T) (*stockPackage, terminal, []*types.ValidatorSet) {
	t.Helper()
	p, term, old := fixture(t)
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
		b := types.Block{Header: base.Header, Data: base.Data, Evidence: base.Evidence, LastCommit: base.LastCommit}
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
		term.id = id
	}
	p.ValidatorState = makePreimage(99999+int64(len(sets))-1, old, old, 0, 0)
	return p, term, sets
}
func TestHistoricalValidatorLookupsAtChangesAndPeriodicCheckpoints(t *testing.T) {
	p, term, sets := windowFixture(t)
	home, _ := install(t, p, term)
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

func TestRejectsGenesisHeightNormalization(t *testing.T) {
	p, term, _ := fixture(t)
	p.Genesis = bytes.Replace(p.Genesis, []byte(`"initial_height":"71"`), []byte(`"initial_height":"0"`), 1)
	home := filepath.Join(t.TempDir(), "comet")
	if _, e := Install(home, writeStockDir(t, p), term.appHash); e == nil {
		t.Fatal("normalized original InitialHeight=0 into another identity")
	}
}

// linkedFixture appends a signed successor whose embedded LastCommit is the first block's commit.
func linkedFixture(t *testing.T) (*stockPackage, terminal) {
	t.Helper()
	p, term, vals := fixture(t)
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
	bp.Header.Height++
	bp.Header.Time = bp.Header.Time.Add(time.Second)
	bp.Header.LastBlockId = previous.BlockID.ToProto()
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
	p.ValidatorState = makePreimage(b.Height, vals, vals, 0, 0)
	term.id = id
	return p, term
}

// Stock SaveBlock keeps each nonterminal commit as the successor's C:h and the terminal one as
// SC:s. Reopen must compare those actual records with the input commit bytes.
func TestReopensActualSuccessorCommits(t *testing.T) {
	p, term := linkedFixture(t)
	home, dir := install(t, p, term)
	if e := reopen(t, home, dir, term); e != nil {
		t.Fatalf("reopen rejected the installed stores: %v", e)
	}
	db, e := dbm.NewGoLevelDB("blockstore", filepath.Join(home, "data"))
	if e != nil {
		t.Fatal(e)
	}
	blocks := bs.NewBlockStore(db)
	for _, height := range []int64{100001, 100002} {
		stored := blocks.LoadBlockCommit(height)
		if height == 100002 {
			// Stock keeps the terminal commit only as SC:s until s+1 is saved.
			if stored != nil {
				t.Fatal("installed terminal C:s")
			}
			stored = blocks.LoadSeenCommit(height)
		}
		if stored == nil {
			t.Fatal("missing actual stored commit")
		}
		raw, e := stored.ToProto().Marshal()
		if e != nil || hexBytes(raw) != p.Blocks[height-100001].Commit {
			t.Fatal("stored commit changed original representation")
		}
	}
	stored := blocks.LoadBlockCommit(100001)
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
	if e = reopen(t, home, dir, term); e == nil || !strings.Contains(e.Error(), "C:100001 differs from the input commit") {
		t.Fatalf("reopen accepted corrupted actual nonterminal C:h commit: %v", e)
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
	p, term, sets := windowFixture(t)
	home, _ := install(t, p, term)
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

// A fresh offline installation must fail even if the logical rows are all present
// when a final durability barrier encounters an unexpected inode after reopen.
func TestFreshInstallRequiresFinalStockFileSync(t *testing.T) {
	p, term, _ := fixture(t)
	dir := writeStockDir(t, p)
	home := filepath.Join(t.TempDir(), "comet")
	calls := 0
	_, err := installFresh(home, dir, term.appHash, func(path string) error {
		calls++
		if calls == 2 {
			if err := os.Symlink(filepath.Join(path, "config", "genesis.json"), filepath.Join(path, "data", "evidence.db", "unexpected")); err != nil {
				t.Fatal(err)
			}
		}
		return syncStockTree(path)
	})
	if calls != 2 || err == nil {
		t.Fatalf("final storage barrier must refuse: calls=%d err=%v", calls, err)
	}
	// A reopened image still cannot complete when fsync itself reports an exhausted
	// storage device at the final barrier.
	full := errors.New("injected final filesystem sync failure")
	calls = 0
	_, err = installFresh(filepath.Join(t.TempDir(), "comet"), dir, term.appHash, func(path string) error {
		calls++
		if calls == 2 {
			return full
		}
		return syncStockTree(path)
	})
	if calls != 2 || !errors.Is(err, full) {
		t.Fatalf("lost final sync failure: %v", err)
	}
}
