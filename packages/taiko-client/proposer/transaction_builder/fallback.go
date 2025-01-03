package builder

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// TxBuilderWithFallback builds type-2 or type-3 transactions based on the
// the realtime onchain cost, if the fallback feature is enabled.
type TxBuilderWithFallback struct {
	rpc                        *rpc.Client
	blobTransactionBuilder     *BlobTransactionBuilder
	calldataTransactionBuilder *CalldataTransactionBuilder
	txmgrSelector              *utils.TxMgrSelector
	fallback                   bool
}

// NewBuilderWithFallback creates a new TxBuilderWithFallback instance.
func NewBuilderWithFallback(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	l2SuggestedFeeRecipient common.Address,
	taikoL1Address common.Address,
	proverSetAddress common.Address,
	gasLimit uint64,
	extraData string,
	chainConfig *config.ChainConfig,
	txmgrSelector *utils.TxMgrSelector,
	revertProtectionEnabled bool,
	blobAllowed bool,
	fallback bool,
) *TxBuilderWithFallback {
	builder := &TxBuilderWithFallback{
		rpc:           rpc,
		fallback:      fallback,
		txmgrSelector: txmgrSelector,
	}

	if blobAllowed {
		builder.blobTransactionBuilder = NewBlobTransactionBuilder(
			rpc,
			proposerPrivateKey,
			taikoL1Address,
			proverSetAddress,
			l2SuggestedFeeRecipient,
			gasLimit,
			extraData,
			chainConfig,
			revertProtectionEnabled,
		)
	}

	builder.calldataTransactionBuilder = NewCalldataTransactionBuilder(
		rpc,
		proposerPrivateKey,
		l2SuggestedFeeRecipient,
		taikoL1Address,
		proverSetAddress,
		gasLimit,
		extraData,
		chainConfig,
		revertProtectionEnabled,
	)

	return builder
}

// BuildOntake builds a type-2 or type-3 transaction based on the
// the realtime onchain cost, if the fallback feature is enabled.
func (b *TxBuilderWithFallback) BuildOntake(
	ctx context.Context,
	txListBytesArray [][]byte,
) (*txmgr.TxCandidate, error) {
	// If calldata is the only option, just use it.
	if b.blobTransactionBuilder == nil {
		return b.calldataTransactionBuilder.BuildOntake(ctx, txListBytesArray)
	}
	// If blob is enabled, and fallback is not enabled, just build a blob transaction.
	if !b.fallback {
		return b.blobTransactionBuilder.BuildOntake(ctx, txListBytesArray)
	}

	// Otherwise, compare the cost, and choose the cheaper option.
	var (
		g              = new(errgroup.Group)
		txWithCalldata *txmgr.TxCandidate
		txWithBlob     *txmgr.TxCandidate
		costCalldata   *big.Int
		costBlob       *big.Int
		err            error
	)

	g.Go(func() error {
		if txWithCalldata, err = b.calldataTransactionBuilder.BuildOntake(ctx, txListBytesArray); err != nil {
			return err
		}
		if costCalldata, err = b.estimateCandidateCost(ctx, txWithCalldata); err != nil {
			return err
		}
		return nil
	})
	g.Go(func() error {
		if txWithBlob, err = b.blobTransactionBuilder.BuildOntake(ctx, txListBytesArray); err != nil {
			return err
		}
		if costBlob, err = b.estimateCandidateCost(ctx, txWithBlob); err != nil {
			return err
		}
		return nil
	})

	if err = g.Wait(); err != nil {
		return nil, err
	}

	metrics.ProposerEstimatedCostCalldata.Set(float64(costCalldata.Uint64()))
	metrics.ProposerEstimatedCostBlob.Set(float64(costBlob.Uint64()))

	if costCalldata.Cmp(costBlob) < 0 {
		log.Info("Building a type-2 transaction", "costCalldata", costCalldata, "costBlob", costBlob)
		return txWithCalldata, nil
	}

	log.Info("Building a type-3 transaction", "costCalldata", costCalldata, "costBlob", costBlob)
	return txWithBlob, nil
}

// estimateCandidateCost estimates the realtime onchain cost of the given transaction.
func (b *TxBuilderWithFallback) estimateCandidateCost(
	ctx context.Context,
	candidate *txmgr.TxCandidate,
) (*big.Int, error) {
	txMgr, _ := b.txmgrSelector.Select()
	gasTipCap, baseFee, blobBaseFee, err := txMgr.SuggestGasPriceCaps(ctx)
	if err != nil {
		return nil, err
	}
	log.Debug("Suggested gas price", "gasTipCap", gasTipCap, "baseFee", baseFee, "blobBaseFee", blobBaseFee)

	gasFeeCap := new(big.Int).Add(baseFee, gasTipCap)
	msg := ethereum.CallMsg{
		From:      txMgr.From(),
		To:        candidate.To,
		Gas:       candidate.GasLimit,
		GasFeeCap: gasFeeCap,
		GasTipCap: gasTipCap,
		Value:     candidate.Value,
		Data:      candidate.TxData,
	}
	if len(candidate.Blobs) != 0 {
		var blobHashes []common.Hash
		if _, blobHashes, err = txmgr.MakeSidecar(candidate.Blobs); err != nil {
			return nil, fmt.Errorf("failed to make sidecar: %w", err)
		}
		msg.BlobHashes = blobHashes
		msg.BlobGasFeeCap = blobBaseFee
	}

	gasUsed, err := b.rpc.L1.EstimateGas(ctx, msg)
	if err != nil {
		return nil, fmt.Errorf("failed to estimate gas used: %w", err)
	}

	feeWithoutBlob := new(big.Int).Mul(gasFeeCap, new(big.Int).SetUint64(gasUsed))

	// If its a type-2 transaction, we won't calculate blob fee.
	if len(candidate.Blobs) == 0 {
		return feeWithoutBlob, nil
	}

	// Otherwise, we add blob fee to the cost.
	return new(big.Int).Add(
		feeWithoutBlob,
		new(big.Int).Mul(new(big.Int).SetUint64(uint64(len(candidate.Blobs))), blobBaseFee),
	), nil
}

// TxBuilderWithFallback returns whether the blob transactions is enabled.
func (b *TxBuilderWithFallback) BlobAllow() bool {
	return b.blobTransactionBuilder != nil
}
