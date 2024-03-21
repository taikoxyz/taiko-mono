package anchortxconstructor

import (
	"context"
	"fmt"
	"math/big"

	"github.com/decred/dcrd/dcrec/secp256k1/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/driver/signer"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

// Each TaikoL2.anchor transaction should use this value as it's gas limit.
const AnchorGasLimit = 250_000

// AnchorTxConstructor is responsible for assembling the anchor transaction (TaikoL2.anchor) in
// each L2 block, which must be the first transaction, and its sender must be the golden touch account.
type AnchorTxConstructor struct {
	rpc                *rpc.Client
	goldenTouchAddress common.Address
	signer             *signer.FixedKSigner
}

// New creates a new AnchorConstructor instance.
func New(rpc *rpc.Client) (*AnchorTxConstructor, error) {
	goldenTouchAddress, err := rpc.TaikoL2.GOLDENTOUCHADDRESS(nil)
	if err != nil {
		return nil, err
	}

	signer, err := signer.NewFixedKSigner("0x" + encoding.GoldenTouchPrivKey)
	if err != nil {
		return nil, fmt.Errorf("invalid golden touch private key %s", encoding.GoldenTouchPrivKey)
	}

	return &AnchorTxConstructor{rpc, goldenTouchAddress, signer}, nil
}

// AssembleAnchorTx assembles a signed TaikoL2.anchor transaction.
func (c *AnchorTxConstructor) AssembleAnchorTx(
	ctx context.Context,
	// Parameters of the TaikoL2.anchor transaction.
	l1Height *big.Int,
	l1Hash common.Hash,
	// Height of the L2 block which including the TaikoL2.anchor transaction.
	l2Height *big.Int,
	baseFee *big.Int,
	parentGasUsed uint64,
) (*types.Transaction, error) {
	opts, err := c.transactOpts(ctx, l2Height, baseFee)
	if err != nil {
		return nil, err
	}

	l1Header, err := c.rpc.L1.HeaderByHash(ctx, l1Hash)
	if err != nil {
		return nil, err
	}

	log.Info(
		"Anchor arguments",
		"l2Height", l2Height,
		"l1Height", l1Height,
		"l1Hash", l1Hash,
		"stateRoot", l1Header.Root,
		"baseFee", baseFee,
		"gasUsed", parentGasUsed,
	)

	return c.rpc.TaikoL2.Anchor(opts, l1Hash, l1Header.Root, l1Height.Uint64(), uint32(parentGasUsed))
}

// transactOpts is a utility method to create some transact options of the anchor transaction in given L2 block with
// golden touch account's private key.
func (c *AnchorTxConstructor) transactOpts(
	ctx context.Context,
	l2Height *big.Int,
	baseFee *big.Int,
) (*bind.TransactOpts, error) {
	var (
		signer       = types.LatestSignerForChainID(c.rpc.L2.ChainID)
		parentHeight = new(big.Int).Sub(l2Height, common.Big1)
	)

	// Get the nonce of golden touch account at the specified parentHeight.
	nonce, err := c.rpc.L2AccountNonce(ctx, c.goldenTouchAddress, parentHeight)
	if err != nil {
		return nil, err
	}

	log.Info(
		"Golden touch account nonce",
		"address", c.goldenTouchAddress,
		"nonce", nonce,
		"parent", parentHeight,
	)

	return &bind.TransactOpts{
		From: c.goldenTouchAddress,
		Signer: func(address common.Address, tx *types.Transaction) (*types.Transaction, error) {
			if address != c.goldenTouchAddress {
				return nil, bind.ErrNotAuthorized
			}
			signature, err := c.signTxPayload(signer.Hash(tx).Bytes())
			if err != nil {
				return nil, err
			}
			return tx.WithSignature(signer, signature)
		},
		Nonce:     new(big.Int).SetUint64(nonce),
		Context:   ctx,
		GasFeeCap: baseFee,
		GasTipCap: common.Big0,
		GasLimit:  AnchorGasLimit,
		NoSend:    true,
	}, nil
}

// signTxPayload calculates an ECDSA signature for an anchor transaction.
func (c *AnchorTxConstructor) signTxPayload(hash []byte) ([]byte, error) {
	if len(hash) != 32 {
		return nil, fmt.Errorf("hash is required to be exactly 32 bytes (%d)", len(hash))
	}

	// Try k = 1.
	sig, ok := c.signer.SignWithK(new(secp256k1.ModNScalar).SetInt(1))(hash)
	if !ok {
		// Try k = 2.
		sig, ok = c.signer.SignWithK(new(secp256k1.ModNScalar).SetInt(2))(hash)
		if !ok {
			log.Crit("Failed to sign TaikoL2.anchor transaction using K = 1 and K = 2")
		}
	}

	return sig[:], nil
}
