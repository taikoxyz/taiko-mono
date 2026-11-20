package checkpoint

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"syscall"

	dbm "github.com/cometbft/cometbft-db"
	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/evidence"
	statepb "github.com/cometbft/cometbft/proto/tendermint/state"
	sm "github.com/cometbft/cometbft/state"
	bs "github.com/cometbft/cometbft/store"
	"github.com/cometbft/cometbft/types"
	"github.com/syndtr/goleveldb/leveldb/opt"
)

// The stock dir the Rust caller writes after authenticate_import accepts the window.
const (
	// genesisFile holds the original GenesisDoc JSON.
	genesisFile = "genesis.json"
	// validatorStateFile holds the raw appendix-A preimage of valStateHash(s): the state the
	// importer derived for s from the package's authenticated preimage for s-1 (DATA-5.4-3).
	validatorStateFile = "validator-state.bin"
	// blocksFile holds one Block JSON object per line, ascending from w+1 to s.
	blocksFile = "blocks.jsonl"
)

// stockInput is one decoded stock dir. Its blocks stay on disk: install streams them once to
// write the stores and once more to check the reopened stores.
type stockInput struct {
	genesisRaw []byte
	genesis    *types.GenesisDoc
	// height is s, the height of the derived validator state.
	height int64
	// current and next are the s+1 and s+2 sets with their derived priorities and proposers.
	current, next *types.ValidatorSet
	// appHash is the post-s AppHash appHash(ELHash(s), valStateHash(s)) (CONS-3.1-8), as the
	// importer computed it; it is installed, not recomputed.
	appHash []byte
	// blocks is the path of blocksFile.
	blocks string
	// nMax is the authenticated committee cap that fixes block.max_bytes (START-10-21).
	nMax int64
}

// readStock decodes the stock dir's genesis, whose consensus params must be the fixed ones for
// committee cap nMax, and its preimage; blocks are read by walk.
func readStock(dir string, appHash []byte, nMax int64) (*stockInput, error) {
	if len(appHash) != 32 {
		return nil, errors.New("app hash must have 32 bytes")
	}
	raw, err := os.ReadFile(filepath.Join(dir, genesisFile))
	if err != nil {
		return nil, err
	}
	g, err := decodeGenesis(raw, nMax)
	if err != nil {
		return nil, err
	}
	preimage, err := os.ReadFile(filepath.Join(dir, validatorStateFile))
	if err != nil {
		return nil, err
	}
	height, current, next, err := DecodeValState(preimage)
	if err != nil {
		return nil, err
	}
	return &stockInput{genesisRaw: raw, genesis: g, height: height, current: current, next: next, appHash: bytes.Clone(appHash), blocks: filepath.Join(dir, blocksFile), nMax: nMax}, nil
}

// walk decodes blocksFile one line at a time and visits each height in file order.
func (in *stockInput) walk(visit func(*blockRecord) error) error {
	f, err := os.Open(in.blocks)
	if err != nil {
		return err
	}
	defer f.Close()
	reader := bufio.NewReaderSize(f, 64<<10)
	for {
		line, readErr := reader.ReadBytes('\n')
		if readErr != nil && readErr != io.EOF {
			return readErr
		}
		if len(line) == 0 && readErr == io.EOF {
			return nil
		}
		var item Block
		if err = json.Unmarshal(line, &item); err != nil {
			return err
		}
		record, err := decodeBlock(in.genesis, item)
		if err != nil {
			return err
		}
		if err = visit(record); err != nil {
			return err
		}
		if readErr == io.EOF {
			return nil
		}
	}
}

// state builds the post-s state (DATA-5.4-4): the terminal BlockID, time and signing set,
// the preimage's s+1 and s+2 sets, AppHash = appHash(ELHash(s), valStateHash(s)) and the
// original InitialHeight.
func (in *stockInput) state(terminal *blockRecord) (sm.State, error) {
	if terminal == nil {
		return sm.State{}, errors.New("empty consensus window")
	}
	if terminal.block.Height != in.height {
		return sm.State{}, errors.New("terminal height differs from the validator-state preimage")
	}
	s, err := sm.MakeGenesisState(in.genesis)
	if err != nil {
		return sm.State{}, err
	}
	s.Version.Consensus.App = 1
	s.LastBlockHeight = in.height
	s.LastBlockID = terminal.id
	s.LastBlockTime = terminal.block.Time
	s.LastValidators = terminal.set.Copy()
	s.Validators = in.current.Copy()
	s.NextValidators = in.next.Copy()
	s.LastHeightValidatorsChanged = in.height + 2
	s.LastHeightConsensusParamsChanged = in.height + 1
	s.LastResultsHash = types.NewResults([]*abci.ExecTxResult{{}}).Hash()
	s.AppHash = bytes.Clone(in.appHash)
	return s, nil
}

