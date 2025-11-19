package builder

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

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
	pacayaInboxAddress      common.Address
	shastaInboxAddress      common.Address
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
	pacayaInboxAddress common.Address,
	shastaInboxAddress common.Address,
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
		pacayaInboxAddress,
		shastaInboxAddress,
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

	if blobs, err = SplitToBlobs(txListsBytes); err != nil {
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
	minTxsPerForcedInclusion *big.Int,
	preconfRouterAddress common.Address,
	proverAuth []byte,
) (*txmgr.TxCandidate, error) {
	var (
		to    = &b.shastaInboxAddress
		blobs []*eth.Blob
		data  []byte
	)
	if preconfRouterAddress != rpc.ZeroAddress {
		to = &preconfRouterAddress
	}

	config, err := b.rpc.GetShastaInboxConfigs(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, fmt.Errorf("failed to get shasta inbox config: %w", encoding.TryParsingCustomError(err))
	}

	// Fetch proposals and transitions from the state indexer.
	// We need to fetch up to 2 proposals and MaxFinalizationCount transition records.
	proposals, transitions, err := b.shastaStateIndexer.GetProposalsInput(config.MaxFinalizationCount.Uint64())
	if err != nil {
		return nil, fmt.Errorf("failed to get proposals input from shasta state indexer: %w", err)
	}

	var (
		parentProposals          []shastaBindings.IInboxProposal
		transitionRecords        []shastaBindings.IInboxTransitionRecord
		checkpoint               = shastaBindings.ICheckpointStoreCheckpoint{BlockNumber: common.Big0}
		derivationSourceManifest = &manifest.DerivationSourceManifest{ProverAuthBytes: proverAuth}
	)
	for i, p := range proposals {
		log.Info(
			"Fetched proposal from state indexer",
			"index", i,
			"id", p.Proposal.Id,
			"coreStateHash", common.Bytes2Hex(p.Proposal.CoreStateHash[:]),
		)
		parentProposals = append(parentProposals, *p.Proposal)
	}
	for i, t := range transitions {
		log.Info(
			"Fetched transition from state indexer",
			"index", i,
			"proposalID", t.ProposalId,
			"proposalHash", common.Bytes2Hex(t.Transition.ProposalHash[:]),
			"checkpointBlockNumber", t.Transition.Checkpoint.BlockNumber.Uint64(),
			"checkpointBlockHash", common.Bytes2Hex(t.Transition.Checkpoint.BlockHash[:]),
			"bondInstructionsHash", len(t.TransitionRecord.BondInstructions),
		)
		if i == len(transitions)-1 {
			checkpoint = t.Transition.Checkpoint
		}
		transitionRecords = append(transitionRecords, *t.TransitionRecord)
	}

	l1Head, err := b.rpc.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L1 head: %w", err)
	}
	// The L1 head must be greater than AnchorMinOffset to propose a new proposal.
	if l1Head.Number.Uint64() <= manifest.AnchorMinOffset {
		return nil, fmt.Errorf(
			"L1 head number %d is lower than required min offset %d",
			l1Head.Number.Uint64(),
			manifest.AnchorMinOffset,
		)
	}

	// Fetch L2 head to get gas limit for the new blocks.
	l2Head, err := b.rpc.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L2 head: %w", err)
	}

	for i, txs := range txBatch {
		// For the first block, we set the anchor block number to
		// (L1 head - AnchorMinOffset - 1).
		var anchorBlockNumber = uint64(0)
		if i == 0 {
			anchorBlockNumber = l1Head.Number.Uint64() - (manifest.AnchorMinOffset + 1)
			log.Info(
				"Set anchor block number for the first block in the batch",
				"anchorBlockNumber", anchorBlockNumber,
				"l1Head", l1Head.Number.Uint64(),
				"anchorMinOffset", manifest.AnchorMinOffset,
			)
		}

		derivationSourceManifest.Blocks = append(derivationSourceManifest.Blocks, &manifest.BlockManifest{
			Timestamp:         uint64(time.Now().Unix()) + uint64(i),
			Coinbase:          b.l2SuggestedFeeRecipient,
			AnchorBlockNumber: anchorBlockNumber,
			GasLimit:          l2Head.GasLimit,
			Transactions:      txs,
		})
	}

	// Encode the derivation source manifest.
	sourceManifestBytes, err := EncodeSourceManifestShasta(derivationSourceManifest)
	if err != nil {
		return nil, fmt.Errorf("failed to encode derivation source manifest: %w", err)
	}

	// Split the derivation source manifest bytes into multiple blobs.
	if blobs, err = SplitToBlobs(sourceManifestBytes); err != nil {
		return nil, err
	}

	// ABI encode the ShastaInbox.propose parameters.
	inputData, err := b.rpc.EncodeProposeInput(
		&bind.CallOpts{Context: ctx},
		&shastaBindings.IInboxProposeInput{
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
			NumForcedInclusions: uint8(minTxsPerForcedInclusion.Uint64()),
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

// SplitToBlobs splits the txListBytes into multiple blobs.
func SplitToBlobs(txListBytes []byte) ([]*eth.Blob, error) {
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

// EncodeSourceManifestShasta encodes the given derivation source manifest to a byte slice
// that can be used as input to the Shasta Inbox.propose function.
func EncodeSourceManifestShasta(sourceManifest *manifest.DerivationSourceManifest) ([]byte, error) {
	sourceManifestBytes, err := utils.EncodeAndCompressSourceManifestShasta(sourceManifest)
	if err != nil {
		return nil, err
	}

	// Prepend the version and length bytes to the manifest bytes, then split
	// the resulting bytes into multiple blobs.
	versionBytes := make([]byte, 32)
	versionBytes[31] = byte(manifest.ShastaPayloadVersion)

	lenBytes := make([]byte, 32)
	lenBig := new(big.Int).SetUint64(uint64(len(sourceManifestBytes)))
	lenBig.FillBytes(lenBytes)

	blobBytesPrefix := make([]byte, 0, 64)
	blobBytesPrefix = append(blobBytesPrefix, versionBytes...)
	blobBytesPrefix = append(blobBytesPrefix, lenBytes...)

	return append(blobBytesPrefix, sourceManifestBytes...), nil
}
