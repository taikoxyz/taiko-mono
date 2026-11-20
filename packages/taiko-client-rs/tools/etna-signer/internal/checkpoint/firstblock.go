package checkpoint

// Certified first-block repair (CONS-3.1-9). Stock CometBFT v0.40.0 keeps its state at height 0
// until a generation's first block's state is saved, and its handshake requires the block store
// to be at most one block above that state. When a generation's initial_height is above 1 and a
// node crashes after saving the first block and before saving its state, the store is at
// initial_height while the state is at 0, so the handshake panics whatever the app reports.
//
// RepairFirstBlock runs offline, with CometBFT stopped and the signer fenced. It preserves the
// original stores, recovers the exact decided block and its commit (from the node's own block
// store or a peer's export), verifies them against the fixed genesis, chain_id and first
// committee, and applies that block exactly as the stock handshake would have had its height
// check used initial_height: InitChain if the app is at height 0, then stock BlockExecutor
// ApplyBlock over the app's ABCI socket (FinalizeBlock and Commit on the real app, which aligns
// its EL), or, when the app already committed the block, over the FinalizeBlock response the
// state store kept, as stock's mock-app replay does. Stock code saves the response and the state;
// the block store, its seen commit and the WAL stay as they were. It never runs consensus,
// never signs and never accepts another block for the height.

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	dbm "github.com/cometbft/cometbft-db"
	abcicli "github.com/cometbft/cometbft/abci/client"
	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/crypto/merkle"
	"github.com/cometbft/cometbft/libs/log"
	"github.com/cometbft/cometbft/mempool"
	"github.com/cometbft/cometbft/proxy"
	sm "github.com/cometbft/cometbft/state"
	bs "github.com/cometbft/cometbft/store"
	"github.com/cometbft/cometbft/types"
	"github.com/syndtr/goleveldb/leveldb/opt"
)

// StoreInstanceFile is the store instance ID's name under <comet home>/data (RECOV-8.2-2): 32
// lowercase hex characters and a newline, mode 0600, replaced with a fresh value by every path
// that creates, imports, restores or rebuilds the Comet stores.
const StoreInstanceFile = "etna-store-instance"

// ErrFirstBlockContradiction marks an authenticated contradiction found by the repair: two
// different certified blocks for the first height, an app whose result differs from the one the
// state store kept, or an app reporting another committed boundary. Startup stops for
// investigation; the CLI exits 2.
var ErrFirstBlockContradiction = errors.New("first-block contradiction")

// contradiction wraps a message as an ErrFirstBlockContradiction.
func contradiction(format string, args ...any) error {
	return fmt.Errorf("%w: %s", ErrFirstBlockContradiction, fmt.Sprintf(format, args...))
}

// RepairOptions configures one first-block repair.
type RepairOptions struct {
	// Home is the stopped CometBFT home: config/genesis.json and the goleveldb stores in data/.
	Home string
	// Backup is an absent directory outside data/ that receives a copy of data/ before anything
	// changes.
	Backup string
	// App is the running app's ABCI address, tcp://host:port or unix://path.
	App string
	// PeerExport optionally names a peer's ExportFirstBlock output for the same genesis.
	PeerExport string
	// Logger receives stock BlockExecutor logs; nil discards them.
	Logger log.Logger
}

// RepairReport is the repair's one JSON line.
type RepairReport struct {
	// Height is the generation's first height, initial_height.
	Height int64 `json:"height"`
	// BlockID is the certified block's full ID.
	BlockID BlockID `json:"block_id"`
	// AppHash is the app hash after the block, which the state, the next header and the app's
	// Info carry.
	AppHash string `json:"app_hash"`
	// Source is "local" (the node's own block store) or "peer" (installed from PeerExport).
	Source string `json:"source"`
	// Applied is "executed" (the real app ran FinalizeBlock and Commit), "replayed" (the app had
	// committed the block; the kept response was replayed) or "already_repaired".
	Applied string `json:"applied"`
	// Backup is the preserved copy of the original data directory.
	Backup string `json:"backup"`
	// StoreInstance is the fresh store instance ID.
	StoreInstance string `json:"store_instance"`
}

