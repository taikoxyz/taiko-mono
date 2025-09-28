package transaction

import (
	"bytes"
	"errors"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
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
	rpc                         *rpc.Client
	taikoInboxAddress           common.Address
	proverSetAddress            common.Address
	surgeProposerWrapperAddress common.Address
}

// NewProveBatchesTxBuilder creates a new ProveBatchesTxBuilder instance.
func NewProveBatchesTxBuilder(
	rpc *rpc.Client,
	taikoInboxAddress common.Address,
	proverSetAddress common.Address,
	surgeProposerWrapperAddress common.Address,
) *ProveBatchesTxBuilder {
	return &ProveBatchesTxBuilder{
		rpc:                         rpc,
		taikoInboxAddress:           taikoInboxAddress,
		proverSetAddress:            proverSetAddress,
		surgeProposerWrapperAddress: surgeProposerWrapperAddress,
	}
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
				"zkVerifier", batchProof.Verifier,
				"sgxVerifier", batchProof.SgxProofVerifier,
			)
		}
		if bytes.Compare(batchProof.Verifier.Bytes(), batchProof.SgxProofVerifier.Bytes()) < 0 {
			subProofs[0] = encoding.SubProof{
				ProofType: encoding.GetProofTypeFromString(string(batchProof.ProofType)),
				Proof:     batchProof.BatchProof,
			}
			subProofs[1] = encoding.SubProof{
				ProofType: encoding.GetProofTypeFromString(string(batchProof.SgxProofType)),
				Proof:     batchProof.SgxBatchProof,
			}
		} else {
			subProofs[0] = encoding.SubProof{
				ProofType: encoding.GetProofTypeFromString(string(batchProof.SgxProofType)),
				Proof:     batchProof.SgxBatchProof,
			}
			subProofs[1] = encoding.SubProof{
				ProofType: encoding.GetProofTypeFromString(string(batchProof.ProofType)),
				Proof:     batchProof.BatchProof,
			}
		}

		combinedProofType := subProofs[0].ProofType + subProofs[1].ProofType
		log.Debug(
			"Combined proof type details",
			"subProof0Type", subProofs[0].ProofType,
			"subProof1Type", subProofs[1].ProofType,
			"combinedProofType", combinedProofType,
		)

		input, err := encoding.EncodeProveBatchesInput(combinedProofType, metas, transitions)
		if err != nil {
			return nil, err
		}
		encodedSubProofs, err := encoding.EncodeBatchesSubProofs(subProofs)
		if err != nil {
			return nil, err
		}

		// Use SurgeProposerWrapper ABI (same interface as TaikoInbox)
		if data, err = encoding.TaikoInboxABI.Pack("proveBatches", input, encodedSubProofs); err != nil {
			return nil, encoding.TryParsingCustomError(err)
		}

		if a.surgeProposerWrapperAddress != rpc.ZeroAddress {
			to = a.surgeProposerWrapperAddress
			log.Info("Using SurgeProposerWrapper for proof submission at proveBatches",
				"surgeProposerWrapper", a.surgeProposerWrapperAddress.Hex(),
				"taikoInbox", a.taikoInboxAddress.Hex())
		} else {
			to = a.taikoInboxAddress
		}

		log.Debug("Transaction data being sent",
			"to", to.Hex(),
			"dataLength", len(data),
			"dataHex", common.Bytes2Hex(data),
			"gasLimit", txOpts.GasLimit,
			"value", txOpts.Value,
			"subProof0Type", subProofs[0].ProofType,
			"subProof0Length", len(subProofs[0].Proof),
			"subProof0Hex", common.Bytes2Hex(subProofs[0].Proof),
			"subProof1Type", subProofs[1].ProofType,
			"subProof1Length", len(subProofs[1].Proof),
			"subProof1Hex", common.Bytes2Hex(subProofs[1].Proof),
			"zkProofType", batchProof.ProofType,
			"sgxProofType", batchProof.SgxProofType,
			"zkBatchProofLength", len(batchProof.BatchProof),
			"sgxBatchProofLength", len(batchProof.SgxBatchProof),
		)

		return &txmgr.TxCandidate{
			TxData:   data,
			To:       &to,
			Blobs:    nil,
			GasLimit: txOpts.GasLimit,
			Value:    txOpts.Value,
		}, nil
	}
}
