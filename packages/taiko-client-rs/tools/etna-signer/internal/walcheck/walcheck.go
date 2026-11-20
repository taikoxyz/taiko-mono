// Package walcheck reads a stock CometBFT v0.40.0 consensus WAL the way stock replay does, for the
// RECOV-8.2-2 replay binding of a validator's signer. It runs in the supervisor's helper process,
// never in the serving signer, and it only reads: the stock WAL group is opened without being
// started, and the state and block stores read-only.
package walcheck

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	dbm "github.com/cometbft/cometbft-db"
	cs "github.com/cometbft/cometbft/consensus"
	"github.com/cometbft/cometbft/libs/log"
	sm "github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/store"
	"github.com/syndtr/goleveldb/leveldb/opt"
)

// maxSuffix bounds the bytes read after a marker: stock keeps at most 1 GiB of WAL.
const maxSuffix = 1 << 30

// Binding is a replay binding: the bytes that follow `#ENDHEIGHT Marker` in the WAL, by length
// and SHA-256.
type Binding struct {
	Marker int64  `json:"marker"`
	Length int64  `json:"wal_length"`
	Digest string `json:"wal_sha256"`
}

// suffix returns every byte that follows `#ENDHEIGHT marker`, as stock catchupReplay reads it:
// stock SearchForEndHeight from the newest file backwards, ignoring corrupted entries, and the
// group reader it returns. found is false when stock replay would not find the marker. The group
// is reopened when a concurrent rotation changed it during the read.
func suffix(walFile string, marker int64) (data []byte, found bool, err error) {
	info, err := os.Lstat(walFile)
	if errors.Is(err, os.ErrNotExist) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	if !info.Mode().IsRegular() {
		return nil, false, fmt.Errorf("%s is not a regular WAL file", walFile)
	}
	for range 3 {
		before, err := groupFiles(walFile)
		if err != nil {
			return nil, false, err
		}
		data, found, err = read(walFile, marker)
		if err != nil {
			return nil, false, err
		}
		after, err := groupFiles(walFile)
		if err != nil {
			return nil, false, err
		}
		if before == after {
			return data, found, nil
		}
	}
	return nil, false, errors.New("the WAL group kept rotating during the read")
}

func read(walFile string, marker int64) ([]byte, bool, error) {
	wal, err := cs.NewWAL(walFile)
	if err != nil {
		return nil, false, err
	}
	wal.SetLogger(log.NewNopLogger())
	defer wal.Group().Head.Close()
	reader, found, err := wal.SearchForEndHeight(marker, &cs.WALSearchOptions{IgnoreDataCorruptionErrors: true})
	if err == io.EOF {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	if !found {
		return nil, false, nil
	}
	defer reader.Close()
	data, err := io.ReadAll(io.LimitReader(reader, maxSuffix+1))
	if err != nil {
		return nil, false, err
	}
	if len(data) > maxSuffix {
		return nil, false, errors.New("more than 1 GiB follows the marker")
	}
	return data, true, nil
}

// groupFiles names the group's files with their sizes, to detect a rotation during a read.
func groupFiles(walFile string) (string, error) {
	dir, base := filepath.Dir(walFile), filepath.Base(walFile)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return "", err
	}
	var listing strings.Builder
	for _, entry := range entries {
		if entry.Name() != base && !strings.HasPrefix(entry.Name(), base+".") {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			return "", err
		}
		fmt.Fprintf(&listing, "%s:%d;", entry.Name(), info.Size())
	}
	return listing.String(), nil
}