func syncDir(path string) (err error) {
	f, e := os.Open(path)
	if e != nil {
		return e
	}
	defer func() { err = errors.Join(err, f.Close()) }()
	return f.Sync()
}

// syncStockTree flushes the closed private native files before the installer reports
// success. Children precede their directory entries. Reject links, devices and other
// unexpected entries instead of following an alias outside the fresh home.
func syncStockTree(path string) (err error) {
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	if !info.IsDir() && (!info.Mode().IsRegular() || info.Sys().(*syscall.Stat_t).Nlink != 1) {
		return fmt.Errorf("unexpected inode in private stock staging: %s", path)
	}
	f, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0)
	if err != nil {
		return err
	}
	defer func() { err = errors.Join(err, f.Close()) }()
	opened, err := f.Stat()
	if err != nil {
		return err
	}
	if !os.SameFile(info, opened) {
		return errors.New("stock staging inode changed during sync")
	}
	if info.IsDir() {
		names, err := f.Readdirnames(-1)
		if err != nil {
			return err
		}
		for _, name := range names {
			if err := syncStockTree(filepath.Join(path, name)); err != nil {
				return err
			}
		}
	}
	return f.Sync()
}

// Install decodes the stock dir, creates the absent home with config/genesis.json, the stock
// state and blockstore databases, an empty evidence database and a fresh store instance ID
// (data/etna-store-instance), then reopens them read-only and checks them. It is the offline store tool CONS-3.1-1 permits for 5.4 import: it runs with
// CometBFT stopped and the signer disconnected, never runs consensus or signs, and never reads
// signer keys, signer state or the WAL (DATA-5.4-5/7). nMax is the committee cap the caller
// authenticated (committeeConfigHash covers it); the genesis must carry the consensus params it
// fixes. The caller stages the other stores and publishes them together.
func Install(home, stockDir string, appHash []byte, nMax int64) (Report, error) {
	return installFresh(home, stockDir, appHash, nMax, syncStockTree)
}

func installFresh(home, stockDir string, appHash []byte, nMax int64, flushTree func(string) error) (report Report, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("stock store installation failed: %v", r)
		}
		if err != nil {
			report = Report{}
		}
	}()
	in, err := readStock(stockDir, appHash, nMax)
	if err != nil {
		return Report{}, err
	}
	if err = os.Mkdir(home, 0700); err != nil {
		return Report{}, err
	}
	if err = os.Mkdir(filepath.Join(home, "config"), 0700); err != nil {
		return Report{}, err
	}
	if err = os.Mkdir(filepath.Join(home, "data"), 0700); err != nil {
		return Report{}, err
	}
	f, err := os.OpenFile(filepath.Join(home, "config", "genesis.json"), os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return Report{}, err
	}
	_, writeErr := f.Write(in.genesisRaw)
	syncErr := f.Sync()
	closeErr := f.Close()
	if err = errors.Join(writeErr, syncErr, closeErr); err != nil {
		return Report{}, err
	}
	if report, err = writeStores(filepath.Join(home, "data"), in); err != nil {
		return Report{}, err
	}
	// New stores get a fresh instance ID, so a signer that signed on another home fences its
	// last signed height here (RECOV-8.2-2, DATA-5.4-7).
	if _, err = writeStoreInstance(filepath.Join(home, "data")); err != nil {
		return Report{}, err
	}
	if err = flushTree(home); err != nil {
		return Report{}, err
	}
	if err = verifyReopened(home, in); err != nil {
		return Report{}, err
	}
	// Read-only reopen can still touch native diagnostics and lock files.
	if err = flushTree(home); err != nil {
		return Report{}, err
	}
	if err = syncDir(filepath.Dir(home)); err != nil {
		return Report{}, err
	}
	return report, nil
}

