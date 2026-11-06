package checkpoint

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	"github.com/cometbft/cometbft/evidence"
	statepb "github.com/cometbft/cometbft/proto/tendermint/state"
	sm "github.com/cometbft/cometbft/state"
	bs "github.com/cometbft/cometbft/store"
	"github.com/cometbft/cometbft/types"
	gogotypes "github.com/cosmos/gogoproto/types"
	"github.com/syndtr/goleveldb/leveldb/opt"
)

// EvidenceExpired uses the post-s state exactly as stock evidence verification at s+1 does.
func EvidenceExpired(postHeight int64, postTime time.Time, evidenceHeight int64, evidenceTime time.Time) bool {
	return evidence.IsEvidenceExpired(postHeight, postTime, evidenceHeight, evidenceTime, types.EvidenceParams{MaxAgeNumBlocks: 100000, MaxAgeDuration: 48 * time.Hour})
}

func checkParents(path string) error {
	if !filepath.IsAbs(path) || filepath.Clean(path) != path {
		return errors.New("home must be absolute and clean")
	}
	for p := filepath.Dir(path); ; p = filepath.Dir(p) {
		info, err := os.Lstat(p)
		if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
			return errors.New("missing or aliased parent")
		}
		if p == filepath.Dir(p) {
			break
		}
	}
	return nil
}
func syncDir(path string) error {
	f, e := os.Open(path)
	if e != nil {
		return e
	}
	defer f.Close()
	return f.Sync()
}

