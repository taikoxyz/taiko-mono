package transaction

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	shastaIndexer "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/state_indexer"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var (
	ErrUnretryableSubmission = errors.New("unretryable submission error")
)

// TxBuilder will build a transaction with the given nonce.
type TxBuilder func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error)

// ProveBatchesTxBuilder is responsible for building ProveBatches transactions.
type ProveBatchesTxBuilder struct {
	rpc                *rpc.Client
	indexer            *shastaIndexer.Indexer
	pacayaInboxAddress common.Address
	shastaInboxAddress common.Address
	proverSetAddress   common.Address
}

// NewProveBatchesTxBuilder creates a new ProveBatchesTxBuilder instance.
func NewProveBatchesTxBuilder(
	rpc *rpc.Client,
	indexer *shastaIndexer.Indexer,
	pacayaInboxAddress common.Address,
	shastaInboxAddress common.Address,
	proverSetAddress common.Address,
) *ProveBatchesTxBuilder {
	return &ProveBatchesTxBuilder{rpc, indexer, pacayaInboxAddress, shastaInboxAddress, proverSetAddress}
}

// BuildProveBatchesPacaya creates a new TaikoInbox.ProveBatches transaction.
func (a *ProveBatchesTxBuilder) BuildProveBatchesPacaya(batchProof *proofProducer.BatchProofs) TxBuilder {
	return func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error) {
		var (
			data        []byte
			to          common.Address
			err         error
			metas       = make([]metadata.TaikoProposalMetaData, len(batchProof.ProofResponses))
			transitions = make([]pacayaBindings.ITaikoInboxTransition, len(batchProof.ProofResponses))
			subProofs   = make([]encoding.SubProofPacaya, 2)
			batchIDs    = make([]uint64, len(batchProof.ProofResponses))
		)
		for i, proof := range batchProof.ProofResponses {
			metas[i] = proof.Meta
			transitions[i] = pacayaBindings.ITaikoInboxTransition{
				ParentHash: proof.Opts.PacayaOptions().Headers[0].ParentHash,
				BlockHash:  proof.Opts.PacayaOptions().Headers[len(proof.Opts.PacayaOptions().Headers)-1].Hash(),
				StateRoot:  proof.Opts.PacayaOptions().Headers[len(proof.Opts.PacayaOptions().Headers)-1].Root,
			}
			batchIDs[i] = proof.Meta.Pacaya().GetBatchID().Uint64()
			log.Info(
				"Build batch proof submission transaction",
				"batchID", batchIDs[i],
				"parentHash", common.Bytes2Hex(transitions[i].ParentHash[:]),
				"blockHash", common.Bytes2Hex(transitions[i].BlockHash[:]),
				"stateRoot", common.Bytes2Hex(transitions[i].StateRoot[:]),
				"startBlockID", proof.Opts.PacayaOptions().Headers[0].Number,
				"endBlockID", proof.Opts.PacayaOptions().Headers[len(proof.Opts.PacayaOptions().Headers)-1].Number,
				"gasLimit", txOpts.GasLimit,
				"verifier", batchProof.Verifier,
			)
		}
		if bytes.Compare(batchProof.Verifier.Bytes(), batchProof.SgxGethProofVerifier.Bytes()) < 0 {
			subProofs[0] = encoding.SubProofPacaya{Verifier: batchProof.Verifier, Proof: batchProof.BatchProof}
			subProofs[1] = encoding.SubProofPacaya{
				Verifier: batchProof.SgxGethProofVerifier,
				Proof:    batchProof.SgxGethBatchProof,
			}
		} else {
			subProofs[0] = encoding.SubProofPacaya{
				Verifier: batchProof.SgxGethProofVerifier,
				Proof:    batchProof.SgxGethBatchProof,
			}
			subProofs[1] = encoding.SubProofPacaya{Verifier: batchProof.Verifier, Proof: batchProof.BatchProof}
		}

		input, err := encoding.EncodeProveBatchesInput(metas, transitions)
		if err != nil {
			return nil, err
		}
		encodedSubProofs, err := encoding.EncodeBatchesSubProofsPacaya(subProofs)
		if err != nil {
			return nil, err
		}

		if a.proverSetAddress != rpc.ZeroAddress {
			if data, err = encoding.ProverSetPacayaABI.Pack("proveBatches", input, encodedSubProofs); err != nil {
				return nil, encoding.TryParsingCustomError(err)
			}
			to = a.proverSetAddress
		} else {
			if data, err = encoding.TaikoInboxABI.Pack("proveBatches", input, encodedSubProofs); err != nil {
				return nil, encoding.TryParsingCustomError(err)
			}
			to = a.pacayaInboxAddress
		}

		return &txmgr.TxCandidate{
			TxData:   data,
			To:       &to,
			Blobs:    nil,
			GasLimit: txOpts.GasLimit,
			Value:    txOpts.Value,
		}, nil
	}
}

