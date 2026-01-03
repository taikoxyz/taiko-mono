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
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/signer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// AnchorTxConstructor is responsible for assembling the anchor transaction (TaikoAnchor.anchorV3) in
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

// AssembleAnchorV3Tx assembles a signed TaikoAnchor.anchorV3 transaction.
func (c *AnchorTxConstructor) AssembleAnchorV3Tx(
	ctx context.Context,
	// Parameters of the TaikoAnchor.anchorV3 transaction.
	anchorBlockID *big.Int,
	anchorStateRoot common.Hash,
	parent *types.Header,
	baseFeeConfig *pacayaBindings.LibSharedDataBaseFeeConfig,
	signalSlots [][32]byte,
	// Height of the L2 block which including the TaikoAnchor.anchorV3 transaction.
	l2Height *big.Int,
	baseFee *big.Int,
) (*types.Transaction, error) {
	opts, err := c.transactOpts(ctx, l2Height, baseFee, parent.Hash())
	if err != nil {
		return nil, fmt.Errorf("failed to create transaction options: %w", err)
	}

	log.Info(
		"AnchorV3 arguments",
		"l2Height", l2Height,
		"anchorBlockId", anchorBlockID,
		"anchorStateRoot", anchorStateRoot,
		"parentGasUsed", parent.GasUsed,
		"parentHash", parent.Hash(),
		"gasIssuancePerSecond", baseFeeConfig.GasIssuancePerSecond,
		"basefeeAdjustmentQuotient", baseFeeConfig.AdjustmentQuotient,
		"signalSlots", len(signalSlots),
		"baseFee", utils.WeiToGWei(baseFee),
	)

	return c.rpc.PacayaClients.TaikoAnchor.AnchorV3(
		opts,
		anchorBlockID.Uint64(),
		anchorStateRoot,
		uint32(parent.GasUsed),
		*baseFeeConfig,
		signalSlots,
	)
}

// AssembleAnchorV4Tx assembles a signed ShastaAnchor.anchorV4 transaction.
func (c *AnchorTxConstructor) AssembleAnchorV4Tx(
	ctx context.Context,
	// Parameters of the ShastaAnchor.anchorV4 transaction.
	parent *types.Header,
	proposer common.Address,
	anchorBlockNumber *big.Int,
	anchorBlockHash common.Hash,
	anchorStateRoot common.Hash,
	endOfSubmissionWindowTimestamp *big.Int,
	// Height of the L2 block which including the ShastaAnchor.anchorV4 transaction.
	l2Height *big.Int,
	baseFee *big.Int,
) (*types.Transaction, error) {
	opts, err := c.transactOpts(ctx, l2Height, baseFee, parent.Hash())
	if err != nil {
		return nil, err
	}

	log.Info(
		"AnchorV4 arguments",
		"l2Height", l2Height,
		"anchorBlockId", anchorBlockNumber,
		"anchorStateRoot", anchorStateRoot,
		"parentGasUsed", parent.GasUsed,
		"parentHash", parent.Hash(),
		"proposer", proposer,
		"endOfSubmissionWindowTimestamp", endOfSubmissionWindowTimestamp,
	)

	return c.rpc.ShastaClients.Anchor.AnchorV4(
		opts,
		shastaBindings.ICheckpointStoreCheckpoint{
			BlockNumber: anchorBlockNumber,
			BlockHash:   anchorBlockHash,
			StateRoot:   anchorStateRoot,
		},
	)
}

// transactOpts is a utility method to create some transact options of the anchor transaction in given L2 block with
// golden touch account's private key.
func (c *AnchorTxConstructor) transactOpts(
	ctx context.Context,
	l2Height *big.Int,
	baseFee *big.Int,
	parentHash common.Hash,
) (*bind.TransactOpts, error) {
	var (
		signer = types.LatestSignerForChainID(c.rpc.L2.ChainID)
	)

	// Get the nonce of golden touch account at the specified parentHeight.
	nonce, err := c.rpc.L2AccountNonce(ctx, consensus.GoldenTouchAccount, parentHash)
	if err != nil {
		return nil, fmt.Errorf("failed to get account nonce: %w", err)
	}

	log.Info(
		"Golden touch account nonce",
		"address", consensus.GoldenTouchAccount,
		"nonce", nonce,
		"parent", new(big.Int).Sub(l2Height, common.Big1),
		"parentHash", parentHash,
	)

	return &bind.TransactOpts{
		From: consensus.GoldenTouchAccount,
		Signer: func(address common.Address, tx *types.Transaction) (*types.Transaction, error) {
			if address != consensus.GoldenTouchAccount {
				return nil, bind.ErrNotAuthorized
			}
			signature, err := c.signTxPayload(signer.Hash(tx).Bytes())
			if err != nil {
				return nil, fmt.Errorf("failed to sign transaction payload: %w", err)
			}
			return tx.WithSignature(signer, signature)
		},
		Nonce:     new(big.Int).SetUint64(nonce),
		Context:   ctx,
		GasFeeCap: baseFee,
		GasTipCap: common.Big0,
		GasLimit:  consensus.AnchorV3V4GasLimit,
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
			log.Crit("Failed to sign TaikoAnchor.anchorV3 / ShastaAnchor.anchorV4 transaction using K = 1 and K = 2")
		}
	}

	return sig[:], nil
}
