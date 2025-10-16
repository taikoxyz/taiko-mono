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

// AnchorTxValidator is responsible for validating the anchor transaction in
// each L2 block, which is always the first transaction.
type AnchorTxValidator struct {
	pacayaAnchorAddress common.Address
	shastaAnchorAddress common.Address
	goldenTouchAddress  common.Address
	chainID             *big.Int
	rpc                 *rpc.Client
}

// New creates a new AnchorTxValidator instance.
func New(pacayaAnchor, shastaAnchor common.Address, chainID *big.Int, rpc *rpc.Client) (*AnchorTxValidator, error) {
	var (
		goldenTouchAddress common.Address
		err                error
	)

	if rpc.ShastaClients != nil && rpc.ShastaClients.Anchor != nil {
		if goldenTouchAddress, err = rpc.ShastaClients.Anchor.GOLDENTOUCHADDRESS(nil); err == nil {
			return &AnchorTxValidator{
				pacayaAnchorAddress: pacayaAnchor,
				shastaAnchorAddress: shastaAnchor,
				goldenTouchAddress:  goldenTouchAddress,
				chainID:             chainID,
				rpc:                 rpc,
			}, nil
		}
	}

	if goldenTouchAddress, err = rpc.PacayaClients.TaikoAnchor.GOLDENTOUCHADDRESS(nil); err != nil {
		return nil, fmt.Errorf("failed to get golden touch address: %w", err)
	}

	return &AnchorTxValidator{
		pacayaAnchorAddress: pacayaAnchor,
		shastaAnchorAddress: shastaAnchor,
		goldenTouchAddress:  goldenTouchAddress,
		chainID:             chainID,
		rpc:                 rpc,
	}, nil
}

// ValidateAnchorTx checks whether the given transaction is a valid `TaikoAnchor.anchorV3` transaction.
func (v *AnchorTxValidator) ValidateAnchorTx(tx *types.Transaction) error {
	if tx.To() == nil {
		return fmt.Errorf("invalid anchor transaction recipient: <nil>")
	}

	to := *tx.To()
	if to != v.pacayaAnchorAddress && to != v.shastaAnchorAddress {
		return fmt.Errorf(
			"invalid anchor transaction recipient: %s (expected %s or %s)",
			to,
			v.pacayaAnchorAddress,
			v.shastaAnchorAddress,
		)
	}

	sender, err := types.LatestSignerForChainID(v.chainID).Sender(tx)
	if err != nil {
		return fmt.Errorf("failed to get anchor transaction sender: %w", err)
	}

	if sender != v.goldenTouchAddress {
		return fmt.Errorf("invalid anchor transaction sender: %s", sender)
	}

	var method *abi.Method
	if method, err = encoding.ShastaAnchorABI.MethodById(tx.Data()); err != nil {
		if method, err = encoding.TaikoAnchorABI.MethodById(tx.Data()); err != nil {
			return fmt.Errorf("failed to get anchor transaction method: %w", err)
		}
	}

	switch method.Name {
	case "anchor", "anchorV2", "anchorV3":
	default:
		return fmt.Errorf("invalid anchor transaction method: %s", method.Name)
	}

	return nil
}
