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

// VerifyExportState reads the full stock state from an independent node's stopped or
// snapshotted goleveldb state store. Load returns the exact committed state. Historical
// LoadValidators may reconstruct priorities with different rescaling (DATA-5.4-8).
func VerifyExportState(dataDir string, preimage []byte, identity ExportIdentity) error {
	height, current, next, err := DecodeValState(preimage)
	if err != nil {
		return err
	}
	if height != identity.Height {
		return errors.New("validator-state preimage has the wrong height")
	}
	db, err := dbm.NewGoLevelDBWithOpts("state", dataDir, &opt.Options{ReadOnly: true, ErrorIfMissing: true})
	if err != nil {
		return fmt.Errorf("open stock state snapshot: %w", err)
	}
	defer db.Close()
	stock, err := sm.NewStore(db, sm.StoreOptions{}).Load()
	if err != nil {
		return fmt.Errorf("read stock state snapshot: %w", err)
	}
	return verifyExportState(stock, identity, current, next)
}

func verifyExportState(stock sm.State, identity ExportIdentity, current, next *types.ValidatorSet) error {
	height := identity.Height
	if height == identity.InitialHeight-1 {
		// Stock represents the state after InitChain with a zero LastBlockHeight even
		// when the first consensus height is greater than one.
		height = 0
	}
	if stock.IsEmpty() || stock.ChainID != identity.ChainID ||
		stock.InitialHeight != identity.InitialHeight || stock.LastBlockHeight != height ||
		!bytes.Equal(stock.LastBlockID.Hash, identity.LastBlockHash) ||
		!bytes.Equal(stock.AppHash, identity.AppHash) {
		return errors.New("stock state snapshot must identify the authenticated predecessor")
	}
	if !sameExportSet(stock.Validators, current) || !sameExportSet(stock.NextValidators, next) {
		return ErrExportValStateMismatch
	}
	return nil
}

func sameExportSet(a, b *types.ValidatorSet) bool {
	if a == nil || b == nil || a.Proposer == nil || b.Proposer == nil ||
		len(a.Validators) != len(b.Validators) || !bytes.Equal(a.Proposer.Address, b.Proposer.Address) {
		return false
	}
	for i, av := range a.Validators {
		bv := b.Validators[i]
		if !av.PubKey.Equals(bv.PubKey) || av.VotingPower != bv.VotingPower ||
			av.ProposerPriority != bv.ProposerPriority {
			return false
		}
	}
	return true
}
