package checkpoint

import (
	"bytes"
	"errors"
	"testing"

	dbm "github.com/cometbft/cometbft-db"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	sm "github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/types"
)

func TestExportComparesStoredPrioritiesAndProposers(t *testing.T) {
	gen := &types.GenesisDoc{
		ChainID: "test", InitialHeight: 1, ConsensusParams: etnaParams(),
		Validators: []types.GenesisValidator{
			{PubKey: secp256k1eth.PrivKey(bytes.Repeat([]byte{1}, 32)).PubKey(), Power: 20},
			{PubKey: secp256k1eth.PrivKey(bytes.Repeat([]byte{2}, 32)).PubKey(), Power: 10},
		},
		AppHash: bytes.Repeat([]byte{3}, 32),
	}
	stock, err := sm.MakeGenesisState(gen)
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	db, err := dbm.NewGoLevelDB("state", dir)
	if err != nil {
		t.Fatal(err)
	}
	if err := sm.NewStore(db, sm.StoreOptions{}).Save(stock); err != nil {
		t.Fatal(err)
	}
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}

	index := func(vs *types.ValidatorSet) uint64 {
		for i, v := range vs.Validators {
			if bytes.Equal(v.Address, vs.Proposer.Address) {
				return uint64(i)
			}
		}
		t.Fatal("stock proposer missing")
		return 0
	}
	current, next := stock.Validators, stock.NextValidators
	cp, np := index(current), index(next)
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
