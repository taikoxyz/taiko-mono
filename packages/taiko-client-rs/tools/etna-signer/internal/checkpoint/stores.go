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
	gogotypes "github.com/cosmos/gogoproto/types"
	"github.com/syndtr/goleveldb/leveldb/opt"
)

// The stock dir the Rust caller writes after authenticate_import accepts the window.
const (
	// genesisFile holds the original GenesisDoc JSON.
	genesisFile = "genesis.json"
	// validatorStateFile holds the raw appendix-A preimage at s.
	validatorStateFile = "validator-state.bin"
	// blocksFile holds one Block JSON object per line, ascending from w+1 to s.
	blocksFile = "blocks.jsonl"
)

// stockInput is one decoded stock dir. Its blocks stay on disk: install streams them once to
// write the stores and once more to check the reopened stores.
type stockInput struct {
	genesisRaw []byte
	genesis    *types.GenesisDoc
	// height is s, the preimage height.
	height int64
	// current and next are the s+1 and s+2 sets with their landed priorities and proposers.
	current, next *types.ValidatorSet
	// appHash is ELHash(s), the post-s AppHash.
	appHash []byte
	// blocks is the path of blocksFile.
	blocks string
}

// readStock decodes the stock dir's genesis and preimage; blocks are read by walk.
func readStock(dir string, appHash []byte) (*stockInput, error) {
	if len(appHash) != 32 {
		return nil, errors.New("app hash must have 32 bytes")
	}
	raw, err := os.ReadFile(filepath.Join(dir, genesisFile))
	if err != nil {
		return nil, err
	}
	g, err := decodeGenesis(raw)
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
	return &stockInput{genesisRaw: raw, genesis: g, height: height, current: current, next: next, appHash: bytes.Clone(appHash), blocks: filepath.Join(dir, blocksFile)}, nil
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
// the preimage's s+1 and s+2 sets, AppHash = ELHash(s) and the original InitialHeight.
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

// Install decodes the stock dir, creates the absent home with config/genesis.json and the stock
// state, blockstore and evidence databases, then reopens them read-only and checks them. Signer
// keys and WAL are never read. The caller stages the other stores and publishes them together.
func Install(home, stockDir string, appHash []byte) (Report, error) {
	return installFresh(home, stockDir, appHash, syncStockTree)
}

func installFresh(home, stockDir string, appHash []byte, flushTree func(string) error) (report Report, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("stock store installation failed: %v", r)
		}
		if err != nil {
			report = Report{}
		}
	}()
	in, err := readStock(stockDir, appHash)
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
// validator and params records, a committed-evidence marker per evidence item without
// validating it again (DATA-5.4-3), and the post-s state through stock Bootstrap.
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
	// Reopening through LoadValidatorsFast/LoadConsensusParams checks compatibility.
	initial, err := sm.MakeGenesisState(in.genesis)
	if err != nil {
		return Report{}, err
	}
	initial.Version.Consensus.App = 1
	temporary := sm.NewStore(dbm.NewMemDB(), sm.StoreOptions{})
	if err = temporary.Bootstrap(initial); err != nil {
		return Report{}, err
	}
	pool, err := evidence.NewPool(evidenceDB, temporary, blocks)
	if err != nil {
		return Report{}, err
	}
	params := in.genesis.ConsensusParams.ToProto()
	var first int64
	var last *blockRecord
	var lastEvidence types.Evidence
	var previousHash []byte
	var changed int64
	err = in.walk(func(record *blockRecord) error {
		b := record.block
		if last == nil {
			first = b.Height
		}
		last = record
		// Stock SaveBlock(h) writes C:h-1 and SC:h. Like a stock node at state s,
		// the terminal commit is only SC:s; C:s appears when s+1 is saved.
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
		if b.Height == changed || b.Height%100000 == 0 {
			info.ValidatorSet, e = record.set.ToProto()
			if e != nil {
				return e
			}
		}
		raw, e := info.Marshal()
		if e != nil {
			return e
		}
		if e = batch.Set([]byte(fmt.Sprintf("validatorsKey:%d", b.Height)), raw); e != nil {
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
		if e = batch.WriteSync(); e != nil {
			return e
		}
		// Public Update marks committed evidence without historical verification.
		post := initial.Copy()
		post.LastBlockHeight = b.Height
		post.LastBlockTime = b.Time
		pool.Update(post, b.Evidence.Evidence)
		if len(b.Evidence.Evidence) > 0 {
			lastEvidence = b.Evidence.Evidence[len(b.Evidence.Evidence)-1]
		}
		return nil
	})
	if err != nil {
		return Report{}, err
	}
	state, err := in.state(last)
	if err != nil {
		return Report{}, err
	}
	if lastEvidence != nil {
		key, raw, e := evidenceMarker(lastEvidence)
		if e != nil {
			return Report{}, e
		}
		if e = evidenceDB.SetSync(key, raw); e != nil {
			return Report{}, e
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

func openReadOnly(home, name string) (*dbm.GoLevelDB, error) {
	return dbm.NewGoLevelDBWithOpts(name, filepath.Join(home, "data"), &opt.Options{ReadOnly: true, ErrorIfMissing: true})
}

// historicalValidatorLookup exposes only the pinned stock keys/powers fast path.
// Full landed sets/priorities are loaded through State.Load, never this view.
func historicalValidatorLookup(store sm.Store) (func(int64) (*types.ValidatorSet, error), error) {
	fast, ok := store.(interface {
		LoadValidatorsFast(int64) (*types.ValidatorSet, error)
	})
	if !ok {
		return nil, errors.New("pinned stock historical validator fast path unavailable")
	}
	return fast.LoadValidatorsFast, nil
}

// verifyReopened reads the closed stores back through stock APIs and compares them with a
// second decode of the stock dir. It re-verifies no commit: the stored bytes must equal the
// input bytes that authenticate_import already verified.
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
	store := sm.NewStore(sd, sm.StoreOptions{})
	loadValidators, e := historicalValidatorLookup(store)
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
		key := "C"
		var storedCommit *types.Commit
		if b.Height == in.height {
			// A stock node has no C:s before s+1, so stock evidence lookups at
			// height s fail on both nodes alike.
			if blocks.LoadBlockCommit(b.Height) != nil {
				return errors.New("reopened terminal C:s diverges from stock")
			}
			key = "SC"
			storedCommit = blocks.LoadSeenCommit(b.Height)
		} else {
			storedCommit = blocks.LoadBlockCommit(b.Height)
		}
		if storedCommit == nil {
			return fmt.Errorf("missing reopened %s:%d", key, b.Height)
		}
		storedBytes, e := storedCommit.ToProto().Marshal()
		if e != nil {
			return e
		}
		inputBytes, e := record.commit.ToProto().Marshal()
		if e != nil {
			return e
		}
		if !bytes.Equal(storedBytes, inputBytes) {
			return fmt.Errorf("reopened %s:%d differs from the input commit", key, b.Height)
		}
		vals, e := loadValidators(b.Height)
		if e != nil || !bytes.Equal(vals.Hash(), record.set.Hash()) {
			return errors.New("reopened historical validators mismatch")
		}
		for _, ev := range b.Evidence.Evidence {
			key, want, e := evidenceMarker(ev)
			if e != nil {
				return e
			}
			raw, e := ed.Get(key)
			if e != nil {
				return e
			}
			if !bytes.Equal(raw, want) {
				return errors.New("reopened committed evidence marker mismatch")
			}
		}
		params, e := store.LoadConsensusParams(b.Height)
		if e != nil || !fixedParams(params) {
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
	c := blocks.LoadSeenCommit(s.LastBlockHeight)
	if c == nil || !c.BlockID.Equals(s.LastBlockID) {
		return errors.New("missing reopened terminal seen commit")
	}
	return nil
}

// evidenceMarker follows the pinned stock pool's committed marker wire format;
// inspection performs no historical evidence verification or block lookup.
func evidenceMarker(ev types.Evidence) ([]byte, []byte, error) {
	key := append([]byte{0}, []byte(fmt.Sprintf("%016X/%X", ev.Height(), ev.Hash()))...)
	height := gogotypes.Int64Value{Value: ev.Height()}
	raw, err := height.Marshal()
	return key, raw, err
}
