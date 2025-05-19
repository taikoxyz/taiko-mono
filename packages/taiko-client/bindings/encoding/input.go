package encoding

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// ABI arguments marshaling components.
var (
	// Pacaya components.
	BatchParamsPacayaComponents = []abi.ArgumentMarshaling{
		{Name: "proposer", Type: "address"},
		{Name: "coinbase", Type: "address"},
		{Name: "parentMetaHash", Type: "bytes32"},
		{Name: "anchorBlockId", Type: "uint64"},
		{Name: "lastBlockTimestamp", Type: "uint64"},
		{Name: "revertIfNotFirstProposal", Type: "bool"},
		{
			Name: "blobParams",
			Type: "tuple",
			Components: []abi.ArgumentMarshaling{
				{Name: "blobHashes", Type: "bytes32[]"},
				{Name: "firstBlobIndex", Type: "uint8"},
				{Name: "numBlobs", Type: "uint8"},
				{Name: "byteOffset", Type: "uint32"},
				{Name: "byteSize", Type: "uint32"},
				{Name: "createdIn", Type: "uint64"},
			},
		},
		{
			Name: "blocks",
			Type: "tuple[]",
			Components: []abi.ArgumentMarshaling{
				{Name: "numTransactions", Type: "uint16"},
				{Name: "timeShift", Type: "uint8"},
				{Name: "signalSlots", Type: "bytes32[]"},
			},
		},
	}
	BatchMetaDataPacayaComponents = []abi.ArgumentMarshaling{
		{Name: "infoHash", Type: "bytes32"},
		{Name: "proposer", Type: "address"},
		{Name: "batchId", Type: "uint64"},
		{Name: "proposedAt", Type: "uint64"},
	}
)

var (
	// Shasta components.
	BatchParamsShastaComponents = []abi.ArgumentMarshaling{
		{Name: "proposer", Type: "address"},
		{Name: "coinbase", Type: "address"},
		{Name: "parentMetaHash", Type: "bytes32"},
		{Name: "anchorBlockId", Type: "uint64"},
		{Name: "lastBlockTimestamp", Type: "uint64"},
		{Name: "revertIfNotFirstProposal", Type: "bool"},
		{
			Name: "blobParams",
			Type: "tuple",
			Components: []abi.ArgumentMarshaling{
				{Name: "blobHashes", Type: "bytes32[]"},
				{Name: "firstBlobIndex", Type: "uint8"},
				{Name: "numBlobs", Type: "uint8"},
				{Name: "byteOffset", Type: "uint32"},
				{Name: "byteSize", Type: "uint32"},
				{Name: "createdIn", Type: "uint64"},
			},
		},
		{
			Name: "blocks",
			Type: "tuple[]",
			Components: []abi.ArgumentMarshaling{
				{Name: "numTransactions", Type: "uint16"},
				{Name: "timeShift", Type: "uint8"},
				{Name: "signalSlots", Type: "bytes32[]"},
			},
		},
		{Name: "proverAuth", Type: "bytes"},
	}
)

var (
	// Shared components
	BatchMetaDataShastaComponents = []abi.ArgumentMarshaling{
		{Name: "infoHash", Type: "bytes32"},
		{Name: "prover", Type: "address"},
		{Name: "batchId", Type: "uint64"},
		{Name: "proposedAt", Type: "uint64"},
	}
	BatchTransitionComponents = []abi.ArgumentMarshaling{
		{Name: "parentHash", Type: "bytes32"},
		{Name: "blockHash", Type: "bytes32"},
		{Name: "stateRoot", Type: "bytes32"},
	}
	SubProofComponents = []abi.ArgumentMarshaling{
		{Name: "verifier", Type: "address"},
		{Name: "proof", Type: "bytes"},
	}
)

var (
	// Pacaya arguments.
	BatchParamsPacayaComponentsType, _ = abi.NewType("tuple", "ITaikoInbox.BatchParams", BatchParamsPacayaComponents)
	BatchParamsPacayaComponentsArgs    = abi.Arguments{
		{Name: "ITaikoInbox.BatchParams", Type: BatchParamsPacayaComponentsType},
	}
	BatchMetaDataPacayaComponentsArrayType, _ = abi.NewType(
		"tuple[]", "ITaikoInbox.BatchMetadata", BatchMetaDataPacayaComponents,
	)
)

var (
	// Shasta arguments.
	BatchParamsShastaComponentsType, _ = abi.NewType("tuple", "ITaikoInbox.BatchParams", BatchParamsShastaComponents)
	BatchParamsShastaComponentsArgs    = abi.Arguments{
		{Name: "ITaikoInbox.BatchParams", Type: BatchParamsShastaComponentsType},
	}
	BatchMetaDataShastaComponentsArrayType, _ = abi.NewType(
		"tuple[]", "ITaikoInbox.BatchMetadata", BatchMetaDataShastaComponents,
	)
)