// BuildProveBatchesShasta creates a new Shasta Inbox.prove transaction.
func (a *ProveBatchesTxBuilder) BuildProveBatchesShasta(batchProof *proofProducer.BatchProofs) TxBuilder {
	return func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error) {
		var (
			proposals   = make([]shastaBindings.IInboxProposal, len(batchProof.ProofResponses))
			transitions = make([]shastaBindings.IInboxTransition, len(batchProof.ProofResponses))
			metadatas   = make([]shastaBindings.IInboxTransitionMetadata, len(batchProof.ProofResponses))
		)

		for i, proofResponse := range batchProof.ProofResponses {
			proposals[i] = proofResponse.Meta.Shasta().GetProposal()

			proposalHash, err := a.rpc.GetShastaProposalHash(nil, proposals[i].Id)
			if err != nil {
				return nil, encoding.TryParsingCustomError(err)
			}
			transitions[i] = shastaBindings.IInboxTransition{
				ProposalHash:         proposalHash,
				ParentTransitionHash: batchProof.ProofResponses[i].Opts.ShastaOptions().ParentTransitionHash,
				Checkpoint:           *batchProof.ProofResponses[i].Opts.ShastaOptions().Checkpoint,
			}
			metadatas[i] = shastaBindings.IInboxTransitionMetadata{
				DesignatedProver: batchProof.ProofResponses[i].Opts.ShastaOptions().DesignatedProver,
				ActualProver:     txOpts.From,
			}

			log.Info(
				"Build batch proof submission transaction",
				"batchID", proposals[i].Id,
				"proposalHash", common.Bytes2Hex(transitions[i].ProposalHash[:]),
				"parentTransitionHash", common.Bytes2Hex(transitions[i].ParentTransitionHash[:]),
				"start", proofResponse.Opts.ShastaOptions().Headers[0].Number,
				"end", proofResponse.Opts.ShastaOptions().Headers[len(proofResponse.Opts.ShastaOptions().Headers)-1].Number,
				"designatedProver", batchProof.ProofResponses[i].Opts.ShastaOptions().DesignatedProver,
				"actualProver", txOpts.From,
			)
		}

		inputData, err := a.rpc.EncodeProveInput(
			&bind.CallOpts{Context: txOpts.Context},
			&shastaBindings.IInboxProveInput{Proposals: proposals, Transitions: transitions, Metadata: metadatas},
		)
		if err != nil {
			return nil, encoding.TryParsingCustomError(err)
		}
		log.Info(
			"Verifier information",
			"GethVerifierID", batchProof.SgxGethVerifierID,
			"GethProof", common.Bytes2Hex(batchProof.SgxGethBatchProof),
			"VerifierID", batchProof.VerifierID,
			"Proof", common.Bytes2Hex(batchProof.BatchProof),
		)

		subProofs := []encoding.SubProofShasta{
			{
				VerifierId: batchProof.SgxGethVerifierID,
				Proof:      batchProof.SgxGethBatchProof,
			},
			{
				VerifierId: batchProof.VerifierID,
				Proof:      batchProof.BatchProof,
			},
		}
		encodedSubProofs, err := encoding.EncodeBatchesSubProofsShasta(subProofs)
		if err != nil {
			return nil, err
		}

		data, err := encoding.ShastaInboxABI.Pack("prove", inputData, encodedSubProofs)
		if err != nil {
			return nil, err
		}
		return &txmgr.TxCandidate{
			TxData:   data,
			To:       &a.shastaInboxAddress,
			Blobs:    nil,
			GasLimit: txOpts.GasLimit,
		}, nil
	}
}

// GetShastaGenesisTransition fetches the genesis transition of Shasta.
func GetShastaGenesisTransition(
	ctx context.Context,
	rpc *rpc.Client,
) (*shastaBindings.IInboxTransition, error) {
	// Use Pacaya Inbox to derive the last Pacaya block ID, which becomes the
	// checkpoint of the Shasta genesis transition.
	blockNumber, err := rpc.LastPacayaBlockID(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch last Pacaya block ID: %w", err)
	}

	header, err := rpc.L2.HeaderByNumber(ctx, blockNumber)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch L2 header at last Pacaya block: %w", err)
	}

	return &shastaBindings.IInboxTransition{
		ProposalHash:         common.Hash{},
		ParentTransitionHash: common.Hash{},
		Checkpoint: shastaBindings.ICheckpointStoreCheckpoint{
			BlockNumber: common.Big0,
			BlockHash:   header.Hash(),
			StateRoot:   common.Hash{},
		},
	}, nil
}

// GetShastaGenesisTransitionHash fetches the genesis transition hash of Shasta.
func GetShastaGenesisTransitionHash(ctx context.Context, rpc *rpc.Client) (common.Hash, error) {
	transition, err := GetShastaGenesisTransition(ctx, rpc)
	if err != nil {
		return common.Hash{}, fmt.Errorf("failed to fetch genesis transition: %w", err)
	}
	return rpc.HashTransitionShasta(&bind.CallOpts{Context: ctx}, transition)
}

