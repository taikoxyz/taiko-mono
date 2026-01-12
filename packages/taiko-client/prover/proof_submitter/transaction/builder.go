package transaction

import (
	"bytes"
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
	pacayaInboxAddress common.Address
	shastaInboxAddress common.Address
	proverSetAddress   common.Address
}

// NewProveBatchesTxBuilder creates a new ProveBatchesTxBuilder instance.
func NewProveBatchesTxBuilder(
	rpc *rpc.Client,
	pacayaInboxAddress common.Address,
	shastaInboxAddress common.Address,
	proverSetAddress common.Address,
) *ProveBatchesTxBuilder {
	return &ProveBatchesTxBuilder{rpc, pacayaInboxAddress, shastaInboxAddress, proverSetAddress}
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
			proposals = make([]*shastaBindings.ShastaInboxClientProposed, len(batchProof.ProofResponses))
			input     = &shastaBindings.IInboxProveInput{
				Commitment:          shastaBindings.IInboxCommitment{ActualProver: txOpts.From},
				ForceCheckpointSync: false,
			}
		)

		if len(batchProof.ProofResponses) == 0 {
			return nil, fmt.Errorf("no proof responses in batch proof")
		}

		for i, proofResponse := range batchProof.ProofResponses {
			if len(proofResponse.Opts.ShastaOptions().Headers) == 0 {
				return nil, fmt.Errorf(
					"no headers in proof response options for proposal ID %d",
					proofResponse.Meta.Shasta().GetEventData().Id,
				)
			}
			proposals[i] = proofResponse.Meta.Shasta().GetEventData()
			lastHeader := proofResponse.Opts.ShastaOptions().Headers[len(proofResponse.Opts.ShastaOptions().Headers)-1]

			proposalHash, err := a.rpc.GetShastaProposalHash(nil, proposals[i].Id)
			if err != nil {
				return nil, encoding.TryParsingCustomError(err)
			}

			// Set first proposal information.
			if i == 0 {
				input.Commitment.FirstProposalId = proposals[i].Id
				input.Commitment.FirstProposalParentBlockHash = proofResponse.Opts.ShastaOptions().Headers[0].ParentHash
			}

			// Set last proposal information.
			if i == len(batchProof.ProofResponses)-1 {
				input.Commitment.LastProposalHash = proposalHash
				input.Commitment.EndBlockNumber = lastHeader.Number
				input.Commitment.EndStateRoot = lastHeader.Root
			}

			// Set transition information.
			input.Commitment.Transitions = append(input.Commitment.Transitions, shastaBindings.IInboxTransition{
				Proposer:  proposals[i].Proposer,
				Timestamp: new(big.Int).SetUint64(proofResponse.Meta.Shasta().GetTimestamp()),
				BlockHash: lastHeader.Hash(),
			})

			log.Info(
				"Build batch proof submission transaction",
				"batchID", proposals[i].Id,
				"proposalHash", proposalHash,
				"start", proofResponse.Opts.ShastaOptions().Headers[0].Number,
				"end", proofResponse.Opts.ShastaOptions().Headers[len(proofResponse.Opts.ShastaOptions().Headers)-1].Number,
				"designatedProver", batchProof.ProofResponses[i].Opts.ShastaOptions().DesignatedProver,
				"actualProver", txOpts.From,
				"firstProposalParentBlockHash", common.Bytes2Hex(input.Commitment.FirstProposalParentBlockHash[:]),
			)
		}

		// Validate consecutive proposals
		for i := 1; i < len(proposals); i++ {
			if proposals[i].Id.Uint64() != proposals[i-1].Id.Uint64()+1 {
				return nil, fmt.Errorf(
					"non-consecutive proposals: %d -> %d",
					proposals[i-1].Id,
					proposals[i].Id)
			}
		}

		inputData, err := a.rpc.EncodeProveInput(&bind.CallOpts{Context: txOpts.Context}, input)
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
