package state

import (
	"context"
	"errors"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
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
// BlockProposed event with given blockID / blockHash.
func (s *State) ResetL1Current(ctx context.Context, blockID *big.Int) error {
	if blockID == nil {
		return errors.New("empty block ID")
	}

	log.Info("Reset L1 current cursor", "blockID", blockID)

	// If blockID is zero, reset to genesis L1 height.
	if blockID.Cmp(common.Big0) == 0 {
		l1Current, err := s.rpc.L1.HeaderByNumber(ctx, s.GenesisL1Height)
		if err != nil {
			return err
		}
		s.SetL1Current(l1Current)
		return nil
	}

	// Fetch the block info from TaikoL1 contract, and set the L1 height.
	var (
		blockInfo bindings.TaikoDataBlockV2
		err       error
	)
	if s.IsOnTake(blockID) {
		blockInfo, err = s.rpc.GetL2BlockInfoV2(ctx, blockID)
	} else {
		blockInfo, err = s.rpc.GetL2BlockInfo(ctx, blockID)
	}
	if err != nil {
		return err
	}
	l1Current, err := s.rpc.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(blockInfo.ProposedIn))
	if err != nil {
		return err
	}
	s.SetL1Current(l1Current)

	log.Info("Reset L1 current cursor", "height", s.GetL1Current().Number, "hash", s.GetL1Current().Hash())

	return nil
}