// Install creates only a previously nonexistent home; signer keys and WAL are never read.
// The controller must stage all other stores and publish its own completion manifest.
func Install(home string, v *Verified) (err error) {
	if v == nil {
		return errors.New("missing verified package")
	}
	if err = checkParents(home); err != nil {
		return err
	}
	if err = os.Mkdir(home, 0700); err != nil {
		return err
	}
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("stock store installation failed: %v", r)
		}
	}()
	if err = os.Mkdir(filepath.Join(home, "config"), 0700); err != nil {
		return err
	}
	if err = os.Mkdir(filepath.Join(home, "data"), 0700); err != nil {
		return err
	}
	f, err := os.OpenFile(filepath.Join(home, "config", "genesis.json"), os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return err
	}
	_, writeErr := f.Write(v.genesisRaw)
	syncErr := f.Sync()
	closeErr := f.Close()
	if writeErr != nil {
		return writeErr
	}
	if syncErr != nil {
		return syncErr
	}
	if closeErr != nil {
		return closeErr
	}
	data := filepath.Join(home, "data")
	stateDB, err := dbm.NewGoLevelDB("state", data)
	if err != nil {
		return err
	}
	defer stateDB.Close()
	blockDB, err := dbm.NewGoLevelDB("blockstore", data)
	if err != nil {
		return err
	}
	defer blockDB.Close()
	evidenceDB, err := dbm.NewGoLevelDB("evidence", data)
	if err != nil {
		return err
	}
	defer evidenceDB.Close()
	store := sm.NewStore(stateDB, sm.StoreOptions{})
	blocks := bs.NewBlockStore(blockDB)
	// The public Bootstrap API has no historical-record-only operation. Use the
	// pinned public protobuf records and stock key formats, with bounded metadata pointers.
	// Reopening through LoadValidatorsFast/LoadConsensusParams checks compatibility.
	initial, err := sm.MakeGenesisState(v.genesis)
	if err != nil {
		return err
	}
	initial.Version.Consensus.App = 1
	temporary := sm.NewStore(dbm.NewMemDB(), sm.StoreOptions{})
	if err = temporary.Bootstrap(initial); err != nil {
		return err
	}
	pool, err := evidence.NewPool(evidenceDB, temporary, blocks)
	if err != nil {
		return err
	}
	var lastEvidence types.Evidence
	var previousHash []byte
	var changed int64
	err = v.walk(func(record *blockRecord) error {
		b := record.block
		parts, e := b.MakePartSet(types.BlockPartSizeBytes)
		if e != nil {
			return e
		}
		blocks.SaveBlock(b, parts, record.commit)
		// Without a successor, stock has only SC:s. Its evidence signed-header lookup
		// requires C:s; install the same verified terminal commit under that stock key.
		if b.Height == v.state.LastBlockHeight {
			raw, e := record.commit.ToProto().Marshal()
			if e != nil {
				return e
			}
			if e = blockDB.SetSync([]byte(fmt.Sprintf("C:%d", b.Height)), raw); e != nil {
				return e
			}
		}
		batch := stateDB.NewBatch()
		defer batch.Close()
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
		cp := statepb.ConsensusParamsInfo{LastHeightChanged: v.report.FirstHeight}
		if b.Height == v.report.FirstHeight {
			cp.ConsensusParams = v.state.ConsensusParams.ToProto()
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
		// Public Update marks authenticated evidence without historical verification.
		post := v.state.Copy()
		post.LastBlockHeight = b.Height
		post.LastBlockTime = b.Time
		pool.Update(post, b.Evidence.Evidence)
		if len(b.Evidence.Evidence) > 0 {
			lastEvidence = b.Evidence.Evidence[len(b.Evidence.Evidence)-1]
		}
		return nil
	})
	if err != nil {
		return err
	}
	if lastEvidence != nil {
		key, raw, e := evidenceMarker(lastEvidence)
		if e != nil {
			return e
		}
		if e = evidenceDB.SetSync(key, raw); e != nil {
			return e
		}
	}
	if err = store.Bootstrap(v.state); err != nil {
		return err
	}
	if err = store.SetOfflineStateSyncHeight(v.state.LastBlockHeight); err != nil {
		return err
	}
	if err = stateDB.Close(); err != nil {
		return err
	}
	if err = blockDB.Close(); err != nil {
		return err
	}
	if err = evidenceDB.Close(); err != nil {
		return err
	}
	if err = verifyReopened(data, v); err != nil {
		return err
	}
	for _, path := range []string{filepath.Join(data, "state.db"), filepath.Join(data, "blockstore.db"), filepath.Join(data, "evidence.db"), data, filepath.Join(home, "config"), home, filepath.Dir(home)} {
		if err = syncDir(path); err != nil {
			return err
		}
	}
	return nil
}
func openReadOnly(home, name string) (*dbm.GoLevelDB, error) {
	path := filepath.Join(home, "data", name+".db")
	if err := checkParents(filepath.Join(path, "child")); err != nil {
		return nil, err
	}
	err := filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && !info.Mode().IsRegular() {
			return errors.New("aliased database entry")
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	info, err := os.Lstat(filepath.Join(path, "LOCK"))
	if err != nil || !info.Mode().IsRegular() {
		return nil, errors.New("missing database lock inode")
	}
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
func verifyReopened(data string, v *Verified) error {
	home := filepath.Dir(data)
	sd, e := openReadOnly(home, "state")
	if e != nil {
		return e
	}
	defer sd.Close()
	bd, e := openReadOnly(home, "blockstore")
	if e != nil {
		return e
	}
	defer bd.Close()
	ed, e := openReadOnly(home, "evidence")
	if e != nil {
		return e
	}
	defer ed.Close()
	store := sm.NewStore(sd, sm.StoreOptions{})
	loadValidators, e := historicalValidatorLookup(store)
	if e != nil {
		return e
	}
	s, e := store.Load()
	if e != nil {
		return e
	}
	if !bytes.Equal(s.Bytes(), v.state.Bytes()) {
		return errors.New("reopened stock state mismatch")
	}
	blocks := bs.NewBlockStore(bd)
	if e = v.walk(func(record *blockRecord) error {
		b := record.block
		read := blocks.LoadBlock(b.Height)
		if read == nil || !bytes.Equal(read.Hash(), b.Hash()) {
			return errors.New("reopened block mismatch")
		}
		storedCommit := blocks.LoadBlockCommit(b.Height)
		if storedCommit == nil {
			return errors.New("missing reopened actual block commit")
		}
		if e = record.set.VerifyCommit(v.genesis.ChainID, record.id, b.Height, storedCommit); e != nil {
			return fmt.Errorf("invalid reopened C:%d: %w", b.Height, e)
		}
		storedBytes, e := storedCommit.ToProto().Marshal()
		if e != nil {
			return e
		}
		expectedBytes, e := record.commit.ToProto().Marshal()
		if e != nil {
			return e
		}
		if !bytes.Equal(storedBytes, expectedBytes) {
			return errors.New("reopened actual commit representation mismatch")
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
	c := blocks.LoadSeenCommit(s.LastBlockHeight)
	if c == nil || !c.BlockID.Equals(s.LastBlockID) {
		return errors.New("missing reopened terminal seen commit")
	}
	return nil
}

// Export reads an offline stock home without writing or creating lock files.
// Explicit bounds and terminal preimage are required; the caller authenticates the result.
func Export(home string, first, last int64, preimage []byte) (*Package, error) {
	var p *Package
	err := exportSource(home, first, last, preimage, func(meta *Package) error { p = meta; return nil }, func(item Block) error { p.Blocks = append(p.Blocks, item); return nil }, MaxPackageBytes)
	return p, err
}

// ExportTo streams the requested complete window from read-only stock stores.
// It never reads a block before first or after last, nor an external signer store.
func ExportTo(w io.Writer, home string, first, last int64, preimage []byte) error {
	firstItem := true
	err := exportSource(home, first, last, preimage, func(p *Package) error {
		prefix, e := json.Marshal(struct {
			Schema  uint32          `json:"schema"`
			Genesis json.RawMessage `json:"genesis"`
		}{p.Schema, p.Genesis})
		if e != nil {
			return e
		}
		if _, e = w.Write(prefix[:len(prefix)-1]); e != nil {
			return e
		}
		_, e = io.WriteString(w, `,"blocks":[`)
		return e
	}, func(item Block) error {
		raw, e := json.Marshal(item)
		if e != nil {
			return e
		}
		if !firstItem {
			if _, e = io.WriteString(w, ","); e != nil {
				return e
			}
		}
		firstItem = false
		_, e = w.Write(raw)
		return e
	}, MaxStreamPackageBytes)
	if err != nil {
		return err
	}
	suffix, err := json.Marshal(hexBytes(preimage))
	if err != nil {
		return err
	}
	if _, err = io.WriteString(w, `],"validator_state":`); err != nil {
		return err
	}
	if _, err = w.Write(suffix); err != nil {
		return err
	}
	_, err = io.WriteString(w, "}\n")
	return err
}
func exportSource(home string, first, last int64, preimage []byte, init func(*Package) error, visit func(Block) error, limit int64) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("corrupt stock export source: %v", r)
		}
	}()
	if first < 1 || last < first || last > int64(^uint64(0)>>1)-2 {
		return errors.New("invalid export range")
	}
	if height, _, _, e := DecodeValState(preimage); e != nil || height != last {
		return errors.New("terminal export preimage height mismatch")
	}
	if err = checkParents(filepath.Join(home, "child")); err != nil {
		return err
	}
	genesisPath := filepath.Join(home, "config", "genesis.json")
	if err = checkParents(genesisPath); err != nil {
		return err
	}
	info, err := os.Lstat(genesisPath)
	if err != nil || !info.Mode().IsRegular() {
		return errors.New("missing or aliased original genesis")
	}
	if info.Size() > maxMetadataJSON {
		return errors.New("oversized original genesis")
	}
	raw, err := os.ReadFile(genesisPath)
	if err != nil {
		return err
	}
	sd, err := openReadOnly(home, "state")
	if err != nil {
		return err
	}
	defer sd.Close()
	bd, err := openReadOnly(home, "blockstore")
	if err != nil {
		return err
	}
	defer bd.Close()
	store := sm.NewStore(sd, sm.StoreOptions{})
	loadValidators, e := historicalValidatorLookup(store)
	if e != nil {
		return e
	}
	blocks := bs.NewBlockStore(bd)
	p := &Package{Schema: 1, Genesis: raw, ValidatorState: hexBytes(preimage), Blocks: []Block{}}
	if err = init(p); err != nil {
		return err
	}
	var size int64
	for h := first; h <= last; h++ {
		b := blocks.LoadBlock(h)
		if b == nil {
			return fmt.Errorf("missing window block %d", h)
		}
		var c *types.Commit
		if h < blocks.Height() {
			c = blocks.LoadBlockCommit(h)
		}
		if c == nil {
			c = blocks.LoadSeenCommit(h)
		}
		if c == nil {
			return fmt.Errorf("missing commit %d", h)
		}
		vals, e := loadValidators(h)
		if e != nil {
			return e
		}
		pb, e := b.ToProto()
		if e != nil {
			return e
		}
		bb, e := pb.Marshal()
		if e != nil {
			return e
		}
		cb, e := c.ToProto().Marshal()
		if e != nil {
			return e
		}
		size += int64(2 * (len(bb) + len(cb)))
		if size > limit {
			return errors.New("export exceeds package resource profile")
		}
		item := Block{Block: hexBytes(bb), Commit: hexBytes(cb), Validators: []Validator{}}
		for _, v := range vals.Validators {
			item.Validators = append(item.Validators, Validator{Key: hexBytes(v.PubKey.Bytes()), Power: v.VotingPower})
		}
		if err = visit(item); err != nil {
			return err
		}
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
