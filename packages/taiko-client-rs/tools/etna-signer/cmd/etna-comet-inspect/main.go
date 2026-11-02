// etna-comet-inspect reads pinned stock Comet databases without starting any service or writer.
package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	dbm "github.com/cometbft/cometbft-db"
	sm "github.com/cometbft/cometbft/state"
	bs "github.com/cometbft/cometbft/store"
	"github.com/syndtr/goleveldb/leveldb/opt"
	"os"
	"path/filepath"
)

type report struct {
	ValidatorsHash     string  `json:"validators_hash"`
	NextValidatorsHash string  `json:"next_validators_hash"`
	Schema             uint32  `json:"schema"`
	Empty              bool    `json:"empty"`
	ChainID            string  `json:"chain_id"`
	InitialHeight      int64   `json:"initial_height"`
	StateHeight        int64   `json:"state_height"`
	StateAppHash       string  `json:"state_app_hash"`
	StateCometHash     string  `json:"state_comet_hash"`
	BlockstoreHeight   int64   `json:"blockstore_height"`
	Blocks             []block `json:"blocks"`
}
type block struct {
	Height       int64    `json:"height"`
	ChainID      string   `json:"chain_id"`
	Hash         string   `json:"hash"`
	AppHash      string   `json:"app_hash"`
	ParentHash   string   `json:"parent_hash"`
	Transactions []string `json:"transactions"`
}

// openReadOnly refuses aliases/missing LOCK before LevelDB can create even a lock inode.
func openReadOnly(data, name string) (*dbm.GoLevelDB, error) {
	path := filepath.Join(data, name+".db")
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil || !info.IsDir() {
		return nil, errors.New("invalid database directory")
	}
	if err = filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && !info.Mode().IsRegular() {
			return errors.New("aliased database entry")
		}
		return nil
	}); err != nil {
		return nil, err
	}
	lock, err := os.Lstat(filepath.Join(path, "LOCK"))
	if err != nil || !lock.Mode().IsRegular() {
		return nil, errors.New("missing database lock inode")
	}
	return dbm.NewGoLevelDBWithOpts(name, data, &opt.Options{ReadOnly: true, ErrorIfMissing: true})
}
func hash(value []byte) string {
	if len(value) == 0 {
		return "0x" + hex.EncodeToString(make([]byte, 32))
	}
	return "0x" + hex.EncodeToString(value)
}
func inspect(home, backend string) (result *report, failure error) {
	defer func() {
		if recover() != nil {
			result = nil
			failure = errors.New("corrupt stock database")
		}
	}()
	if backend != "goleveldb" || !filepath.IsAbs(home) {
		return nil, errors.New("unsupported inspection configuration")
	}
	data := filepath.Join(home, "data")
	for _, path := range []string{home, data} {
		info, err := os.Lstat(path)
		if err != nil || !info.IsDir() {
			return nil, errors.New("invalid Comet home")
		}
	}
	stateDB, err := openReadOnly(data, "state")
	if err != nil {
		return nil, err
	}
	if stateDB != nil {
		defer stateDB.Close()
	}
	blockDB, err := openReadOnly(data, "blockstore")
	if err != nil {
		return nil, err
	}
	if blockDB != nil {
		defer blockDB.Close()
	}
	out := &report{Schema: 1, Empty: true, ValidatorsHash: hash(nil), NextValidatorsHash: hash(nil), StateAppHash: hash(nil), StateCometHash: hash(nil), Blocks: []block{}}
	var state sm.State
	if stateDB != nil {
		state, err = sm.NewStore(stateDB, sm.StoreOptions{}).Load()
		if err != nil {
			return nil, err
		}
	}
	var store *bs.BlockStore
	if blockDB != nil {
		store = bs.NewBlockStore(blockDB)
		out.BlockstoreHeight = store.Height()
	}
	if state.IsEmpty() {
		if out.BlockstoreHeight != 0 {
			return nil, errors.New("blocks without state identity")
		}
		return out, nil
	}
	out.ValidatorsHash = hash(state.Validators.Hash())
	out.NextValidatorsHash = hash(state.NextValidators.Hash())
	out.Empty = false
	out.ChainID = state.ChainID
	out.InitialHeight = state.InitialHeight
	out.StateHeight = state.LastBlockHeight
	out.StateAppHash = hash(state.AppHash)
	out.StateCometHash = hash(state.LastBlockID.Hash)
	next := state.LastBlockHeight + 1
	if state.LastBlockHeight == 0 {
		next = state.InitialHeight
	}
	if out.BlockstoreHeight != state.LastBlockHeight && out.BlockstoreHeight != next {
		return nil, errors.New("incoherent state/blockstore heights")
	}
	for _, height := range []int64{state.LastBlockHeight, out.BlockstoreHeight} {
		if height == 0 || (len(out.Blocks) > 0 && out.Blocks[len(out.Blocks)-1].Height == height) {
			continue
		}
		if store == nil {
			return nil, errors.New("missing blockstore")
		}
		meta := store.LoadBlockMeta(height)
		blockData := store.LoadBlock(height)
		if meta == nil || blockData == nil || blockData.ValidateBasic() != nil || blockData.Header.ChainID != state.ChainID || !bytes.Equal(meta.BlockID.Hash, blockData.Hash()) {
			return nil, errors.New("invalid stored block")
		}
		if height == state.LastBlockHeight && !bytes.Equal(state.LastBlockID.Hash, blockData.Hash()) {
			return nil, errors.New("state block hash mismatch")
		}
		item := block{Height: height, ChainID: blockData.Header.ChainID, Hash: hash(blockData.Hash()), AppHash: hash(blockData.Header.AppHash), ParentHash: hash(blockData.Header.LastBlockID.Hash), Transactions: []string{}}
		for _, tx := range blockData.Data.Txs {
			item.Transactions = append(item.Transactions, "0x"+hex.EncodeToString(tx))
		}
		out.Blocks = append(out.Blocks, item)
	}
	return out, nil
}
func main() {
	home := flag.String("home", "", "existing installed Comet home")
	backend := flag.String("backend", "goleveldb", "pinned read-only database backend")
	flag.Parse()
	result, err := inspect(*home, *backend)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Comet store inspection failed")
		os.Exit(1)
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		os.Exit(1)
	}
}