var (
	// Shared arguments.
	BatchTransitionComponentsArrayType, _ = abi.NewType("tuple[]", "ITaikoInbox.Transition", BatchTransitionComponents)
	SubProofsComponentsArrayType, _       = abi.NewType("tuple[]", "ComposeVerifier.SubProof", SubProofComponents)
	SubProofsComponentsArrayArgs          = abi.Arguments{
		{Name: "ComposeVerifier.SubProof[]", Type: SubProofsComponentsArrayType},
	}
	ProveBatchesInputArgs = abi.Arguments{
		{Name: "ITaikoInbox.BlockMetadata[]", Type: BatchMetaDataPacayaComponentsArrayType},
		{Name: "TaikoData.Transition[]", Type: BatchTransitionComponentsArrayType},
	}
	stringType, _             = abi.NewType("string", "", nil)
	uint256Type, _            = abi.NewType("uint256", "", nil)
	bytesType, _              = abi.NewType("bytes", "", nil)
	PacayaDifficultyInputArgs = abi.Arguments{
		{Name: "TAIKO_DIFFICULTY", Type: stringType},
		{Name: "block.number", Type: uint256Type},
	}
	batchParamsWithForcedInclusionArgs = abi.Arguments{
		{Name: "bytesX", Type: bytesType},
		{Name: "bytesY", Type: bytesType},
	}
)

// EncodeBatchParamsPacayaWithForcedInclusion performs the solidity `abi.encode` for the given two Pacaya batchParams.
func EncodeBatchParamsPacayaWithForcedInclusion(paramsForcedInclusion, params *BatchParamsPacaya) ([]byte, error) {
	var (
		x   []byte
		err error
	)
	if paramsForcedInclusion != nil {
		if x, err = BatchParamsPacayaComponentsArgs.Pack(paramsForcedInclusion); err != nil {
			return nil, fmt.Errorf("failed to abi.encode Pacaya batch params, %w", err)
		}
	}
	y, err := BatchParamsPacayaComponentsArgs.Pack(params)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode Pacaya batch params, %w", err)
	}
	return batchParamsWithForcedInclusionArgs.Pack(x, y)
}

// EncodeBatchParamsShastaWithForcedInclusion performs the solidity `abi.encode` for the given two Shasta batchParams.
func EncodeBatchParamsShastaWithForcedInclusion(paramsForcedInclusion, params *BatchParamsShasta) ([]byte, error) {
	var (
		x   []byte
		err error
	)
	if paramsForcedInclusion != nil {
		if x, err = BatchParamsShastaComponentsArgs.Pack(paramsForcedInclusion); err != nil {
			return nil, fmt.Errorf("failed to abi.encode Shasta batch params, %w", err)
		}
	}
	y, err := BatchParamsShastaComponentsArgs.Pack(params)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode Shasta batch params, %w", err)
	}
	return batchParamsWithForcedInclusionArgs.Pack(x, y)
}

// EncodeBatchesSubProofs performs the solidity `abi.encode` for the given Pacaya batchParams.
func EncodeBatchesSubProofs(subProofs []SubProof) ([]byte, error) {
	b, err := SubProofsComponentsArrayArgs.Pack(subProofs)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode Pacaya batch subproofs, %w", err)
	}
	return b, nil
}

// EncodeProveBatchesInput performs the solidity `abi.encode` for the given TaikoInbox.proveBatches input.
func EncodeProveBatchesInput(
	metas []metadata.TaikoProposalMetaData,
	transitions []pacayaBindings.ITaikoInboxTransition,
) ([]byte, error) {
	if len(metas) != len(transitions) {
		return nil, fmt.Errorf("both arrays of TaikoBlockMetaData and TaikoInboxTransition must be equal in length")
	}
	pacayaMetas := make([]pacayaBindings.ITaikoInboxBatchMetadata, 0)
	for i := range metas {
		pacayaMetas = append(pacayaMetas, pacayaBindings.ITaikoInboxBatchMetadata{
			InfoHash:   metas[i].Pacaya().InnerMetadata().InfoHash,
			Proposer:   metas[i].Pacaya().GetProposer(),
			BatchId:    metas[i].Pacaya().GetBatchID().Uint64(),
			ProposedAt: metas[i].Pacaya().GetProposedAt(),
		})
	}
	input, err := ProveBatchesInputArgs.Pack(pacayaMetas, transitions)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode TaikoInbox.proveBatches input item after pacaya fork, %w", err)
	}

	return input, nil
}

// CalculatePacayaDifficulty calculates the difficulty for the given Pacaya block.
func CalculatePacayaDifficulty(blockNum *big.Int) ([]byte, error) {
	packed, err := PacayaDifficultyInputArgs.Pack("TAIKO_DIFFICULTY", blockNum)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode Pacaya difficulty, %w", err)
	}

	return crypto.Keccak256(packed), nil
}

// EncodeBaseFeeConfig encodes the block.extraData field from the given base fee config.
func EncodeBaseFeeConfig(baseFeeConfig *pacayaBindings.LibSharedDataBaseFeeConfig) [32]byte {
	var (
		bytes32Value [32]byte
		uintValue    = new(big.Int).SetUint64(uint64(baseFeeConfig.SharingPctg))
	)
	copy(bytes32Value[32-len(uintValue.Bytes()):], uintValue.Bytes())
	return bytes32Value
}