// ExportFirstBlock reads a generation's certified first block from a stopped node's stores and
// returns it in the blocks.jsonl line format: the original block, its own-height commit (C:h
// when the node saved the next block, else the seen commit) and the genesis validators. The
// commit must certify the block under the genesis committee.
func ExportFirstBlock(home string) (item Block, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("first-block export failed: %v", r)
		}
	}()
	genesis, vals, err := firstBlockGenesis(home)
	if err != nil {
		return Block{}, err
	}
	db, err := dbm.NewGoLevelDBWithOpts("blockstore", filepath.Join(home, "data"), &opt.Options{ReadOnly: true, ErrorIfMissing: true})
	if err != nil {
		return Block{}, fmt.Errorf("open the stopped block store: %w", err)
	}
	defer func() { err = errors.Join(err, db.Close()) }()
	blocks := bs.NewBlockStore(db)
	height := genesis.InitialHeight
	block, meta := blocks.LoadBlock(height), blocks.LoadBlockMeta(height)
	if block == nil || meta == nil {
		return Block{}, fmt.Errorf("the block store holds no block at the first height %d", height)
	}
	commit := blocks.LoadBlockCommit(height)
	if commit == nil {
		commit = blocks.LoadSeenCommit(height)
	}
	if commit == nil {
		return Block{}, fmt.Errorf("the block store holds no commit for the first height %d", height)
	}
	if err = vals.VerifyCommit(genesis.ChainID, meta.BlockID, height, commit); err != nil {
		return Block{}, fmt.Errorf("the stored commit does not certify the first block: %w", err)
	}
	item, err = encodeFirstBlock(block, commit, vals)
	if err != nil {
		return Block{}, err
	}
	record, err := decodeBlock(genesis, item)
	if err != nil {
		return Block{}, err
	}
	if !record.id.Equals(meta.BlockID) {
		return Block{}, errors.New("the stored block does not hash to its stored BlockID")
	}
	return item, nil
}