// BuildParentTransitionHash builds the parent transition hash for the given batchID.
func BuildParentTransitionHash(
	ctx context.Context,
	rpc *rpc.Client,
	indexer *shastaIndexer.Indexer,
	batchID *big.Int,
) (common.Hash, error) {
	type transitionEntry struct {
		transition *shastaBindings.IInboxTransition
	}

	targetBatchID := new(big.Int).Set(batchID)
	var (
		parentTransitions []transitionEntry
		cursor            = new(big.Int).Sub(new(big.Int).Set(batchID), common.Big1)
		coreState         = indexer.GetLastCoreState()
	)

	// If the parent transition already been just finalized, return the last finalized transition hash directly.
	if cursor.Cmp(coreState.LastFinalizedProposalId) == 0 {
		return coreState.LastFinalizedTransitionHash, nil
	}

	for {
		if cursor.Cmp(common.Big0) == 0 {
			transition, err := GetShastaGenesisTransition(ctx, rpc)
			if err != nil {
				return common.Hash{}, err
			}
			parentTransitions = append(
				[]transitionEntry{{transition: transition}},
				parentTransitions...,
			)
			break
		}

		if coreState.LastFinalizedProposalId.Cmp(cursor) == 0 {
			if len(parentTransitions) != 0 {
				parentTransitions[0].transition.ParentTransitionHash = coreState.LastFinalizedTransitionHash
			}
			break
		}

		if transition := indexer.GetTransitionRecordByProposalID(cursor.Uint64()); transition != nil {
			log.Debug(
				"Using cached Shasta transition record",
				"proposalId", transition.ProposalId,
				"hash", common.Hash(transition.TransitionRecord.TransitionHash),
			)
			var blockNumber *big.Int
			if transition.Transition.Checkpoint.BlockNumber != nil {
				blockNumber = new(big.Int).Set(transition.Transition.Checkpoint.BlockNumber)
			}
			transitionCopy := &shastaBindings.IInboxTransition{
				ProposalHash:         transition.Transition.ProposalHash,
				ParentTransitionHash: common.Hash{},
				Checkpoint: shastaBindings.ICheckpointStoreCheckpoint{
					BlockNumber: blockNumber,
					BlockHash:   transition.Transition.Checkpoint.BlockHash,
					StateRoot:   transition.Transition.Checkpoint.StateRoot,
				},
			}
			parentTransitions = append(
				[]transitionEntry{{transition: transitionCopy}},
				parentTransitions...,
			)
			cursor.Sub(cursor, common.Big1)
			continue
		}

		proposal, err := indexer.GetProposalByID(cursor.Uint64())
		if err != nil {
			return common.Hash{}, fmt.Errorf("failed to fetch proposal %d: %w", cursor.Uint64(), err)
		}

		checkpointL1Origin, err := rpc.L2.LastL1OriginByBatchID(ctx, proposal.Proposal.Id)
		if err != nil {
			return common.Hash{}, fmt.Errorf("failed to fetch last L1 origin: %w", err)
		}
		checkpointHeader, err := rpc.L2.HeaderByNumber(ctx, checkpointL1Origin.BlockID)
		if err != nil {
			return common.Hash{}, fmt.Errorf("failed to fetch checkpoint header: %w", err)
		}
		proposalHash, err := rpc.HashProposalShasta(&bind.CallOpts{Context: ctx}, proposal.Proposal)
		if err != nil {
			return common.Hash{}, fmt.Errorf("failed to fetch proposal hash: %w", err)
		}

		localTransition := &shastaBindings.IInboxTransition{
			ProposalHash:         proposalHash,
			ParentTransitionHash: common.Hash{},
			Checkpoint: shastaBindings.ICheckpointStoreCheckpoint{
				BlockNumber: checkpointHeader.Number,
				BlockHash:   checkpointHeader.Hash(),
				StateRoot:   checkpointHeader.Root,
			},
		}

		parentTransitions = append(
			[]transitionEntry{{transition: localTransition}},
			parentTransitions...,
		)
		cursor.Sub(cursor, common.Big1)
	}

	if len(parentTransitions) == 0 {
		return common.Hash{}, fmt.Errorf("no parent transition found for batchID %s", targetBatchID)
	}

	currentHash, err := rpc.HashTransitionShasta(&bind.CallOpts{Context: ctx}, parentTransitions[0].transition)
	if err != nil {
		return common.Hash{}, fmt.Errorf("failed to hash Shasta transition: %w", err)
	}
	for i := 1; i < len(parentTransitions); i++ {
		parentTransitions[i].transition.ParentTransitionHash = currentHash
		if currentHash, err = rpc.HashTransitionShasta(
			&bind.CallOpts{Context: ctx},
			parentTransitions[i].transition,
		); err != nil {
			return common.Hash{}, fmt.Errorf("failed to hash Shasta transition: %w", err)
		}
	}

	return currentHash, nil
}