// writeStores saves every window block and commit through stock SaveBlock, the historical
// validator and params records, s's own commit under the block-commit lookup and the post-s
// state through stock Bootstrap (DATA-5.4-3/4). The evidence database is created empty: the stock
// pool starts with no pending or committed evidence, and no window block carries any
// (CONS-3.1-10).
func writeStores(data string, in *stockInput) (Report, error) {
	// Native consensus fsyncs each live commit. Here every row belongs to a fresh,
	// unpublished image: a crash discards it. Use the same stock block/state APIs and
	// enforce file and directory durability for the closed image as a whole.
	options := &opt.Options{NoSync: true, ErrorIfExist: true}
	stateDB, err := dbm.NewGoLevelDBWithOpts("state", data, options)
	if err != nil {
		return Report{}, err
	}
	defer stateDB.Close()
	blockDB, err := dbm.NewGoLevelDBWithOpts("blockstore", data, options)
	if err != nil {
		return Report{}, err
	}
	defer blockDB.Close()
	evidenceDB, err := dbm.NewGoLevelDBWithOpts("evidence", data, options)
	if err != nil {
		return Report{}, err
	}
	defer evidenceDB.Close()
	store := sm.NewStore(stateDB, sm.StoreOptions{})
	blocks := bs.NewBlockStore(blockDB)
	// The public Bootstrap API has no historical-record-only operation. Use the
	// pinned public protobuf records and stock key formats, with bounded metadata pointers.
	// Reopening through LoadValidators/LoadConsensusParams checks compatibility.
	params := in.genesis.ConsensusParams.ToProto()
	var first int64
	var last *blockRecord
	var previousHash []byte
	var changed int64
	err = in.walk(func(record *blockRecord) error {
		b := record.block
		if last == nil {
			first = b.Height
		}
		last = record
		// Stock SaveBlock(h) writes C:h-1 and SC:h; C:s follows below.
		blocks.SaveBlock(b, record.parts, record.commit)
		batch := stateDB.NewBatch()
		defer batch.Close()
		var e error
		hash := record.set.Hash()
		if !bytes.Equal(hash, previousHash) {
			changed = b.Height
			previousHash = bytes.Clone(hash)
		}
		info := statepb.ValidatorsInfo{LastHeightChanged: changed}
		if fullSetHeight(b.Height, changed) {
			if e = checkFullSet(record.set); e != nil {
				return fmt.Errorf("validator set at %d: %w", b.Height, e)
			}
			info.ValidatorSet, e = record.set.ToProto()
			if e != nil {
				return e
			}
		}
		raw, e := info.Marshal()
		if e != nil {
			return e
		}
		if e = batch.Set(validatorsKey(b.Height), raw); e != nil {
			return e
		}
		cp := statepb.ConsensusParamsInfo{LastHeightChanged: first}
		if b.Height == first {
			cp.ConsensusParams = params
		}
		raw, e = cp.Marshal()
		if e != nil {
			return e
		}
		if e = batch.Set([]byte(fmt.Sprintf("consensusParamsKey:%d", b.Height)), raw); e != nil {
			return e
		}
		return batch.WriteSync()
	})
	if err != nil {
		return Report{}, err
	}
	state, err := in.state(last)
	if err != nil {
		return Report{}, err
	}
	// A stock node writes C:s only when it saves s+1, from that block's LastCommit. Stock
	// evidence verification reads C:x for a signed header at any height it accepts, s
	// included, so s's verified own commit is installed there as well as under SC:s.
	terminal, err := last.commit.ToProto().Marshal()
	if err != nil {
		return Report{}, err
	}
	if err = blockDB.Set(blockCommitKey(state.LastBlockHeight), terminal); err != nil {
		return Report{}, err
	}
	for _, set := range []*types.ValidatorSet{state.LastValidators, state.Validators, state.NextValidators} {
		if err = checkFullSet(set); err != nil {
			return Report{}, fmt.Errorf("post-s validator set: %w", err)
		}
	}
	if err = store.Bootstrap(state); err != nil {
		return Report{}, err
	}
	if err = store.SetOfflineStateSyncHeight(state.LastBlockHeight); err != nil {
		return Report{}, err
	}
	if err = errors.Join(stateDB.Close(), blockDB.Close(), evidenceDB.Close()); err != nil {
		return Report{}, err
	}
	id := state.LastBlockID
	return Report{FirstHeight: first, LastHeight: state.LastBlockHeight, BlockID: BlockID{Hash: hexBytes(id.Hash), Parts: PartSet{Total: id.PartSetHeader.Total, Hash: hexBytes(id.PartSetHeader.Hash)}}}, nil
}

