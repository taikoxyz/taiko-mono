package anchortxvalidator

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// AnchorTxValidator is responsible for validating the anchor transaction (TaikoAnchor.anchorV3) in
// each L2 block, which is always the first transaction.
type AnchorTxValidator struct {
	taikoAnchorAddress common.Address
	goldenTouchAddress common.Address
	chainID            *big.Int
	rpc                *rpc.Client
}

// New creates a new AnchorTxValidator instance.
func New(taikoAnchorAddress common.Address, chainID *big.Int, rpc *rpc.Client) (*AnchorTxValidator, error) {
	goldenTouchAddress, err := rpc.PacayaClients.TaikoAnchor.GOLDENTOUCHADDRESS(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get golden touch address: %w", err)
	}

	return &AnchorTxValidator{taikoAnchorAddress, goldenTouchAddress, chainID, rpc}, nil
}

// ValidateAnchorTx checks whether the given transaction is a valid `TaikoAnchor.anchorV3` transaction.
func (v *AnchorTxValidator) ValidateAnchorTx(tx *types.Transaction) error {
	if tx.To() == nil || *tx.To() != v.taikoAnchorAddress {
		return fmt.Errorf("invalid TaikoAnchor.anchorV3 transaction to: %s, want: %s", tx.To(), v.taikoAnchorAddress)
	}

	sender, err := types.LatestSignerForChainID(v.chainID).Sender(tx)
	if err != nil {
		return fmt.Errorf("failed to get TaikoAnchor.anchorV3 transaction sender: %w", err)
	}

	if sender != v.goldenTouchAddress {
		return fmt.Errorf("invalid TaikoAnchor.anchorV3 transaction sender: %s", sender)
	}

	var method *abi.Method
	if method, err = encoding.TaikoAnchorABI.MethodById(tx.Data()); err != nil {
		return fmt.Errorf("failed to get TaikoAnchor.anchorV3 transaction method: %w", err)
	}
	if method.Name != "anchorV3" {
		return fmt.Errorf(
			"invalid TaikoAnchor.anchorV3 transaction selector, expect: %s, actual: %s",
			"anchorV3",
			method.Name,
		)
	}

	return nil
}