// RepairFirstBlock repairs a home stopped by the first-block crash; see the file comment. In
// order: it refuses a home whose genesis starts at height 1 (stock replays that block) and one
// whose stores CometBFT holds open; copies data/ to Backup and syncs the copy; writes a fresh
// store instance ID; recovers and verifies the certified block; asks the app for its committed
// boundary; applies the block; and reads back the state, the block store and the app's Info.
// A failure before the state is saved leaves the stores as stock left them (the instance ID
// and the backup aside); a rerun resumes from wherever stock's own write order stopped.
func RepairFirstBlock(o RepairOptions) (report RepairReport, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("first-block repair failed: %v", r)
		}
		if err != nil {
			report = RepairReport{}
		}
	}()
	logger := o.Logger
	if logger == nil {
		logger = log.NewNopLogger()
	}
	genesis, vals, err := firstBlockGenesis(o.Home)
	if err != nil {
		return RepairReport{}, err
	}
	height := genesis.InitialHeight
	data := filepath.Join(o.Home, "data")
	if err = preserve(data, o.Backup); err != nil {
		return RepairReport{}, err
	}
	instance, err := writeStoreInstance(data)
	if err != nil {
		return RepairReport{}, err
	}
	report = RepairReport{Height: height, Backup: o.Backup, StoreInstance: instance}

	options := &opt.Options{ErrorIfMissing: true}
	stateDB, err := dbm.NewGoLevelDBWithOpts("state", data, options)
	if err != nil {
		return RepairReport{}, fmt.Errorf("open the state store: %w", err)
	}
	defer func() { err = errors.Join(err, stateDB.Close()) }()
	blockDB, err := dbm.NewGoLevelDBWithOpts("blockstore", data, options)
	if err != nil {
		return RepairReport{}, fmt.Errorf("open the block store: %w", err)
	}
	defer func() { err = errors.Join(err, blockDB.Close()) }()
	stateStore := sm.NewStore(stateDB, sm.StoreOptions{})
	blocks := bs.NewBlockStore(blockDB)
	state, err := stateStore.LoadFromDBOrGenesisDoc(genesis)
	if err != nil {
		return RepairReport{}, err
	}
	if state.ChainID != genesis.ChainID || state.InitialHeight != height {
		return RepairReport{}, errors.New("the state store belongs to another genesis")
	}

	record, source, err := certifiedFirstBlock(genesis, vals, blocks, o.PeerExport)
	if err != nil {
		return RepairReport{}, err
	}
	report.Source = source
	report.BlockID = BlockID{Hash: hexBytes(record.id.Hash), Parts: PartSet{Total: record.id.PartSetHeader.Total, Hash: hexBytes(record.id.PartSetHeader.Hash)}}

	client, err := abcicli.NewClient(o.App, "socket", true)
	if err != nil {
		return RepairReport{}, err
	}
	client.SetLogger(logger.With("module", "abci-client"))
	if err = client.Start(); err != nil {
		return RepairReport{}, fmt.Errorf("connect to the app at %s: %w", o.App, err)
	}
	defer func() { err = errors.Join(err, client.Stop()) }()
	query := proxy.NewAppConnQuery(client, proxy.NopMetrics())
	consensus := proxy.NewAppConnConsensus(client, proxy.NopMetrics())
	ctx := context.Background()
	info, err := query.Info(ctx, proxy.RequestInfo)
	if err != nil {
		return RepairReport{}, fmt.Errorf("app Info: %w", err)
	}

	switch state.LastBlockHeight {
	case height:
		// A rerun after the state was saved: only check that everything agrees.
		report.Applied = "already_repaired"
	case 0:
		if blocks.Height() == 0 {
			// The peer path: install the certified block as stock SaveBlock would have.
			blocks.SaveBlock(record.block, record.parts, record.commit)
		}
		// As the stock handshake: the app version is set from Info while no block is committed.
		state.Version.Consensus.App = info.AppVersion
		switch info.LastBlockHeight {
		case 0:
			if state, err = initChain(ctx, consensus, genesis, state, stateStore); err != nil {
				return RepairReport{}, err
			}
			kept, _ := stateStore.LoadLastFinalizeBlockResponse(height)
			executor := sm.NewBlockExecutor(stateStore, logger, sameAsKept{consensus, kept}, &mempool.NopMempool{}, sm.EmptyEvidencePool{}, blocks)
			if state, err = executor.ApplyBlock(state, record.id, record.block); err != nil {
				return RepairReport{}, err
			}
			report.Applied = "executed"
		case height:
			kept, e := stateStore.LoadLastFinalizeBlockResponse(height)
			if e != nil {
				return RepairReport{}, fmt.Errorf("the app committed block %d but the state store kept no FinalizeBlock response for it: %w", height, e)
			}
			if !bytes.Equal(kept.AppHash, info.LastBlockAppHash) {
				return RepairReport{}, contradiction("the app reports app hash %X at %d, the kept FinalizeBlock response %X", info.LastBlockAppHash, height, kept.AppHash)
			}
			replay, e := keptResponseApp(kept)
			if e != nil {
				return RepairReport{}, e
			}
			executor := sm.NewBlockExecutor(stateStore, logger, replay, &mempool.NopMempool{}, sm.EmptyEvidencePool{}, blocks)
			if state, err = executor.ApplyBlock(state, record.id, record.block); err != nil {
				return RepairReport{}, err
			}
			report.Applied = "replayed"
		default:
			return RepairReport{}, contradiction("the app reports committed height %d; a generation starting at %d can only be at 0 or %d", info.LastBlockHeight, height, height)
		}
	default:
		return RepairReport{}, fmt.Errorf("the stock state is at height %d, not at 0 or the first height %d: this is not the first-block failure", state.LastBlockHeight, height)
	}

	// Read back what stock's handshake will see, then the app's own boundary.
	saved, err := stateStore.Load()
	if err != nil {
		return RepairReport{}, err
	}
	if saved.LastBlockHeight != height || !saved.LastBlockID.Equals(record.id) {
		return RepairReport{}, errors.New("the saved state does not name the certified first block")
	}
	meta, seen := blocks.LoadBlockMeta(height), blocks.LoadSeenCommit(height)
	if blocks.Height() != height || meta == nil || !meta.BlockID.Equals(record.id) || seen == nil {
		return RepairReport{}, errors.New("the block store does not hold the certified first block and its seen commit")
	}
	if err = vals.VerifyCommit(genesis.ChainID, record.id, height, seen); err != nil {
		return RepairReport{}, fmt.Errorf("the stored seen commit does not certify the first block: %w", err)
	}
	info, err = query.Info(ctx, proxy.RequestInfo)
	if err != nil {
		return RepairReport{}, fmt.Errorf("app Info after the repair: %w", err)
	}
	if info.LastBlockHeight != height || !bytes.Equal(info.LastBlockAppHash, saved.AppHash) {
		return RepairReport{}, contradiction("the app reports height %d app hash %X, the repaired state %d app hash %X", info.LastBlockHeight, info.LastBlockAppHash, height, saved.AppHash)
	}
	// Stock writes each batch with a synced log; sync the directory entries too.
	if err = syncDir(data); err != nil {
		return RepairReport{}, err
	}
	report.AppHash = hexBytes(saved.AppHash)
	return report, nil
}