// fullSetHeight reports whether stock saveValidatorsInfo stores a full set at height: the height
// its set changed or a multiple of valSetCheckpointInterval (100,000, state/store.go). The first
// window height counts as a change, so no record points below the window.
func fullSetHeight(height, lastChanged int64) bool {
	return height == lastChanged || height%100000 == 0
}

// validatorsKey and blockCommitKey are the pinned stock keys of state/store.go and
// store/store.go.
func validatorsKey(height int64) []byte  { return []byte(fmt.Sprintf("validatorsKey:%d", height)) }
func blockCommitKey(height int64) []byte { return []byte(fmt.Sprintf("C:%d", height)) }

func openReadOnly(home, name string) (*dbm.GoLevelDB, error) {
	return dbm.NewGoLevelDBWithOpts(name, filepath.Join(home, "data"), &opt.Options{ReadOnly: true, ErrorIfMissing: true})
}

// historicalValidatorLookup exposes only the pinned stock keys/powers fast path, which reads
// the same stored record as LoadValidators without its in-memory priority increment.
func historicalValidatorLookup(store sm.Store) (func(int64) (*types.ValidatorSet, error), error) {
	fast, ok := store.(interface {
		LoadValidatorsFast(int64) (*types.ValidatorSet, error)
	})
	if !ok {
		return nil, errors.New("pinned stock historical validator fast path unavailable")
	}
	return fast.LoadValidatorsFast, nil
}

// storedFullSet decodes the full set stored at height, or returns nil where stock keeps only a
// pointer, and holds it to checkFullSet.
func storedFullSet(db dbm.DB, height int64) (*types.ValidatorSet, error) {
	raw, err := db.Get(validatorsKey(height))
	if err != nil {
		return nil, err
	}
	if len(raw) == 0 {
		return nil, fmt.Errorf("missing reopened validators record at %d", height)
	}
	var info statepb.ValidatorsInfo
	if err = info.Unmarshal(raw); err != nil {
		return nil, err
	}
	if info.ValidatorSet == nil {
		return nil, nil
	}
	set, err := types.ValidatorSetFromProto(info.ValidatorSet)
	if err != nil {
		return nil, fmt.Errorf("reopened validator set at %d: %w", height, err)
	}
	if err = checkFullSet(set); err != nil {
		return nil, fmt.Errorf("reopened validator set at %d: %w", height, err)
	}
	return set, nil
}

// sameCommit compares a stored commit with the input one byte for byte.
func sameCommit(stored, input *types.Commit) bool {
	if stored == nil {
		return false
	}
	a, e1 := stored.ToProto().Marshal()
	b, e2 := input.ToProto().Marshal()
	return e1 == nil && e2 == nil && bytes.Equal(a, b)
}