func digest(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

// Live is the binding of a signature Comet requested just now: Comet flushes and syncs its WAL
// before it asks for a vote or a proposal and writes nothing more while it waits, so every byte
// after the marker is flushed input, through the record that triggered the request and the
// round-state records written while handling it. nil when the marker is absent: same-height
// replay is then unavailable.
func Live(walFile string, marker int64) (*Binding, error) {
	data, found, err := suffix(walFile, marker)
	if err != nil || !found {
		return nil, err
	}
	return &Binding{Marker: marker, Length: int64(len(data)), Digest: digest(data)}, nil
}

// Preflight is the startup check of a saved binding against a stopped node's stores.
type Preflight struct {
	// Eligible is true only when stock v0.40.0 can replay Height from the verified predecessor
	// through the whole bound prefix: the stores hold exactly the predecessor, the WAL holds
	// `#ENDHEIGHT Marker` and no `#ENDHEIGHT Height`, and the bytes after the marker begin with
	// the bound prefix and decode completely.
	Eligible bool   `json:"eligible"`
	Reason   string `json:"reason"`
	// Repair is true when the bound prefix is intact and only bytes after it fail to decode, a
	// torn tail that stock repairs at startup: this start cannot replay, and the next one may.
	Repair bool `json:"repair"`
	// Startup is the pinned startup prefix: the contiguous, decodable bytes from the marker
	// through the last complete record.
	Startup *Binding `json:"startup"`
}

// Check verifies the saved binding of the last signature at height (round-state records
// included) against the WAL and the stopped node's stores at dbDir (goleveldb only): the
// committed state must be the predecessor of height and, after the generation's first block, its
// block must hash to predecessor.
func Check(walFile, dbDir string, height int64, saved Binding, predecessor []byte) (Preflight, error) {
	refuse := func(format string, args ...any) (Preflight, error) {
		return Preflight{Reason: fmt.Sprintf(format, args...)}, nil
	}
	state, blockHash, err := predecessorOf(dbDir, saved.Marker)
	if err != nil {
		return refuse("stores: %v", err)
	}
	switch {
	case saved.Marker == 0 && (state.LastBlockHeight != 0 || height != state.InitialHeight):
		return refuse("the stores are at height %d, not before the generation's initial height %d = %d", state.LastBlockHeight, state.InitialHeight, height)
	case saved.Marker != 0 && (saved.Marker != height-1 || state.LastBlockHeight != saved.Marker):
		return refuse("the stores are at height %d, not at the predecessor %d of %d", state.LastBlockHeight, saved.Marker, height)
	case !bytes.Equal(blockHash, predecessor):
		return refuse("the stores' block at %d is %X, not the bound predecessor %X", saved.Marker, blockHash, predecessor)
	}
	if _, decided, err := suffix(walFile, height); err != nil || decided {
		return refuse("the WAL holds #ENDHEIGHT %d (%v): stock replay refuses it", height, err)
	}
	data, found, err := suffix(walFile, saved.Marker)
	if err != nil {
		return refuse("WAL: %v", err)
	}
	if !found {
		return refuse("the WAL has no #ENDHEIGHT %d", saved.Marker)
	}
	if int64(len(data)) < saved.Length || digest(data[:saved.Length]) != saved.Digest {
		return refuse("the %d bytes after #ENDHEIGHT %d are not the bound prefix", saved.Length, saved.Marker)
	}
	end, err := decodable(data)
	if end < saved.Length {
		return refuse("the bound prefix does not decode completely: %v", err)
	}
	startup := &Binding{Marker: saved.Marker, Length: end, Digest: digest(data[:end])}
	if end < int64(len(data)) {
		return Preflight{Repair: true, Startup: startup, Reason: fmt.Sprintf("%d bytes after the last complete record do not decode (%v): stock repairs them first", int64(len(data))-end, err)}, nil
	}
	return Preflight{Eligible: true, Startup: startup}, nil
}

// decodable is the length of the longest prefix of data that the stock decoder reads as complete
// records, and the error that stopped it.
func decodable(data []byte) (int64, error) {
	reader := bytes.NewReader(data)
	decoder := cs.NewWALDecoder(reader)
	var end int64
	for {
		_, err := decoder.Decode()
		if err == io.EOF {
			return end, nil
		}
		if err != nil {
			return end, err
		}
		end = int64(len(data)) - int64(reader.Len())
	}
}

// predecessorOf reads, read-only, the committed state and the hash of the block at marker (none
// for marker 0) from a stopped node's goleveldb stores.
func predecessorOf(dbDir string, marker int64) (sm.State, []byte, error) {
	options := &opt.Options{ReadOnly: true, ErrorIfMissing: true}
	stateDB, err := dbm.NewGoLevelDBWithOpts("state", dbDir, options)
	if err != nil {
		return sm.State{}, nil, err
	}
	defer stateDB.Close()
	state, err := sm.NewStore(stateDB, sm.StoreOptions{}).Load()
	if err != nil {
		return sm.State{}, nil, err
	}
	if marker == 0 {
		return state, nil, nil
	}
	blockDB, err := dbm.NewGoLevelDBWithOpts("blockstore", dbDir, options)
	if err != nil {
		return sm.State{}, nil, err
	}
	defer blockDB.Close()
	meta := store.NewBlockStore(blockDB).LoadBlockMeta(marker)
	if meta == nil {
		return sm.State{}, nil, fmt.Errorf("no block at %d", marker)
	}
	return state, meta.BlockID.Hash, nil
}

// Head is the committed height of a stopped node's goleveldb stores and its block's hash (none
// at height 0).
func Head(dbDir string) (int64, []byte, error) {
	state, _, err := predecessorOf(dbDir, 0)
	if err != nil {
		return 0, nil, err
	}
	if state.LastBlockHeight == 0 {
		return 0, nil, nil
	}
	_, hash, err := predecessorOf(dbDir, state.LastBlockHeight)
	return state.LastBlockHeight, hash, err
}