// firstBlockGenesis reads the home's fixed genesis and its committee. Only a generation whose
// initial_height is above 1 has the first-block failure.
func firstBlockGenesis(home string) (*types.GenesisDoc, *types.ValidatorSet, error) {
	genesis, err := types.GenesisDocFromFile(filepath.Join(home, "config", "genesis.json"))
	if err != nil {
		return nil, nil, err
	}
	if genesis.InitialHeight <= 1 {
		return nil, nil, fmt.Errorf("initial_height %d: stock CometBFT replays a first block at height 1 itself; nothing to repair", genesis.InitialHeight)
	}
	vals := make([]*types.Validator, len(genesis.Validators))
	for i, val := range genesis.Validators {
		vals[i] = types.NewValidator(val.PubKey, val.Power)
	}
	set := types.NewValidatorSet(vals)
	if err = set.ValidateBasic(); err != nil {
		return nil, nil, fmt.Errorf("genesis validators: %w", err)
	}
	return genesis, set, nil
}

// certifiedFirstBlock returns the first block and its commit, from the block store or, when it
// holds none, the peer export, and checks it: canonical bytes, no evidence (CONS-3.1-10), the
// genesis chain_id and initial height, and a commit holding more than 2/3 of the genesis
// committee's power for its full BlockID. A peer block that differs from the stored one is a
// contradiction: two certified blocks at one height.
func certifiedFirstBlock(genesis *types.GenesisDoc, vals *types.ValidatorSet, blocks *bs.BlockStore, peer string) (*blockRecord, string, error) {
	height := genesis.InitialHeight
	var local, remote *blockRecord
	switch stored := blocks.Height(); {
	case stored == height && blocks.Base() == height:
		block, meta, seen := blocks.LoadBlock(height), blocks.LoadBlockMeta(height), blocks.LoadSeenCommit(height)
		if block == nil || meta == nil || seen == nil {
			return nil, "", fmt.Errorf("the block store lacks the block, meta or seen commit of %d", height)
		}
		item, err := encodeFirstBlock(block, seen, vals)
		if err != nil {
			return nil, "", err
		}
		if local, err = decodeBlock(genesis, item); err != nil {
			return nil, "", fmt.Errorf("stored first block: %w", err)
		}
		if !local.id.Equals(meta.BlockID) {
			return nil, "", errors.New("the stored block does not hash to its stored BlockID")
		}
	case stored == 0:
	default:
		return nil, "", fmt.Errorf("the block store spans %d..%d, not the generation's first block %d alone: this is not the first-block failure", blocks.Base(), stored, height)
	}
	if peer != "" {
		raw, err := readBounded(peer, int64(genesis.ConsensusParams.Block.MaxBytes)*4+(64<<20))
		if err != nil {
			return nil, "", err
		}
		var item Block
		if err = json.Unmarshal(raw, &item); err != nil {
			return nil, "", fmt.Errorf("peer export: %w", err)
		}
		if remote, err = decodeBlock(genesis, item); err != nil {
			return nil, "", fmt.Errorf("peer export: %w", err)
		}
		if !bytes.Equal(remote.set.Hash(), vals.Hash()) {
			return nil, "", errors.New("peer export: its validators are not the genesis committee")
		}
	}
	record, source := local, "local"
	switch {
	case local == nil && remote == nil:
		return nil, "", fmt.Errorf("the block store holds no block at %d: stock CometBFT handshakes from this store; supply --peer-export only to apply a block the committee already decided", height)
	case local == nil:
		record, source = remote, "peer"
	case remote != nil && !remote.id.Equals(local.id):
		return nil, "", contradiction("the peer export's first block %X differs from the stored one %X", remote.id.Hash, local.id.Hash)
	}
	b := record.block
	if b.ChainID != genesis.ChainID || b.Height != height {
		return nil, "", fmt.Errorf("block %s/%d is not the first block of %s/%d", b.ChainID, b.Height, genesis.ChainID, height)
	}
	if err := vals.VerifyCommit(genesis.ChainID, record.id, height, record.commit); err != nil {
		if source == "local" && remote != nil {
			// The stored seen commit is damaged but the peer's certifies the same BlockID.
			if err = vals.VerifyCommit(genesis.ChainID, record.id, height, remote.commit); err == nil {
				return record, source, nil
			}
		}
		return nil, "", fmt.Errorf("the %s commit does not certify the first block under the genesis committee: %w", source, err)
	}
	return record, source, nil
}

