package builder

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// CalldataTransactionBuilder is responsible for building a TaikoInbox.proposeBatch transaction with txList
// bytes saved in calldata.
type CalldataTransactionBuilder struct {
	rpc                     *rpc.Client
	proposerPrivateKey      *ecdsa.PrivateKey
	l2SuggestedFeeRecipient common.Address
	taikoInboxAddress       common.Address
	taikoWrapperAddress     common.Address
	proverSetAddress        common.Address
	gasLimit                uint64
	chainConfig             *config.ChainConfig
	revertProtectionEnabled bool
}

// NewCalldataTransactionBuilder creates a new CalldataTransactionBuilder instance based on giving configurations.
func NewCalldataTransactionBuilder(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	l2SuggestedFeeRecipient common.Address,
	taikoInboxAddress common.Address,
	taikoWrapperAddress common.Address,
	proverSetAddress common.Address,
	gasLimit uint64,
	chainConfig *config.ChainConfig,
	revertProtectionEnabled bool,
) *CalldataTransactionBuilder {
	return &CalldataTransactionBuilder{
		rpc,
		proposerPrivateKey,
		l2SuggestedFeeRecipient,
		taikoInboxAddress,
		taikoWrapperAddress,
		proverSetAddress,
		gasLimit,
		chainConfig,
		revertProtectionEnabled,
	}
}

// BuildPacaya implements the ProposeBatchTransactionBuilder interface.
func (b *CalldataTransactionBuilder) BuildPacaya(
	ctx context.Context,
	txBatch []types.Transactions,
	forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
	parentMetahash common.Hash,
) (*txmgr.TxCandidate, error) {
	// ABI encode the TaikoWrapper.proposeBatch / ProverSet.proposeBatch parameters.
	var (
		to       = &b.taikoWrapperAddress
		proposer = crypto.PubkeyToAddress(b.proposerPrivateKey.PublicKey)
		data     []byte
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

	if b.proverSetAddress != rpc.ZeroAddress {
		if data, err = encoding.ProverSetPacayaABI.Pack("proposeBatch", encodedParams, txListsBytes); err != nil {
			return nil, err
		}
	} else {
		if data, err = encoding.TaikoWrapperPacayaABI.Pack("proposeBatch", encodedParams, txListsBytes); err != nil {
			return nil, err
		}
	}

	return &txmgr.TxCandidate{TxData: data, Blobs: nil, To: to, GasLimit: b.gasLimit}, nil
}

// BuildShasta implements the ProposeBatchTransactionBuilder interface.
func (b *CalldataTransactionBuilder) BuildShasta(
	ctx context.Context,
	txBatch []types.Transactions,
	forcedInclusion *shastaBindings.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
	parentMetahash common.Hash,
) (*txmgr.TxCandidate, error) {
	// ABI encode the TaikoWrapper.v4ProposeBatch / ProverSet.v4ProposeBatch parameters.
	var (
		to       = &b.taikoWrapperAddress
		proposer = crypto.PubkeyToAddress(b.proposerPrivateKey.PublicKey)
		data     []byte
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
		return nil, fmt.Errorf("failed to build Shasta proposal params: %w", err)
	}

	if b.proverSetAddress != rpc.ZeroAddress {
		if data, err = encoding.ProverSetShastaABI.Pack("v4ProposeBatch", encodedParams, txListsBytes); err != nil {
			return nil, err
		}
	} else {
		if data, err = encoding.TaikoWrapperShastaABI.Pack("v4ProposeBatch", encodedParams, txListsBytes); err != nil {
			return nil, err
		}
	}

	return &txmgr.TxCandidate{TxData: data, Blobs: nil, To: to, GasLimit: b.gasLimit}, nil
}
