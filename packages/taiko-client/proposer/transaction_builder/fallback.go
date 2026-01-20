package builder

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
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
	pacayaInboxAddress common.Address,
	shastaInboxAddress common.Address,
	taikoWrapperAddress common.Address,
	proverSetAddress common.Address,
	gasLimit uint64,
	chainConfig *config.ChainConfig,
	txmgrSelector *utils.TxMgrSelector,
	revertProtectionEnabled bool,
	blobAllowed bool,
	fallback bool,
) *TxBuilderWithFallback {
	builder := &TxBuilderWithFallback{rpc: rpc, fallback: fallback, txmgrSelector: txmgrSelector}
	if blobAllowed {
		builder.blobTransactionBuilder = NewBlobTransactionBuilder(
			rpc,
			proposerPrivateKey,
			pacayaInboxAddress,
			shastaInboxAddress,
			taikoWrapperAddress,
			proverSetAddress,
			l2SuggestedFeeRecipient,
			gasLimit,
			chainConfig,
			revertProtectionEnabled,
		)
	}

	builder.calldataTransactionBuilder = NewCalldataTransactionBuilder(
		rpc,
		proposerPrivateKey,
		l2SuggestedFeeRecipient,
		pacayaInboxAddress,
		taikoWrapperAddress,
		proverSetAddress,
		gasLimit,
		chainConfig,
		revertProtectionEnabled,
	)

	return builder
}

// BuildPacaya implements the ProposeBatchTransactionBuilder interface.
func (b *TxBuilderWithFallback) BuildPacaya(
	ctx context.Context,
	txBatch []types.Transactions,
	forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
	parentMetahash common.Hash,
	preconfRouterAddress common.Address,
) (*txmgr.TxCandidate, error) {
	// If calldata is the only option, just use it.
	if b.blobTransactionBuilder == nil {
		return b.calldataTransactionBuilder.BuildPacaya(
			ctx, txBatch, forcedInclusion, minTxsPerForcedInclusion, parentMetahash, preconfRouterAddress,
		)
	}
	// If blob is enabled, and fallback is not enabled, just build a blob transaction.
	if !b.fallback {
		return b.blobTransactionBuilder.BuildPacaya(
			ctx,
			txBatch,
			forcedInclusion,
			minTxsPerForcedInclusion,
			parentMetahash,
			preconfRouterAddress,
		)
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
		if txWithCalldata, err = b.calldataTransactionBuilder.BuildPacaya(
			ctx,
			txBatch,
			forcedInclusion,
			minTxsPerForcedInclusion,
			parentMetahash,
			preconfRouterAddress,
		); err != nil {
			return fmt.Errorf("failed to build type-2 transaction: %w", err)
		}
		if costCalldata, err = b.estimateCandidateCost(ctx, txWithCalldata); err != nil {
			return fmt.Errorf("failed to estimate type-2 transaction cost: %w", encoding.TryParsingCustomError(err))
		}
		return nil
	})
	g.Go(func() error {
		if txWithBlob, err = b.blobTransactionBuilder.BuildPacaya(
			ctx,
			txBatch,
			forcedInclusion,
			minTxsPerForcedInclusion,
			parentMetahash,
			preconfRouterAddress,
		); err != nil {
			return fmt.Errorf("failed to build type-3 transaction: %w", err)
		}
		if costBlob, err = b.estimateCandidateCost(ctx, txWithBlob); err != nil {
			return fmt.Errorf("failed to estimate type-3 transaction cost: %w", encoding.TryParsingCustomError(err))
		}
		return nil
	})

	if err = g.Wait(); err != nil {
		log.Error("Failed to estimate transactions cost, will build a type-3 transaction", "error", err)
		metrics.ProposerCostEstimationError.Inc()
		// If there is an error, just build a blob transaction.
		return b.blobTransactionBuilder.BuildPacaya(
			ctx,
			txBatch,
			forcedInclusion,
			minTxsPerForcedInclusion,
			parentMetahash,
			preconfRouterAddress,
		)
	}

	var (
		costCalldataFloat64 float64
		costBlobFloat64     float64
	)
	costCalldataFloat64, _ = utils.WeiToEther(costCalldata).Float64()
	costBlobFloat64, _ = utils.WeiToEther(costBlob).Float64()

	metrics.ProposerEstimatedCostCalldata.Set(costCalldataFloat64)
	metrics.ProposerEstimatedCostBlob.Set(costBlobFloat64)

	if costCalldata.Cmp(costBlob) < 0 {
		log.Info("Building a type-2 transaction", "costCalldata", costCalldataFloat64, "costBlob", costBlobFloat64)
		metrics.ProposerProposeByCalldata.Inc()
		return txWithCalldata, nil
	}

	log.Info("Building a type-3 transaction", "costCalldata", costCalldataFloat64, "costBlob", costBlobFloat64)
	metrics.ProposerProposeByBlob.Inc()
	return txWithBlob, nil
}

// BuildShasta implements the ProposeBatchTransactionBuilder interface.
// Since Shasta fork doesn't support calldata to send txList bytes anymore, we just return the blob transaction here.
func (b *TxBuilderWithFallback) BuildShasta(
	ctx context.Context,
	txBatch []types.Transactions,
	preconfRouterAddress common.Address,
) (*txmgr.TxCandidate, error) {
	// Shasta requires blob transactions for proposal data availability.
	if b.blobTransactionBuilder == nil {
		return nil, fmt.Errorf("blob transactions must be enabled for Shasta; set --l1.blobAllowed=true")
	}
	return b.blobTransactionBuilder.BuildShasta(
		ctx,
		txBatch,
		preconfRouterAddress,
	)
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
		From:  txMgr.From(),
		To:    candidate.To,
		Gas:   candidate.GasLimit,
		Value: candidate.Value,
		Data:  candidate.TxData,
	}
	if len(candidate.Blobs) != 0 {
		var blobHashes []common.Hash
		if _, blobHashes, err = txmgr.MakeSidecar(candidate.Blobs); err != nil {
			return nil, fmt.Errorf("failed to make sidecar: %w", err)
		}
		msg.BlobHashes = blobHashes
	}

	gasUsed, err := b.rpc.L1.EstimateGas(ctx, msg)
	if err != nil {
		return nil, fmt.Errorf("failed to estimate gas used: %w", err)
	}

	feeWithoutBlob := new(big.Int).Mul(gasFeeCap, new(big.Int).SetUint64(gasUsed))

	// If it's a type-2 transaction, we won't calculate blob fee.
	if len(candidate.Blobs) == 0 {
		return feeWithoutBlob, nil
	}

	// Otherwise, we add blob fee to the cost.
	return new(big.Int).Add(
		feeWithoutBlob,
		new(big.Int).Mul(
			new(big.Int).SetUint64(
				uint64(len(candidate.Blobs)*params.BlobTxBlobGasPerBlob),
			),
			blobBaseFee,
		),
	), nil
}

// BlobAllow returns whether blob transactions are allowed.
func (b *TxBuilderWithFallback) BlobAllow() bool {
	return b.blobTransactionBuilder != nil
}
