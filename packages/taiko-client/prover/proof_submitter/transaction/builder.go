package transaction

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

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
	rpcPollingInterval       = 3 * time.Second
	defaultWaitTimeout       = 1 * time.Minute
	ErrUnretryableSubmission = errors.New("unretryable submission error")
)

// TxBuilder will build a transaction with the given nonce.
type TxBuilder func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error)

// ProveBatchesTxBuilder is responsible for building ProveBatches transactions.
type ProveBatchesTxBuilder struct {
	rpc               *rpc.Client
	indexer           *shastaIndexer.Indexer
	taikoInboxAddress common.Address
	proverSetAddress  common.Address
}

// NewProveBatchesTxBuilder creates a new ProveBatchesTxBuilder instance.
func NewProveBatchesTxBuilder(
	rpc *rpc.Client,
	indexer *shastaIndexer.Indexer,
	taikoInboxAddress common.Address,
	proverSetAddress common.Address,
) *ProveBatchesTxBuilder {
	return &ProveBatchesTxBuilder{rpc, indexer, taikoInboxAddress, proverSetAddress}
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
			subProofs   = make([]encoding.SubProof, 2)
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
			subProofs[0] = encoding.SubProof{Verifier: batchProof.Verifier, Proof: batchProof.BatchProof}
			subProofs[1] = encoding.SubProof{Verifier: batchProof.SgxGethProofVerifier, Proof: batchProof.SgxGethBatchProof}
		} else {
			subProofs[0] = encoding.SubProof{Verifier: batchProof.SgxGethProofVerifier, Proof: batchProof.SgxGethBatchProof}
			subProofs[1] = encoding.SubProof{Verifier: batchProof.Verifier, Proof: batchProof.BatchProof}
		}

		input, err := encoding.EncodeProveBatchesInput(metas, transitions)
		if err != nil {
			return nil, err
		}
		encodedSubProofs, err := encoding.EncodeBatchesSubProofs(subProofs)
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
			to = a.taikoInboxAddress
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
		)

		for i, proofResponse := range batchProof.ProofResponses {
			proposals[i] = proofResponse.Meta.Shasta().GetProposal()
			lastHeader := proofResponse.Opts.ShastaOptions().Headers[len(proofResponse.Opts.ShastaOptions().Headers)-1]

			proposalHash, err := a.rpc.GetShastaProposalHash(nil, proposals[i].Id)
			if err != nil {
				return nil, encoding.TryParsingCustomError(err)
			}
			state, err := a.rpc.GetShastaAnchorState(&bind.CallOpts{Context: txOpts.Context, BlockHash: lastHeader.Hash()})
			if err != nil {
				return nil, encoding.TryParsingCustomError(err)
			}

			parentTransitionHash, err := a.WaitParnetShastaTransitionHash(txOpts.Context, proposals[i].Id)
			if err != nil {
				log.Error("Failed to get parent Shasta transition hash", "batchID", proposals[i].Id, "error", err)
				return nil, err
			}
			log.Info(
				"Building Shasta batch proof submission transaction",
				"batchID", proposals[i].Id,
				"parentTransitionHash", common.Bytes2Hex(parentTransitionHash[:]),
				"blockNumber", lastHeader.Number,
				"blockHash", common.Bytes2Hex(lastHeader.Hash().Bytes()),
				"stateRoot", common.Bytes2Hex(lastHeader.Root.Bytes()),
				"designatedProver", state.DesignatedProver,
				"actualProver", txOpts.From,
				"gasLimit", txOpts.GasLimit,
				"to", a.taikoInboxAddress,
			)
			transitions[i] = shastaBindings.IInboxTransition{
				ProposalHash:         proposalHash,
				ParentTransitionHash: parentTransitionHash,
				Checkpoint: shastaBindings.ICheckpointManagerCheckpoint{
					BlockNumber: lastHeader.Number,
					BlockHash:   lastHeader.Hash(),
					StateRoot:   lastHeader.Root,
				},
				DesignatedProver: state.DesignatedProver,
				ActualProver:     txOpts.From,
			}
		}

		inputData, err := a.rpc.EncodeProveInputShasta(
			&bind.CallOpts{Context: txOpts.Context},
			&shastaBindings.IInboxProveInput{Proposals: proposals, Transitions: transitions},
		)
		if err != nil {
			return nil, encoding.TryParsingCustomError(err)
		}

		data, err := encoding.ShastaInboxABI.Pack("prove", inputData, batchProof.BatchProof)
		if err != nil {
			return nil, err
		}

		return &txmgr.TxCandidate{
			TxData:   data,
			To:       &a.taikoInboxAddress,
			Blobs:    nil,
			GasLimit: txOpts.GasLimit,
		}, nil
	}
}

// WaitParnetShastaTransition keeps waiting for the parent transition of the given batchID.
func (a *ProveBatchesTxBuilder) WaitParnetShastaTransitionHash(
	ctx context.Context,
	batchID *big.Int,
) (common.Hash, error) {
	var (
		ctxWithTimeout = ctx
		cancel         context.CancelFunc
	)

	ticker := time.NewTicker(rpcPollingInterval)
	defer ticker.Stop()

	if _, ok := ctx.Deadline(); !ok {
		ctxWithTimeout, cancel = context.WithTimeout(ctx, defaultWaitTimeout)
		defer cancel()
	}

	if batchID.Cmp(common.Big1) == 0 {
		header, err := a.rpc.L2.HeaderByNumber(ctx, common.Big0)
		if err != nil {
			return common.Hash{}, fmt.Errorf("failed to fetch genesis block header: %w", err)
		}
		return a.rpc.ShastaClients.Inbox.HashTransition(
			&bind.CallOpts{Context: ctxWithTimeout}, shastaBindings.IInboxTransition{
				ProposalHash:         common.Hash{},
				ParentTransitionHash: common.Hash{},
				Checkpoint: shastaBindings.ICheckpointManagerCheckpoint{
					BlockNumber: common.Big0,
					BlockHash:   header.Hash(),
					StateRoot:   common.Hash{},
				},
				DesignatedProver: rpc.ZeroAddress,
				ActualProver:     rpc.ZeroAddress,
			},
		)
	}
	log.Debug("Start fetching block header from L2 execution engine", "batchID", batchID)

	for ; true; <-ticker.C {
		if ctxWithTimeout.Err() != nil {
			return common.Hash{}, ctxWithTimeout.Err()
		}

		transition := a.indexer.GetTransitionRecordByProposalID(batchID.Uint64() - 1)
		if transition == nil {
			log.Debug("Transition record not found, keep retrying", "batchID", batchID)
			continue
		}

		hash, err := a.rpc.ShastaClients.Inbox.HashTransition(
			&bind.CallOpts{Context: ctxWithTimeout},
			*transition.Transition,
		)
		if err != nil {
			log.Error("Failed to hash Shasta transition", "batchID", batchID, "error", err)
			continue
		}

		return hash, nil
	}

	return common.Hash{}, fmt.Errorf("failed to fetch parent transition from Shasta protocol, batchID: %d", batchID)
}