// encodeFirstBlock writes a block, its commit and the genesis keys and powers as one
// blocks.jsonl line.
func encodeFirstBlock(block *types.Block, commit *types.Commit, vals *types.ValidatorSet) (Block, error) {
	bp, err := block.ToProto()
	if err != nil {
		return Block{}, err
	}
	bb, err := bp.Marshal()
	if err != nil {
		return Block{}, err
	}
	cb, err := commit.ToProto().Marshal()
	if err != nil {
		return Block{}, err
	}
	item := Block{Block: hexBytes(bb), Commit: hexBytes(cb)}
	for _, v := range vals.Validators {
		item.Validators = append(item.Validators, Validator{Key: hexBytes(v.PubKey.Bytes()), Power: v.VotingPower})
	}
	return item, nil
}

// initChain sends InitChain built from the genesis exactly as the stock handshake does at app
// height 0, and saves the state as stock does while the state holds no block.
func initChain(ctx context.Context, consensus proxy.AppConnConsensus, genesis *types.GenesisDoc, state sm.State, store sm.Store) (sm.State, error) {
	validators := make([]*types.Validator, len(genesis.Validators))
	for i, val := range genesis.Validators {
		validators[i] = types.NewValidator(val.PubKey, val.Power)
	}
	params := genesis.ConsensusParams.ToProto()
	res, err := consensus.InitChain(ctx, &abci.RequestInitChain{
		Time:            genesis.GenesisTime,
		ChainId:         genesis.ChainID,
		InitialHeight:   genesis.InitialHeight,
		ConsensusParams: &params,
		Validators:      types.TM2PB.ValidatorUpdates(types.NewValidatorSet(validators)),
		AppStateBytes:   genesis.AppState,
	})
	if err != nil {
		return state, fmt.Errorf("app InitChain: %w", err)
	}
	if len(res.AppHash) > 0 {
		state.AppHash = res.AppHash
	}
	if len(res.Validators) > 0 {
		vals, err := types.PB2TM.ValidatorUpdates(res.Validators)
		if err != nil {
			return state, err
		}
		state.Validators = types.NewValidatorSet(vals)
		state.NextValidators = types.NewValidatorSet(vals).CopyIncrementProposerPriority(1)
	}
	if res.ConsensusParams != nil {
		state.ConsensusParams = state.ConsensusParams.Update(res.ConsensusParams)
		state.Version.Consensus.App = state.ConsensusParams.Version.App
	}
	state.LastResultsHash = merkle.HashFromByteSlices(nil)
	return state, store.Save(state)
}

// sameAsKept is the app's consensus connection, except that a FinalizeBlock result differing
// from the response the state store kept for the height (the app finalized the block before the
// crash but had not committed it) is refused before stock saves anything: FinalizeBlock must
// return the same result again (CONS-3.1-9).
type sameAsKept struct {
	proxy.AppConnConsensus
	kept *abci.ResponseFinalizeBlock
}

// FinalizeBlock forwards to the app and compares its result with the kept one, if any.
func (c sameAsKept) FinalizeBlock(ctx context.Context, req *abci.RequestFinalizeBlock) (*abci.ResponseFinalizeBlock, error) {
	res, err := c.AppConnConsensus.FinalizeBlock(ctx, req)
	if err != nil || c.kept == nil {
		return res, err
	}
	got, e1 := res.Marshal()
	want, e2 := c.kept.Marshal()
	if e1 != nil || e2 != nil || !bytes.Equal(got, want) {
		return nil, contradiction("the app's FinalizeBlock result for %d differs from the response the state store kept", req.Height)
	}
	return res, nil
}

// keptResponseApp answers FinalizeBlock with the kept response and an empty Commit, as stock's
// mock-app replay does for an app that already committed the block.
func keptResponseApp(kept *abci.ResponseFinalizeBlock) (proxy.AppConnConsensus, error) {
	client, err := proxy.NewLocalClientCreator(&keptResponse{kept: kept}).NewABCIClient()
	if err != nil {
		return nil, err
	}
	if err = client.Start(); err != nil {
		return nil, err
	}
	return proxy.NewAppConnConsensus(client, proxy.NopMetrics()), nil
}

