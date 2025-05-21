package builder

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/params"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// BlobTransactionBuilder is responsible for building a TaikoInbox.proposeBatch transaction with txList
// bytes saved in blob.
type BlobTransactionBuilder struct {
	rpc                     *rpc.Client
	proposerPrivateKey      *ecdsa.PrivateKey
	taikoInboxAddress       common.Address
	taikoWrapperAddress     common.Address
	proverSetAddress        common.Address
	l2SuggestedFeeRecipient common.Address
	gasLimit                uint64
	chainConfig             *config.ChainConfig
	revertProtectionEnabled bool
}

// NewBlobTransactionBuilder creates a new BlobTransactionBuilder instance based on giving configurations.
func NewBlobTransactionBuilder(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	taikoInboxAddress common.Address,
	taikoWrapperAddress common.Address,
	proverSetAddress common.Address,
	l2SuggestedFeeRecipient common.Address,
	gasLimit uint64,
	chainConfig *config.ChainConfig,
	revertProtectionEnabled bool,
) *BlobTransactionBuilder {
	return &BlobTransactionBuilder{
		rpc,
		proposerPrivateKey,
		taikoInboxAddress,
		taikoWrapperAddress,
		proverSetAddress,
		l2SuggestedFeeRecipient,
		gasLimit,
		chainConfig,
		revertProtectionEnabled,
	}
}

// BuildPacaya implements the ProposeBatchTransactionBuilder interface.
func (b *BlobTransactionBuilder) BuildPacaya(
	ctx context.Context,
	txBatch []types.Transactions,
	forcedInclusion params.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
	parentMetahash common.Hash,
) (*txmgr.TxCandidate, error) {
	// ABI encode the TaikoWrapper.proposeBatch / ProverSet.proposeBatch parameters.
	var (
		to       = &b.taikoWrapperAddress
		proposer = crypto.PubkeyToAddress(b.proposerPrivateKey.PublicKey)
		data     []byte
		blobs    []*eth.Blob
	)

	if b.proverSetAddress != rpc.ZeroAddress {
		to = &b.proverSetAddress
	}

	encodedParams, txListsBytes, err := BuildProposalParams(
		ctx,
		b.taikoInboxAddress,
		b.proverSetAddress,
		b.l2SuggestedFeeRecipient,
		b.revertProtectionEnabled,
		proposer,
		txBatch,
		forcedInclusion,
		minTxsPerForcedInclusion,
		parentMetahash,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to build Pacaya proposal params: %w", err)
	}

	if blobs, err = b.splitToBlobs(txListsBytes); err != nil {
		return nil, err
	}

	if b.proverSetAddress != rpc.ZeroAddress {
		if data, err = encoding.ProverSetPacayaABI.Pack("proposeBatch", encodedParams, []byte{}); err != nil {
			return nil, err
		}
	} else {
		if data, err = encoding.TaikoWrapperPacayaABI.Pack("proposeBatch", encodedParams, []byte{}); err != nil {
			return nil, err
		}
	}

	return &txmgr.TxCandidate{
		TxData:   data,
		Blobs:    blobs,
		To:       to,
		GasLimit: b.gasLimit,
	}, nil
}

// BuildShasta implements the ProposeBatchTransactionBuilder interface.
func (b *BlobTransactionBuilder) BuildShasta(
	ctx context.Context,
	txBatch []types.Transactions,
	forcedInclusion params.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
	parentMetahash common.Hash,
) (*txmgr.TxCandidate, error) {
	// ABI encode the TaikoWrapper.v4ProposeBatch / ProverSet.v4ProposeBatch parameters.
	var (
		to       = &b.taikoWrapperAddress
		proposer = crypto.PubkeyToAddress(b.proposerPrivateKey.PublicKey)
		data     []byte
		blobs    []*eth.Blob
	)

	if b.proverSetAddress != rpc.ZeroAddress {
		to = &b.proverSetAddress
	}

	// TODO: add NumBlobs: uint8(len(blobs)),
	encodedParams, txListsBytes, err := BuildProposalParams(
		ctx,
		b.taikoInboxAddress,
		b.proverSetAddress,
		b.l2SuggestedFeeRecipient,
		b.revertProtectionEnabled,
		proposer,
		txBatch,
		forcedInclusion,
		minTxsPerForcedInclusion,
		parentMetahash,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to build Shasta proposal params: %w", err)
	}

	if blobs, err = b.splitToBlobs(txListsBytes); err != nil {
		return nil, fmt.Errorf("failed to split transactions bytes into blobs: %w", err)
	}

	if b.proverSetAddress != rpc.ZeroAddress {
		if data, err = encoding.ProverSetShastaABI.Pack("v4ProposeBatch", encodedParams, []byte{}); err != nil {
			return nil, err
		}
	} else {
		if data, err = encoding.TaikoWrapperShastaABI.Pack("v4ProposeBatch", encodedParams, []byte{}); err != nil {
			return nil, err
		}
	}

	return &txmgr.TxCandidate{TxData: data, Blobs: blobs, To: to, GasLimit: b.gasLimit}, nil
}

// splitToBlobs splits the txListBytes into multiple blobs.
func (b *BlobTransactionBuilder) splitToBlobs(txListBytes []byte) ([]*eth.Blob, error) {
	var blobs []*eth.Blob
	for start := 0; start < len(txListBytes); start += eth.MaxBlobDataSize {
		end := start + eth.MaxBlobDataSize
		if end > len(txListBytes) {
			end = len(txListBytes)
		}

		var blob = &eth.Blob{}
		if err := blob.FromData(txListBytes[start:end]); err != nil {
			return nil, err
		}

		blobs = append(blobs, blob)
	}

	return blobs, nil
}
