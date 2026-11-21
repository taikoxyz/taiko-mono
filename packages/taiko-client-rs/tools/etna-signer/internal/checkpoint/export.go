package checkpoint

import (
	"bytes"
	"errors"
	"fmt"

	dbm "github.com/cometbft/cometbft-db"
	sm "github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/types"
	"github.com/syndtr/goleveldb/leveldb/opt"
)

// ErrExportValStateMismatch means a stock state for the exact checkpoint predecessor
// disagrees with the app's authenticated validator state. The producer must alert.
var ErrExportValStateMismatch = errors.New("validator-state preimage disagrees with stock CometBFT")

// ExportIdentity binds a stock snapshot to the authenticated header at s.
type ExportIdentity struct {
	ChainID       string
	Height        int64
	InitialHeight int64
	LastBlockHash []byte
	AppHash       []byte
}

// VerifyExportState reads, read-only, the stock State an independent node's stopped or
// snapshotted goleveldb state store holds: Store.Load(), the state immediately after its height,
// which at the origin is the state after InitChain. It must be labelled with identity's height,
// chain and predecessor, and its Validators and NextValidators, stored proposers included, must
// equal the preimage's (DATA-5.4-8). A later state, a historical LoadValidators, /validators or an
// app's copy cannot stand in: LoadValidators may rebuild priorities with different rescaling
// (SYNC-9-5c).
func VerifyExportState(dataDir string, preimage []byte, identity ExportIdentity) error {
	height, current, next, err := DecodeValState(preimage)
	if err != nil {
		return err
	}
	if height != identity.Height {
		return errors.New("validator-state preimage has the wrong height")
	}
	stock, err := loadStockState(dataDir)
	if err != nil {
		return err
	}
	return verifyExportState(stock, identity, current, next)
}

// SnapshotReport is what snapshot-height prints for a stopped stock state snapshot.
type SnapshotReport struct {
	ChainID string `json:"chain_id"`
	// LastBlockHeight is the height x whose committed state the snapshot holds, so it serves
	// the export of checkpoint s = x + 1.
	LastBlockHeight int64 `json:"last_block_height"`
}

// SnapshotHeight reads, read-only, the height of the committed state that a stopped or
// snapshotted stock state store holds. Stock CometBFT cannot stop at a chosen height, so the
// producer reads the height of the snapshot it took and lands exactly the checkpoint after it
// (DATA-5.4-8).
func SnapshotHeight(dataDir string) (SnapshotReport, error) {
	stock, err := loadStockState(dataDir)
	if err != nil {
		return SnapshotReport{}, err
	}
	height, err := committedHeight(stock)
	if err != nil {
		return SnapshotReport{}, err
	}
	return SnapshotReport{ChainID: stock.ChainID, LastBlockHeight: height}, nil
}

// loadStockState opens the goleveldb state store in dataDir read-only and loads the
// exact committed state.
func loadStockState(dataDir string) (sm.State, error) {
	db, err := dbm.NewGoLevelDBWithOpts("state", dataDir, &opt.Options{ReadOnly: true, ErrorIfMissing: true})
	if err != nil {
		return sm.State{}, fmt.Errorf("open stock state snapshot: %w", err)
	}
	defer db.Close()
	stock, err := sm.NewStore(db, sm.StoreOptions{}).Load()
	if err != nil {
		return sm.State{}, fmt.Errorf("read stock state snapshot: %w", err)
	}
	return stock, nil
}

// committedHeight is the height whose committed state stock holds. Stock represents the state
// after InitChain with a zero LastBlockHeight even when the first consensus height is greater
// than one; that state is the one at InitialHeight - 1.
func committedHeight(stock sm.State) (int64, error) {
	switch {
	case stock.IsEmpty():
		return 0, errors.New("stock state snapshot holds no state")
	case stock.LastBlockHeight == 0:
		return stock.InitialHeight - 1, nil
	case stock.LastBlockHeight < stock.InitialHeight:
		return 0, fmt.Errorf("stock state snapshot height %d precedes its initial height %d",
			stock.LastBlockHeight, stock.InitialHeight)
	}
	return stock.LastBlockHeight, nil
}

func verifyExportState(stock sm.State, identity ExportIdentity, current, next *types.ValidatorSet) error {
	if stock.IsEmpty() || stock.ChainID != identity.ChainID ||
		stock.InitialHeight != identity.InitialHeight {
		return errors.New("stock state snapshot must be of the authenticated chain")
	}
	height, err := committedHeight(stock)
	if err != nil {
		return err
	}
	if height != identity.Height {
		return fmt.Errorf("stock state snapshot is at height %d, but checkpoint %d needs it at height %d",
			height, identity.Height+1, identity.Height)
	}
	if !bytes.Equal(stock.LastBlockID.Hash, identity.LastBlockHash) ||
		!bytes.Equal(stock.AppHash, identity.AppHash) {
		return errors.New("stock state snapshot must identify the authenticated predecessor")
	}
	if !sameExportSet(stock.Validators, current) || !sameExportSet(stock.NextValidators, next) {
		return ErrExportValStateMismatch
	}
	return nil
}

// sameExportSet compares one set of the stock State with the preimage's: every member's key,
// power and priority in canonical order, and the stored proposer with its key, power and
// priority (DATA-5.4-8).
func sameExportSet(a, b *types.ValidatorSet) bool {
	if a == nil || b == nil || a.Proposer == nil || b.Proposer == nil ||
		len(a.Validators) != len(b.Validators) || !sameValidator(a.Proposer, b.Proposer) {
		return false
	}
	for i, av := range a.Validators {
		if !sameValidator(av, b.Validators[i]) {
			return false
		}
	}
	return true
}

func sameValidator(a, b *types.Validator) bool {
	return bytes.Equal(a.Address, b.Address) && a.PubKey.Equals(b.PubKey) &&
		a.VotingPower == b.VotingPower && a.ProposerPriority == b.ProposerPriority
}
