package anchortxvalidator

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// AnchorTxValidator is responsible for validating the anchor transaction (TaikoL2.anchor) in
// each L2 block, which is always the first transaction.
type AnchorTxValidator struct {
	taikoL2Address     common.Address
	goldenTouchAddress common.Address
	chainID            *big.Int
	rpc                *rpc.Client
}

// New creates a new AnchorTxValidator instance.
func New(taikoL2Address common.Address, chainID *big.Int, rpc *rpc.Client) (*AnchorTxValidator, error) {
	goldenTouchAddress, err := rpc.TaikoL2.GOLDENTOUCHADDRESS(nil)
	if err != nil {
		return nil, err
	}

	return &AnchorTxValidator{taikoL2Address, goldenTouchAddress, chainID, rpc}, nil
}

// ValidateAnchorTx checks whether the given transaction is a valid `TaikoL2.anchor` transaction.
func (v *AnchorTxValidator) ValidateAnchorTx(tx *types.Transaction) error {
	if tx.To() == nil || *tx.To() != v.taikoL2Address {
		return fmt.Errorf("invalid TaikoL2.anchor transaction to: %s, want: %s", tx.To(), v.taikoL2Address)
	}

	sender, err := types.LatestSignerForChainID(v.chainID).Sender(tx)
	if err != nil {
		return fmt.Errorf("failed to get TaikoL2.anchor transaction sender: %w", err)
	}

	if sender != v.goldenTouchAddress {
		return fmt.Errorf("invalid TaikoL2.anchor transaction sender: %s", sender)
	}

	method, err := encoding.TaikoL2ABI.MethodById(tx.Data())
	if err != nil {
		return fmt.Errorf("failed to get TaikoL2.anchor transaction method: %w", err)
	}
	if method.Name != "anchor" && method.Name != "anchorV2" {
		return fmt.Errorf(
			"invalid TaikoL2.anchor transaction selector, expect: %s, actual: %s",
			"anchor / anchorV2",
			method.Name,
		)
	}

	return nil
}