// verifyReopened reads the closed stores back through stock APIs and compares them with a
// second decode of the stock dir, as DATA-5.4-3 requires before P2P is enabled: at every window
// height x, LoadBlockMeta(x) holds the authenticated header and time, LoadBlockCommit(x) x's own
// commit and the stored validator lookup the matching set; every full set passes checkFullSet;
// the evidence database is empty. It re-verifies no commit: the stored bytes must equal the input
// bytes that authenticate_import already verified.
//
// Stock LoadValidators(x) rebuilds a height without a stored set by advancing the last stored
// one by x minus its height, so calling it at every height costs the window length squared times
// the set size. It is called at every height still inside either evidence age limit at s, the
// only heights a stock pool at s or later passes to it (verify checks expiry first), and at
// every stored full set; the other heights check the same stored record through stock
// LoadValidatorsFast, which skips only the in-memory priority increment.
func verifyReopened(home string, in *stockInput) (err error) {
	sd, e := openReadOnly(home, "state")
	if e != nil {
		return e
	}
	defer func() { err = errors.Join(err, sd.Close()) }()
	bd, e := openReadOnly(home, "blockstore")
	if e != nil {
		return e
	}
	defer func() { err = errors.Join(err, bd.Close()) }()
	ed, e := openReadOnly(home, "evidence")
	if e != nil {
		return e
	}
	defer func() { err = errors.Join(err, ed.Close()) }()
	if e = requireEmpty(ed); e != nil {
		return e
	}
	store := sm.NewStore(sd, sm.StoreOptions{})
	loadStored, e := historicalValidatorLookup(store)
	if e != nil {
		return e
	}
	s, e := store.Load()
	if e != nil {
		return e
	}
	blocks := bs.NewBlockStore(bd)
	var last *blockRecord
	if e = in.walk(func(record *blockRecord) error {
		last = record
		b := record.block
		read := blocks.LoadBlock(b.Height)
		if read == nil || !bytes.Equal(read.Hash(), b.Hash()) {
			return errors.New("reopened block mismatch")
		}
		meta := blocks.LoadBlockMeta(b.Height)
		if meta == nil || !meta.BlockID.Equals(record.id) || !bytes.Equal(meta.Header.Hash(), b.Hash()) || !meta.Header.Time.Equal(b.Time) {
			return fmt.Errorf("reopened block meta at %d differs from the authenticated header", b.Height)
		}
		if !sameCommit(blocks.LoadBlockCommit(b.Height), record.commit) {
			return fmt.Errorf("reopened C:%d differs from the input commit", b.Height)
		}
		if b.Height == in.height && !sameCommit(blocks.LoadSeenCommit(b.Height), record.commit) {
			return fmt.Errorf("reopened SC:%d differs from the input commit", b.Height)
		}
		full, e := storedFullSet(sd, b.Height)
		if e != nil {
			return e
		}
		vals, e := loadStored(b.Height)
		if e != nil || !bytes.Equal(vals.Hash(), record.set.Hash()) {
			return errors.New("reopened historical validators mismatch")
		}
		if full != nil || !evidence.IsEvidenceExpired(s.LastBlockHeight, s.LastBlockTime, b.Height, b.Time, s.ConsensusParams.Evidence) {
			vals, e = store.LoadValidators(b.Height)
			if e != nil || !bytes.Equal(vals.Hash(), record.set.Hash()) {
				return fmt.Errorf("reopened stock LoadValidators(%d) mismatch: %v", b.Height, e)
			}
		}
		params, e := store.LoadConsensusParams(b.Height)
		if e != nil || !fixedParams(params, in.nMax) {
			return errors.New("reopened historical params mismatch")
		}
		return nil
	}); e != nil {
		return e
	}
	want, e := in.state(last)
	if e != nil {
		return e
	}
	if !bytes.Equal(s.Bytes(), want.Bytes()) {
		return errors.New("reopened stock state mismatch")
	}
	for offset, set := range []*types.ValidatorSet{want.LastValidators, want.Validators, want.NextValidators} {
		height := want.LastBlockHeight + int64(offset)
		stored, e := storedFullSet(sd, height)
		if e != nil {
			return e
		}
		if stored == nil || !bytes.Equal(stored.Hash(), set.Hash()) || !bytes.Equal(stored.Proposer.Address, set.Proposer.Address) {
			return fmt.Errorf("reopened full validator set at %d mismatch", height)
		}
	}
	for _, set := range []*types.ValidatorSet{s.LastValidators, s.Validators, s.NextValidators} {
		if e = checkFullSet(set); e != nil {
			return fmt.Errorf("reopened post-s state: %w", e)
		}
	}
	return nil
}

// requireEmpty refuses an evidence database holding any key: the stock pool starts empty.
func requireEmpty(db dbm.DB) (err error) {
	it, err := db.Iterator(nil, nil)
	if err != nil {
		return err
	}
	defer func() { err = errors.Join(err, it.Close()) }()
	if it.Valid() {
		return errors.New("reopened evidence store is not empty")
	}
	return it.Error()
}
