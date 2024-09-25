package transaction

import (
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var (
	ErrUnretryableSubmission = errors.New("unretryable submission error")
	ZeroAddress              common.Address
)

// TxBuilder will build a transaction with the given nonce.
type TxBuilder func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error)

// ProveBlockTxBuilder is responsible for building ProveBlock transactions.
type ProveBlockTxBuilder struct {
	rpc                           *rpc.Client
	taikoL1Address                common.Address
	proverSetAddress              common.Address
	guardianProverMajorityAddress common.Address
	guardianProverMinorityAddress common.Address
}

// NewProveBlockTxBuilder creates a new ProveBlockTxBuilder instance.
func NewProveBlockTxBuilder(
	rpc *rpc.Client,
	taikoL1Address common.Address,
	proverSetAddress common.Address,
	guardianProverMajorityAddress common.Address,
	guardianProverMinorityAddress common.Address,
) *ProveBlockTxBuilder {
	return &ProveBlockTxBuilder{
		rpc,
		taikoL1Address,
		proverSetAddress,
		guardianProverMajorityAddress,
		guardianProverMinorityAddress,
	}
}

// Build creates a new TaikoL1.ProveBlock transaction with the given nonce.
func (a *ProveBlockTxBuilder) Build(
	blockID *big.Int,
	meta metadata.TaikoBlockMetaData,
	transition *bindings.TaikoDataTransition,
	tierProof *bindings.TaikoDataTierProof,
	tier uint16,
) TxBuilder {
	return func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error) {
		var (
			data     []byte
			to       common.Address
			err      error
			guardian = tier >= encoding.TierGuardianMinorityID
		)

		log.Info(
			"Build proof submission transaction",
			"blockID", blockID,
			"gasLimit", txOpts.GasLimit,
			"guardian", guardian,
		)

		if !guardian {
			input, err := encoding.EncodeProveBlockInput(meta, transition, tierProof)
			if err != nil {
				return nil, err
			}

			if meta.IsOntakeBlock() {
				if a.proverSetAddress != ZeroAddress {
					if data, err = encoding.ProverSetABI.Pack(
						"proveBlocks",
						[]uint64{blockID.Uint64()},
						[][]byte{input},
						[]byte{},
					); err != nil {
						return nil, err
					}
					to = a.proverSetAddress
				} else {
					if data, err = encoding.TaikoL1ABI.Pack(
						"proveBlocks",
						[]uint64{blockID.Uint64()},
						[][]byte{input},
						[]byte{},
					); err != nil {
						return nil, err
					}
					to = a.taikoL1Address
				}
			} else {
				if a.proverSetAddress != ZeroAddress {
					if data, err = encoding.ProverSetABI.Pack("proveBlock", blockID.Uint64(), input); err != nil {
						return nil, err
					}
					to = a.proverSetAddress
				} else {
					if data, err = encoding.TaikoL1ABI.Pack("proveBlock", blockID.Uint64(), input); err != nil {
						return nil, err
					}
					to = a.taikoL1Address
				}
			}
		} else {
			if tier > encoding.TierGuardianMinorityID {
				to = a.guardianProverMajorityAddress
			} else if tier == encoding.TierGuardianMinorityID && a.guardianProverMinorityAddress != ZeroAddress {
				to = a.guardianProverMinorityAddress
			} else {
				return nil, fmt.Errorf("tier %d need set guardianProverMinorityAddress", tier)
			}

			if meta.IsOntakeBlock() {
				if data, err = encoding.GuardianProverABI.Pack(
					"approveV2",
					meta.(*metadata.TaikoDataBlockMetadataOntake).InnerMetadata(),
					*transition,
					*tierProof,
				); err != nil {
					return nil, err
				}
			} else {
				if data, err = encoding.GuardianProverABI.Pack(
					"approve",
					meta.(*metadata.TaikoDataBlockMetadataLegacy).InnerMetadata(),
					*transition,
					*tierProof,
				); err != nil {
					return nil, err
				}
			}
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

// BuildProveBlocks creates a new TaikoL1.ProveBlocks transaction with the given nonce.
func (a *ProveBlockTxBuilder) BuildProveBlocks(
	batchProof *proofProducer.BatchProofs,
) TxBuilder {
	return func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error) {
		var (
			data        []byte
			to          common.Address
			err         error
			metas       = make([]metadata.TaikoBlockMetaData, len(batchProof.Proofs))
			transitions = make([]bindings.TaikoDataTransition, len(batchProof.Proofs))
			blockIDs    = make([]*big.Int, len(batchProof.Proofs))
		)
		for i, proof := range batchProof.Proofs {
			metas[i] = proof.Meta
			transitions[i] = bindings.TaikoDataTransition{
				ParentHash: proof.Header.ParentHash,
				BlockHash:  proof.Opts.BlockHash,
				StateRoot:  proof.Opts.StateRoot,
				Graffiti:   rpc.StringToBytes32(proof.Opts.Graffiti),
			}
			blockIDs[i] = proof.BlockID
		}
		log.Info(
			"Build batch proof submission transaction",
			"blockIDs", blockIDs,
			"gasLimit", txOpts.GasLimit,
		)
		input, err := encoding.EncodeProveBlocksInput(metas, transitions)
		if err != nil {
			return nil, err
		}

		if a.proverSetAddress != ZeroAddress {
			if data, err = encoding.ProverSetABI.Pack(
				"proveBlocks",
				blockIDs,
				input,
				batchProof.BatchProof,
			); err != nil {
				return nil, err
			}
			to = a.proverSetAddress
		} else {
			if data, err = encoding.TaikoL1ABI.Pack(
				"proveBlocks",
				blockIDs,
				input,
				batchProof.BatchProof,
			); err != nil {
				return nil, err
			}
			to = a.taikoL1Address
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