// keptResponse is the local app behind keptResponseApp.
type keptResponse struct {
	abci.BaseApplication
	kept *abci.ResponseFinalizeBlock
}

// FinalizeBlock returns the kept response.
func (k *keptResponse) FinalizeBlock(context.Context, *abci.RequestFinalizeBlock) (*abci.ResponseFinalizeBlock, error) {
	return k.kept, nil
}

// preserve copies the stopped data directory to backup, which must be absent and outside data,
// and syncs the copy. The goleveldb stores are opened read-only meanwhile: their shared locks
// fail while CometBFT holds them, and keep it from starting until the copy is complete.
func preserve(data, backup string) (err error) {
	if backup == "" {
		return errors.New("a backup directory is required")
	}
	absData, err := filepath.Abs(data)
	if err != nil {
		return err
	}
	absBackup, err := filepath.Abs(backup)
	if err != nil {
		return err
	}
	if rel, e := filepath.Rel(absData, absBackup); e == nil && rel != ".." && !strings.HasPrefix(rel, "../") {
		return errors.New("the backup directory must lie outside the data directory")
	}
	if _, e := os.Lstat(backup); !errors.Is(e, os.ErrNotExist) {
		return fmt.Errorf("backup %s must not exist", backup)
	}
	for _, name := range []string{"state", "blockstore"} {
		db, e := dbm.NewGoLevelDBWithOpts(name, data, &opt.Options{ReadOnly: true, ErrorIfMissing: true})
		if e != nil {
			return fmt.Errorf("open %s.db read-only (is CometBFT stopped?): %w", name, e)
		}
		defer func() { err = errors.Join(err, db.Close()) }()
	}
	if err = copyTree(data, backup); err != nil {
		return fmt.Errorf("back up %s: %w", data, err)
	}
	if err = syncStockTree(backup); err != nil {
		return err
	}
	return syncDir(filepath.Dir(absBackup))
}

// copyTree copies a tree of directories and regular files; any other inode is refused.
func copyTree(from, to string) error {
	info, err := os.Lstat(from)
	if err != nil {
		return err
	}
	switch {
	case info.IsDir():
		if err = os.Mkdir(to, info.Mode().Perm()|0o700); err != nil {
			return err
		}
		entries, err := os.ReadDir(from)
		if err != nil {
			return err
		}
		for _, entry := range entries {
			if err = copyTree(filepath.Join(from, entry.Name()), filepath.Join(to, entry.Name())); err != nil {
				return err
			}
		}
		return nil
	case info.Mode().IsRegular():
		source, err := os.Open(from)
		if err != nil {
			return err
		}
		defer source.Close()
		target, err := os.OpenFile(to, os.O_WRONLY|os.O_CREATE|os.O_EXCL|syscall.O_NOFOLLOW, info.Mode().Perm())
		if err != nil {
			return err
		}
		_, copyErr := io.Copy(target, source)
		return errors.Join(copyErr, target.Sync(), target.Close())
	default:
		return fmt.Errorf("unexpected inode %s", from)
	}
}

// writeStoreInstance replaces data/StoreInstanceFile with a fresh 128-bit random ID: written to a
// private temporary file, synced, renamed over the old one and the directory synced. The signer
// then fences through its last signed height until a committed chain covers it (RECOV-8.2-2).
func writeStoreInstance(data string) (string, error) {
	var id [16]byte
	if _, err := rand.Read(id[:]); err != nil {
		return "", err
	}
	value := hex.EncodeToString(id[:])
	temp, err := os.CreateTemp(data, "."+StoreInstanceFile+".*")
	if err != nil {
		return "", err
	}
	name := temp.Name()
	defer os.Remove(name)
	_, writeErr := temp.WriteString(value + "\n")
	if err = errors.Join(writeErr, temp.Chmod(0o600), temp.Sync(), temp.Close()); err != nil {
		return "", err
	}
	if err = os.Rename(name, filepath.Join(data, StoreInstanceFile)); err != nil {
		return "", err
	}
	return value, syncDir(data)
}

// readBounded reads a regular file of at most limit bytes.
func readBounded(path string, limit int64) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	raw, err := io.ReadAll(io.LimitReader(f, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(raw)) > limit {
		return nil, fmt.Errorf("%s exceeds %d bytes", path, limit)
	}
	return raw, nil
}
