package checkpoint

import (
	"bytes"
	"errors"
	"strings"
	"testing"

	dbm "github.com/cometbft/cometbft-db"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	sm "github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/types"
)

// exportGenesis is a two-validator stock genesis whose first height is initial.
func exportGenesis(initial int64) *types.GenesisDoc {
	return &types.GenesisDoc{
		ChainID: "test", InitialHeight: initial, ConsensusParams: etnaParams(),
		Validators: []types.GenesisValidator{
			{PubKey: secp256k1eth.PrivKey(bytes.Repeat([]byte{1}, 32)).PubKey(), Power: 20},
			{PubKey: secp256k1eth.PrivKey(bytes.Repeat([]byte{2}, 32)).PubKey(), Power: 10},
		},
		AppHash: bytes.Repeat([]byte{3}, 32),
	}
}

// proposerIndex is the index of the stored proposer in vs.
func proposerIndex(t *testing.T, vs *types.ValidatorSet) uint64 {
	t.Helper()
	for i, v := range vs.Validators {
		if bytes.Equal(v.Address, vs.Proposer.Address) {
			return uint64(i)
		}
	}
	t.Fatal("stock proposer missing")
	return 0
}

// saveStockState writes state into a fresh stock state store and returns its directory.
func saveStockState(t *testing.T, state sm.State) string {
	t.Helper()
	dir := t.TempDir()
	db, err := dbm.NewGoLevelDB("state", dir)
	if err != nil {
		t.Fatal(err)
	}
	if err := sm.NewStore(db, sm.StoreOptions{}).Save(state); err != nil {
		t.Fatal(err)
	}
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}
	return dir
}

func TestExportComparesStoredPrioritiesAndProposers(t *testing.T) {
	gen := exportGenesis(1)
	stock, err := sm.MakeGenesisState(gen)
	if err != nil {
		t.Fatal(err)
	}
	dir := saveStockState(t, stock)

	current, next := stock.Validators, stock.NextValidators
	cp, np := proposerIndex(t, current), proposerIndex(t, next)
	identity := ExportIdentity{ChainID: gen.ChainID, Height: 0, InitialHeight: gen.InitialHeight, AppHash: gen.AppHash}
	preimage := makePreimage(0, current, next, cp, np)
	if err := VerifyExportState(dir, preimage, identity); err != nil {
		t.Fatal(err)
	}
	wrong := current.Copy()
	wrong.Validators[0].ProposerPriority++
	for name, altered := range map[string][]byte{
		"current priority": makePreimage(0, wrong, next, cp, np),
		"next proposer":    makePreimage(0, current, next, cp, 1-np),
	} {
		t.Run(name, func(t *testing.T) {
			if err := VerifyExportState(dir, altered, identity); !errors.Is(err, ErrExportValStateMismatch) {
				t.Fatalf("wrong validator state got %v", err)
			}
		})
	}
	identity.AppHash = bytes.Repeat([]byte{4}, 32)
	if err := VerifyExportState(dir, preimage, identity); err == nil || errors.Is(err, ErrExportValStateMismatch) {
		t.Fatalf("wrong snapshot identity got %v", err)
	}
}

// A producer reads the height x its stopped snapshot holds and exports x + 1; an export at
// another checkpoint is refused with both heights.
func TestSnapshotHeightIsTheCommittedHeightAndExportNamesAMismatch(t *testing.T) {
	origin, err := sm.MakeGenesisState(exportGenesis(1))
	if err != nil {
		t.Fatal(err)
	}
	// Stock keeps a later generation's post-InitChain state at LastBlockHeight 0: height 6.
	recovered, err := sm.MakeGenesisState(exportGenesis(7))
	if err != nil {
		t.Fatal(err)
	}
	// A state after block 5 also holds the set that signed it.
	later := origin.Copy()
	later.LastBlockHeight = 5
	later.LastValidators = origin.Validators.Copy()
	for name, c := range map[string]struct {
		state  sm.State
		height int64
	}{"origin": {origin, 0}, "recovery origin": {recovered, 6}, "later": {later, 5}} {
		report, err := SnapshotHeight(saveStockState(t, c.state))
		if err != nil || report != (SnapshotReport{ChainID: "test", LastBlockHeight: c.height}) {
			t.Fatalf("%s: got %+v, %v", name, report, err)
		}
	}
	current, next := later.Validators, later.NextValidators
	preimage := makePreimage(4, current, next, proposerIndex(t, current), proposerIndex(t, next))
	identity := ExportIdentity{ChainID: "test", Height: 4, InitialHeight: 1, AppHash: later.AppHash}
	err = VerifyExportState(saveStockState(t, later), preimage, identity)
	if err == nil || errors.Is(err, ErrExportValStateMismatch) ||
		!strings.Contains(err.Error(), "snapshot is at height 5, but checkpoint 5 needs it at height 4") {
		t.Fatalf("export of s = 5 from a snapshot at 5 got %v", err)
	}
	if _, err := SnapshotHeight(t.TempDir()); err == nil {
		t.Fatal("a directory without a state store has no height")
	}
}
