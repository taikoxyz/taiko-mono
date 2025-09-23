package state

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// GetL1Current reads the L1 current cursor concurrent safely.
func (s *State) GetL1Current() *types.Header {
	return s.l1Current.Load().(*types.Header)
}

// SetL1Current sets the L1 current cursor concurrent safely.
func (s *State) SetL1Current(h *types.Header) {
	if h == nil {
		log.Warn("Empty l1 current cursor")
		return
	}
	log.Debug("Set L1 current cursor", "number", h.Number)
	s.l1Current.Store(h)
}

// ResetL1Current resets the l1Current cursor to the L1 height which emitted a
// BatchProposed event with given blockID.
func (s *State) ResetL1Current(ctx context.Context, blockID *big.Int) error {
	if blockID == nil {
		return errors.New("empty block ID")
	}

	log.Info("Reset L1 current cursor", "blockID", blockID)

	// If blockID is zero, reset to genesis L1 height.
	if blockID.Cmp(common.Big0) == 0 {
		log.Info("Reset L1 current cursor to genesis L1 height", "blockID", blockID)
		l1Current, err := s.rpc.L1.HeaderByNumber(ctx, s.GenesisL1Height)
		if err != nil {
			return fmt.Errorf("failed to get L1 header at genesis height: %w", err)
		}
		s.SetL1Current(l1Current)
		return nil
	}

	// Fetch the block info from TaikoInbox contract, and set the L1 height.
	batch, err := s.FindBatchForBlockID(ctx, blockID.Uint64())
	if err != nil {
		return fmt.Errorf("failed to find batch for block ID (%d): %w", blockID, err)
	}
	proposedIn := batch.AnchorBlockId

	l1Current, err := s.rpc.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(proposedIn))
	if err != nil {
		return fmt.Errorf("failed to fetch L1 header by number (%d): %w", blockID, err)
	}
	s.SetL1Current(l1Current)

	log.Info("Reset L1 current cursor", "height", s.GetL1Current().Number, "hash", s.GetL1Current().Hash())

	return nil
}

// FindBatchForBlockID finds the TaikoInboxBatch for the given block ID.
func (s *State) FindBatchForBlockID(ctx context.Context, blockID uint64) (*pacayaBindings.ITaikoInboxBatch, error) {
	stateVars, err := s.rpc.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, fmt.Errorf("failed to get protocol state variables: %w", err)
	}

	var (
		lastBatchID = stateVars.Stats2.NumBatches - 1
		lastBatch   *pacayaBindings.ITaikoInboxBatch
	)
	batch, err := s.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(lastBatchID))
	if err != nil {
		return nil, fmt.Errorf("failed to get batch by ID %d: %w", lastBatchID, err)
	}
	lastBatch = batch

	for {
		batch, err := s.rpc.GetBatchByID(ctx, new(big.Int).SetUint64(lastBatchID-1))
		if err != nil {
			return nil, fmt.Errorf("failed to get batch by ID %d: %w", lastBatchID-1, err)
		}

		if batch.LastBlockId < blockID {
			return lastBatch, nil
		}

		lastBatch = batch
		lastBatchID = batch.BatchId
		continue
	}
}
