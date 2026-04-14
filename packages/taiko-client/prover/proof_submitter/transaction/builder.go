package transaction

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// TxBuilder will build a transaction with the given nonce.
type TxBuilder func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error)

// ProveBatchesTxBuilder is responsible for building inbox.prove transactions.
type ProveBatchesTxBuilder struct {
	rpc          *rpc.Client
	inboxAddress common.Address
}

// NewProveBatchesTxBuilder creates a new ProveBatchesTxBuilder instance.
func NewProveBatchesTxBuilder(
	rpc *rpc.Client,
	inboxAddress common.Address,
) *ProveBatchesTxBuilder {
	return &ProveBatchesTxBuilder{rpc: rpc, inboxAddress: inboxAddress}
}

// BuildProveBatchesShasta creates a new inbox prove transaction.
func (a *ProveBatchesTxBuilder) BuildProveBatchesShasta(
	ctx context.Context,
	batchProof *proofProducer.BatchProofs,
) TxBuilder {
	return func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error) {
		var (
			proposals = make([]*shastaBindings.ShastaInboxClientProposed, len(batchProof.ProofResponses))
			input     = &shastaBindings.IInboxProveInput{
				Commitment: shastaBindings.IInboxCommitment{ActualProver: txOpts.From},
			}
		)

		if len(batchProof.ProofResponses) == 0 {
			return nil, fmt.Errorf("no proof responses in batch proof")
		}

		for i, proofResponse := range batchProof.ProofResponses {
			if len(proofResponse.Opts.ProposalOptions().Headers) == 0 {
				return nil, fmt.Errorf(
					"no headers in proof response options for proposal ID %d",
					proofResponse.Meta.Shasta().GetEventData().Id,
				)
			}
			proposals[i] = proofResponse.Meta.Shasta().GetEventData()
			lastHeader := proofResponse.Opts.ProposalOptions().Headers[len(proofResponse.Opts.ProposalOptions().Headers)-1]

			proposalHash, err := a.rpc.GetProposalHash(nil, proposals[i].Id)
			if err != nil {
				return nil, encoding.TryParsingCustomError(err)
			}

			// Set first proposal information.
			if i == 0 {
				input.Commitment.FirstProposalId = proposals[i].Id
				if proposals[i].Id.Cmp(common.Big1) == 0 {
					block, err := a.rpc.L2.BlockByNumber(ctx, proofResponse.Opts.ProposalOptions().L2BlockNums[0])
					if err != nil {
						return nil, err
					}
					input.Commitment.FirstProposalParentBlockHash = block.ParentHash()
				} else {
					lastOriginInLastProposal, err := a.rpc.LastL1OriginInProposal(
						ctx,
						new(big.Int).Sub(proposals[i].Id, common.Big1),
					)
					if err != nil {
						return nil, err
					}
					input.Commitment.FirstProposalParentBlockHash = lastOriginInLastProposal.L2BlockHash
				}
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
				"Build proposal proof submission transaction",
				"proposalID", proposals[i].Id,
				"proposalHash", proposalHash,
				"start", proofResponse.Opts.ProposalOptions().Headers[0].Number,
				"end", proofResponse.Opts.ProposalOptions().Headers[len(proofResponse.Opts.ProposalOptions().Headers)-1].Number,
				"designatedProver", batchProof.ProofResponses[i].Opts.ProposalOptions().DesignatedProver,
				"actualProver", txOpts.From,
				"firstProposalParentBlockHash", common.Bytes2Hex(input.Commitment.FirstProposalParentBlockHash[:]),
			)
		}

		// Validate consecutive proposals.
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

		encodedSubProofs, err := encoding.EncodeBatchesSubProofs([]encoding.SubProofShasta{
			{VerifierId: batchProof.SgxGethVerifierID, Proof: batchProof.SgxGethBatchProof},
			{VerifierId: batchProof.VerifierID, Proof: batchProof.BatchProof},
		})
		if err != nil {
			return nil, err
		}

		data, err := encoding.ShastaInboxABI.Pack("prove", inputData, encodedSubProofs)
		if err != nil {
			return nil, encoding.TryParsingCustomError(err)
		}

		return &txmgr.TxCandidate{
			TxData:   data,
			To:       &a.inboxAddress,
			Blobs:    nil,
			GasLimit: txOpts.GasLimit,
			Value:    txOpts.Value,
		}, nil
	}
}
