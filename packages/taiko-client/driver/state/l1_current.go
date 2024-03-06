package state

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
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
func (s *State) ResetL1Current(
	ctx context.Context,
	blockID *big.Int,
) error {
	if blockID == nil {
		return fmt.Errorf("empty block ID")
	}

	log.Info("Reset L1 current cursor", "blockID", blockID)

	if blockID.Cmp(common.Big0) == 0 {
		l1Current, err := s.rpc.L1.HeaderByNumber(ctx, s.GenesisL1Height)
		if err != nil {
			return err
		}
		s.SetL1Current(l1Current)
		return nil
	}

	blockInfo, err := s.rpc.TaikoL1.GetBlock(&bind.CallOpts{Context: ctx}, blockID.Uint64())
	if err != nil {
		return err
	}

	l1Current, err := s.rpc.L1.HeaderByNumber(ctx, new(big.Int).SetUint64(blockInfo.Blk.ProposedIn))
	if err != nil {
		return err
	}
	s.SetL1Current(l1Current)

	log.Info("Reset L1 current cursor", "height", s.GetL1Current().Number, "hash", s.GetL1Current().Hash())

	return nil
}
