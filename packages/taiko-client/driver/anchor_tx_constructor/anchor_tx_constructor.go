package anchortxconstructor

import (
	"context"
	"fmt"
	"math/big"

	"github.com/decred/dcrd/dcrec/secp256k1/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/signer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// AnchorTxConstructor is responsible for assembling the anchor transaction (TaikoL2.anchor) in
// each L2 block, which must be the first transaction, and its sender must be the golden touch account.
type AnchorTxConstructor struct {
	rpc    *rpc.Client
	signer *signer.FixedKSigner
}

// New creates a new AnchorConstructor instance.
func New(rpc *rpc.Client) (*AnchorTxConstructor, error) {
	signer, err := signer.NewFixedKSigner("0x" + encoding.GoldenTouchPrivKey)
	if err != nil {
		return nil, fmt.Errorf("invalid golden touch private key %s", encoding.GoldenTouchPrivKey)
	}

	return &AnchorTxConstructor{rpc, signer}, nil
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
		"baseFee", utils.WeiToGWei(baseFee),
		"gasUsed", parentGasUsed,
	)

	return c.rpc.V1.TaikoL2.Anchor(opts, l1Hash, l1Header.Root, l1Height.Uint64(), uint32(parentGasUsed))
}

// AssembleAnchorV2Tx assembles a signed TaikoL2.anchorV2 transaction.
func (c *AnchorTxConstructor) AssembleAnchorV2Tx(
	ctx context.Context,
	// Parameters of the TaikoL2.anchorV2 transaction.
	anchorBlockID *big.Int,
	anchorStateRoot common.Hash,
	parentGasUsed uint64,
	gasIssuancePerSecond uint32,
	basefeeAdjustmentQuotient uint8,
	// Height of the L2 block which including the TaikoL2.anchorV2 transaction.
	l2Height *big.Int,
	baseFee *big.Int,
) (*types.Transaction, error) {
	opts, err := c.transactOpts(ctx, l2Height, baseFee)
	if err != nil {
		return nil, err
	}

	log.Info(
		"AnchorV2 arguments",
		"l2Height", l2Height,
		"anchorBlockId", anchorBlockID,
		"anchorStateRoot", anchorStateRoot,
		"parentGasUsed", parentGasUsed,
		"gasIssuancePerSecond", gasIssuancePerSecond,
		"basefeeAdjustmentQuotient", basefeeAdjustmentQuotient,
		"baseFee", utils.WeiToGWei(baseFee),
	)

	return c.rpc.V2.TaikoL2.AnchorV2(
		opts,
		anchorBlockID.Uint64(),
		anchorStateRoot,
		uint32(parentGasUsed),
		gasIssuancePerSecond,
		basefeeAdjustmentQuotient,
	)
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
	nonce, err := c.rpc.L2AccountNonce(ctx, consensus.GoldenTouchAccount, parentHeight)
	if err != nil {
		return nil, err
	}

	log.Info(
		"Golden touch account nonce",
		"address", consensus.GoldenTouchAccount,
		"nonce", nonce,
		"parent", parentHeight,
	)

	return &bind.TransactOpts{
		From: consensus.GoldenTouchAccount,
		Signer: func(address common.Address, tx *types.Transaction) (*types.Transaction, error) {
			if address != consensus.GoldenTouchAccount {
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
		GasLimit:  consensus.AnchorGasLimit,
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
