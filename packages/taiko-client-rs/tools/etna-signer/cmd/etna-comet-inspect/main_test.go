package main

import (
	"crypto/sha256"
	dbm "github.com/cometbft/cometbft-db"
	"github.com/cometbft/cometbft/crypto/ed25519"
	sm "github.com/cometbft/cometbft/state"
	bs "github.com/cometbft/cometbft/store"
	"github.com/cometbft/cometbft/types"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

func fingerprints(t *testing.T, root string) map[string][32]byte {
	t.Helper()
	out := map[string][32]byte{}
	if err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.Mode().IsRegular() {
			raw, e := os.ReadFile(path)
			if e != nil {
				return e
			}
			out[path] = sha256.Sum256(raw)
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	return out
}
func TestInspectorReadsStockStateWithoutChangingAnyBytes(t *testing.T) {
	home := t.TempDir()
	data := filepath.Join(home, "data")
	if err := os.Mkdir(data, 0700); err != nil {
		t.Fatal(err)
	}
	database, err := dbm.NewGoLevelDB("state", data)
	if err != nil {
		t.Fatal(err)
	}
	genesis := &types.GenesisDoc{GenesisTime: time.Unix(100, 0), ChainID: "etna-inspect-test", InitialHeight: 7, ConsensusParams: types.DefaultConsensusParams(), Validators: []types.GenesisValidator{{PubKey: ed25519.GenPrivKey().PubKey(), Power: 1}}, AppHash: make([]byte, 32)}
	state, err := sm.MakeGenesisState(genesis)
	if err != nil {
		t.Fatal(err)
	}
	if err = sm.NewStore(database, sm.StoreOptions{}).Save(state); err != nil {
		t.Fatal(err)
	}
	database.Close()
	blocks, err := dbm.NewGoLevelDB("blockstore", data)
	if err != nil {
		t.Fatal(err)
	}
	blocks.Close()
	before := fingerprints(t, home)
	got, err := inspect(home, "goleveldb")
	if err != nil {
		t.Fatal(err)
	}
	if got.Empty || got.ChainID != genesis.ChainID || got.InitialHeight != 7 || got.StateHeight != 0 || got.BlockstoreHeight != 0 {
		t.Fatalf("unexpected report: %+v", got)
	}
	if !reflect.DeepEqual(before, fingerprints(t, home)) {
		t.Fatal("read-only inspection changed database bytes/names")
	}
	if _, err = inspect(home, "pebbledb"); err == nil {
		t.Fatal("unsupported backend accepted")
	}
}
func TestInspectorNeverCreatesMissingDatabases(t *testing.T) {
	home := t.TempDir()
	if err := os.Mkdir(filepath.Join(home, "data"), 0700); err != nil {
		t.Fatal(err)
	}
	before := fingerprints(t, home)
	got, err := inspect(home, "goleveldb")
	if err != nil || !got.Empty {
		t.Fatalf("empty store: %+v %v", got, err)
	}
	if !reflect.DeepEqual(before, fingerprints(t, home)) {
		t.Fatal("created files during inspection")
	}
}

func TestInspectorRefusesMissingLockWithoutCreatingIt(t *testing.T) {
	home := t.TempDir()
	data := filepath.Join(home, "data")
	os.Mkdir(data, 0700)
	db, err := dbm.NewGoLevelDB("state", data)
	if err != nil {
		t.Fatal(err)
	}
	db.Close()
	lock := filepath.Join(data, "state.db", "LOCK")
	if err = os.Remove(lock); err != nil {
		t.Fatal(err)
	}
	if _, err = inspect(home, "goleveldb"); err == nil {
		t.Fatal("missing lock accepted")
	}
	if _, err = os.Stat(lock); !os.IsNotExist(err) {
		t.Fatal("read-only open recreated LOCK")
	}
}

func TestInspectorReadsOneBlockCrashWindowAndRejectsMixedState(t *testing.T) {
	home := t.TempDir()
	data := filepath.Join(home, "data")
	if err := os.Mkdir(data, 0700); err != nil {
		t.Fatal(err)
	}
	genesis := &types.GenesisDoc{GenesisTime: time.Unix(100, 0), ChainID: "etna-inspect-crash", InitialHeight: 7, ConsensusParams: types.DefaultConsensusParams(), Validators: []types.GenesisValidator{{PubKey: ed25519.GenPrivKey().PubKey(), Power: 1}}, AppHash: make([]byte, 32)}
	state, err := sm.MakeGenesisState(genesis)
	if err != nil {
		t.Fatal(err)
	}
	database, err := dbm.NewGoLevelDB("state", data)
	if err != nil {
		t.Fatal(err)
	}
	if err = sm.NewStore(database, sm.StoreOptions{}).Save(state); err != nil {
		t.Fatal(err)
	}
	database.Close()
	block, err := state.MakeBlock(7, types.Txs{types.Tx("envelope")}, new(types.Commit), nil, state.Validators.GetProposer().Address)
	if err != nil {
		t.Fatal(err)
	}
	parts, err := block.MakePartSet(types.BlockPartSizeBytes)
	if err != nil {
		t.Fatal(err)
	}
	blocks, err := dbm.NewGoLevelDB("blockstore", data)
	if err != nil {
		t.Fatal(err)
	}
	bs.NewBlockStore(blocks).SaveBlock(block, parts, &types.Commit{Height: 7})
	blocks.Close()
	before := fingerprints(t, home)
	got, err := inspect(home, "goleveldb")
	if err != nil {
		t.Fatal(err)
	}
	if got.StateHeight != 0 || got.BlockstoreHeight != 7 || len(got.Blocks) != 1 || got.Blocks[0].Hash != hash(block.Hash()) || got.Blocks[0].Transactions[0] != hash([]byte("envelope")) {
		t.Fatalf("wrong crash metadata: %+v", got)
	}
	if !reflect.DeepEqual(before, fingerprints(t, home)) {
		t.Fatal("crash inspection changed files")
	}
	database, err = dbm.NewGoLevelDB("state", data)
	if err != nil {
		t.Fatal(err)
	}
	state.ChainID = "foreign"
	if err = sm.NewStore(database, sm.StoreOptions{}).Save(state); err != nil {
		t.Fatal(err)
	}
	database.Close()
	before = fingerprints(t, home)
	if _, err = inspect(home, "goleveldb"); err == nil {
		t.Fatal("mixed native chain identity accepted")
	}
	if !reflect.DeepEqual(before, fingerprints(t, home)) {
		t.Fatal("failed inspection changed files")
	}
}
