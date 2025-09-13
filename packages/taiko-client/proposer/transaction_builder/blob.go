package builder

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	shastaIndexer "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/state_indexer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// BlobTransactionBuilder is responsible for building a TaikoInbox.proposeBatch transaction with txList
// bytes saved in blob.
type BlobTransactionBuilder struct {
	rpc                     *rpc.Client
	shastaStateIndexer      *shastaIndexer.Indexer
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
	shastaStateIndexer *shastaIndexer.Indexer,
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
		shastaStateIndexer,
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
	forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
	parentMetahash common.Hash,
	preconfRouterAddress common.Address,
) (*txmgr.TxCandidate, error) {
	to := &b.taikoWrapperAddress
	if preconfRouterAddress != rpc.ZeroAddress {
		to = &preconfRouterAddress
	}

	// ABI encode the TaikoWrapper.proposeBatch / ProverSet.proposeBatch parameters.
	var (
		proposer              = crypto.PubkeyToAddress(b.proposerPrivateKey.PublicKey)
		data                  []byte
		blobs                 []*eth.Blob
		encodedParams         []byte
		blockParams           []pacayaBindings.ITaikoInboxBlockParams
		forcedInclusionParams *encoding.BatchParams
		allTxs                types.Transactions
	)

	if b.proverSetAddress != rpc.ZeroAddress {
		to = &b.proverSetAddress
		proposer = b.proverSetAddress
	}

	if forcedInclusion != nil {
		blobParams, blockParams := buildParamsForForcedInclusion(forcedInclusion, minTxsPerForcedInclusion)
		forcedInclusionParams = &encoding.BatchParams{
			Proposer:                 proposer,
			Coinbase:                 b.l2SuggestedFeeRecipient,
			RevertIfNotFirstProposal: b.revertProtectionEnabled,
			BlobParams:               *blobParams,
			Blocks:                   blockParams,
		}
	}

	for _, txs := range txBatch {
		allTxs = append(allTxs, txs...)
		blockParams = append(blockParams, pacayaBindings.ITaikoInboxBlockParams{
			NumTransactions: uint16(len(txs)),
			TimeShift:       0,
			SignalSlots:     make([][32]byte, 0),
		})
	}

	txListsBytes, err := utils.EncodeAndCompressTxList(allTxs)
	if err != nil {
		return nil, err
	}

	if blobs, err = b.splitToBlobs(txListsBytes); err != nil {
		return nil, err
	}

	params := &encoding.BatchParams{
		Proposer:                 proposer,
		Coinbase:                 b.l2SuggestedFeeRecipient,
		RevertIfNotFirstProposal: b.revertProtectionEnabled,
		BlobParams: encoding.BlobParams{
			BlobHashes:     [][32]byte{},
			FirstBlobIndex: 0,
			NumBlobs:       uint8(len(blobs)),
			ByteOffset:     0,
			ByteSize:       uint32(len(txListsBytes)),
		},
		Blocks: blockParams,
	}

	if b.revertProtectionEnabled {
		if forcedInclusionParams != nil {
			forcedInclusionParams.ParentMetaHash = parentMetahash
		} else {
			params.ParentMetaHash = parentMetahash
		}
	}

	if encodedParams, err = encoding.EncodeBatchParamsWithForcedInclusion(forcedInclusionParams, params); err != nil {
		return nil, err
	}

	if b.proverSetAddress != rpc.ZeroAddress {
		if data, err = encoding.ProverSetPacayaABI.Pack("proposeBatch", encodedParams, []byte{}); err != nil {
			return nil, err
		}
	} else {
		if data, err = encoding.TaikoWrapperABI.Pack("proposeBatch", encodedParams, []byte{}); err != nil {
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
	forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
	preconfRouterAddress common.Address,
) (*txmgr.TxCandidate, error) {
	var (
		to    = &b.taikoInboxAddress
		blobs []*eth.Blob
		data  []byte
	)
	if preconfRouterAddress != rpc.ZeroAddress {
		to = &preconfRouterAddress
	}

	config, err := b.rpc.ShastaClients.Inbox.GetConfig(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, fmt.Errorf("failed to get shasta inbox config: %w", encoding.TryParsingCustomError(err))
	}

	proposals, transitions, err := b.shastaStateIndexer.GetProposalsInput(config.MaxFinalizationCount.Uint64())
	var (
		parentProposals   []shastaBindings.IInboxProposal
		transitionRecords []shastaBindings.IInboxTransitionRecord
		checkpoint        = shastaBindings.ICheckpointManagerCheckpoint{BlockNumber: common.Big0}
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get proposals input from shasta state indexer: %w", err)
	}
	for _, p := range proposals {
		parentProposals = append(parentProposals, *p.Proposal)
	}
	for i, t := range transitions {
		if i == len(transitions)-1 {
			checkpoint = t.Transition.Checkpoint
		}
		transitionRecords = append(transitionRecords, *t.TransitionRecord)
	}

	l1Head, err := b.rpc.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L1 head: %w", err)
	}
	if l1Head.Number.Uint64() <= manifest.AnchorMinOffset {
		return nil, fmt.Errorf(
			"L1 head number %d is lower than required min offset %d",
			l1Head.Number.Uint64(),
			manifest.AnchorMinOffset,
		)
	}

	proposalManifest := &manifest.ProtocolProposalManifest{}
	for i, txs := range txBatch {
		anchorBlockNumber := uint64(0)
		if i == 0 {
			anchorBlockNumber = l1Head.Number.Uint64() - (manifest.AnchorMinOffset + 1)
		}

		proposalManifest.Blocks = append(proposalManifest.Blocks, &manifest.ProtocolBlockManifest{
			Timestamp:         0,
			Coinbase:          b.l2SuggestedFeeRecipient,
			AnchorBlockNumber: anchorBlockNumber,
			GasLimit:          0,
			Transactions:      txs,
		})
	}

	proposalManifestBytes, err := EncodeProposalManifestShasta(proposalManifest)
	if err != nil {
		return nil, fmt.Errorf("failed to encode proposal manifest: %w", err)
	}

	if blobs, err = b.splitToBlobs(proposalManifestBytes); err != nil {
		return nil, err
	}

	inputData, err := b.rpc.ShastaClients.Inbox.EncodeProposeInput(
		&bind.CallOpts{Context: ctx},
		shastaBindings.IInboxProposeInput{
			Deadline:          common.Big0,
			CoreState:         *proposals[0].CoreState,
			ParentProposals:   parentProposals,
			TransitionRecords: transitionRecords,
			Checkpoint:        checkpoint,
			BlobReference: shastaBindings.LibBlobsBlobReference{
				BlobStartIndex: 0,
				NumBlobs:       uint16(len(blobs)),
				Offset:         common.Big0,
			},
		},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to encode shasta propose input: %w", err)
	}

	if data, err = encoding.ShastaInboxABI.Pack("propose", []byte{}, inputData); err != nil {
		return nil, err
	}

	return &txmgr.TxCandidate{
		TxData:   data,
		Blobs:    blobs,
		To:       to,
		GasLimit: b.gasLimit,
	}, nil
}

// splitToBlobs splits the txListBytes into multiple blobs.
func (b *BlobTransactionBuilder) splitToBlobs(txListBytes []byte) ([]*eth.Blob, error) {
	var blobs []*eth.Blob
	for start := 0; start < len(txListBytes); start += eth.MaxBlobDataSize {
		end := min(start+eth.MaxBlobDataSize, len(txListBytes))

		var blob = &eth.Blob{}
		if err := blob.FromData(txListBytes[start:end]); err != nil {
			return nil, err
		}

		blobs = append(blobs, blob)
	}

	return blobs, nil
}

// EncodeProposalManifestShasta encodes the given proposal manifest to a byte slice
// that can be used as input to the Shasta Inbox.propose function.
func EncodeProposalManifestShasta(proposalManifest *manifest.ProtocolProposalManifest) ([]byte, error) {
	proposalManifestBytes, err := utils.EncodeAndCompressShastaProposal(*proposalManifest)
	if err != nil {
		return nil, err
	}

	// Prepend the version and length bytes to the proposal manifest bytes, then split
	// the resulting bytes into multiple blobs.
	versionBytes := make([]byte, 32)
	versionBytes[31] = byte(manifest.ShastaPayloadVersion)

	lenBytes := make([]byte, 32)
	lenBig := new(big.Int).SetUint64(uint64(len(proposalManifestBytes)))
	lenBig.FillBytes(lenBytes)

	blobBytesPrefix := make([]byte, 0, 64)
	blobBytesPrefix = append(blobBytesPrefix, versionBytes...)
	blobBytesPrefix = append(blobBytesPrefix, lenBytes...)

	return append(blobBytesPrefix, proposalManifestBytes...), nil
}
