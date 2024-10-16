package encoding

import (
	"errors"
	"fmt"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

// ABI arguments marshaling components.
var (
	blockMetadataComponents = []abi.ArgumentMarshaling{
		{
			Name: "l1Hash",
			Type: "bytes32",
		},
		{
			Name: "difficulty",
			Type: "bytes32",
		},
		{
			Name: "blobHash",
			Type: "bytes32",
		},
		{
			Name: "extraData",
			Type: "bytes32",
		},
		{
			Name: "depositsHash",
			Type: "bytes32",
		},
		{
			Name: "coinbase",
			Type: "address",
		},
		{
			Name: "id",
			Type: "uint64",
		},
		{
			Name: "gasLimit",
			Type: "uint32",
		},
		{
			Name: "timestamp",
			Type: "uint64",
		},
		{
			Name: "l1Height",
			Type: "uint64",
		},
		{
			Name: "minTier",
			Type: "uint16",
		},
		{
			Name: "blobUsed",
			Type: "bool",
		},
		{
			Name: "parentMetaHash",
			Type: "bytes32",
		},
		{
			Name: "sender",
			Type: "address",
		},
	}
	blockMetadataV2Components = []abi.ArgumentMarshaling{
		{
			Name: "anchorBlockHash",
			Type: "bytes32",
		},
		{
			Name: "difficulty",
			Type: "bytes32",
		},
		{
			Name: "blobHash",
			Type: "bytes32",
		},
		{
			Name: "extraData",
			Type: "bytes32",
		},
		{
			Name: "coinbase",
			Type: "address",
		},
		{
			Name: "id",
			Type: "uint64",
		},
		{
			Name: "gasLimit",
			Type: "uint32",
		},
		{
			Name: "timestamp",
			Type: "uint64",
		},
		{
			Name: "anchorBlockId",
			Type: "uint64",
		},
		{
			Name: "minTier",
			Type: "uint16",
		},
		{
			Name: "blobUsed",
			Type: "bool",
		},
		{
			Name: "parentMetaHash",
			Type: "bytes32",
		},
		{
			Name: "proposer",
			Type: "address",
		},
		{
			Name: "livenessBond",
			Type: "uint96",
		},
		{
			Name: "proposedAt",
			Type: "uint64",
		},
		{
			Name: "proposedIn",
			Type: "uint64",
		},
		{
			Name: "blobTxListOffset",
			Type: "uint32",
		},
		{
			Name: "blobTxListLength",
			Type: "uint32",
		},
		{
			Name: "blobIndex",
			Type: "uint8",
		},
		{
			Name: "baseFeeConfig",
			Type: "tuple",
			Components: []abi.ArgumentMarshaling{
				{
					Name: "adjustmentQuotient",
					Type: "uint8",
				},
				{
					Name: "sharingPctg",
					Type: "uint8",
				},
				{
					Name: "gasIssuancePerSecond",
					Type: "uint32",
				},
				{
					Name: "minGasExcess",
					Type: "uint64",
				},
				{
					Name: "maxGasIssuancePerBlock",
					Type: "uint32",
				},
			},
		},
	}
	transitionComponents = []abi.ArgumentMarshaling{
		{
			Name: "parentHash",
			Type: "bytes32",
		},
		{
			Name: "blockHash",
			Type: "bytes32",
		},
		{
			Name: "stateRoot",
			Type: "bytes32",
		},
		{
			Name: "graffiti",
			Type: "bytes32",
		},
	}
	tierProofComponents = []abi.ArgumentMarshaling{
		{
			Name: "tier",
			Type: "uint16",
		},
		{
			Name: "data",
			Type: "bytes",
		},
	}
	blockParamsComponents = []abi.ArgumentMarshaling{
		{
			Name: "assignedProver",
			Type: "address",
		},
		{
			Name: "coinbase",
			Type: "address",
		},
		{
			Name: "extraData",
			Type: "bytes32",
		},
		{
			Name: "parentMetaHash",
			Type: "bytes32",
		},
		{
			Name: "hookCalls",
			Type: "tuple[]",
			Components: []abi.ArgumentMarshaling{
				{
					Name: "hook",
					Type: "address",
				},
				{
					Name: "data",
					Type: "bytes",
				},
			},
		},
		{
			Name: "signature",
			Type: "bytes",
		},
	}
	blockParamsV2Components = []abi.ArgumentMarshaling{
		{
			Name: "proposer",
			Type: "address",
		},
		{
			Name: "coinbase",
			Type: "address",
		},
		{
			Name: "parentMetaHash",
			Type: "bytes32",
		},
		{
			Name: "anchorBlockId",
			Type: "uint64",
		},
		{
			Name: "timestamp",
			Type: "uint64",
		},
		{
			Name: "blobTxListOffset",
			Type: "uint32",
		},
		{
			Name: "blobTxListLength",
			Type: "uint32",
		},
		{
			Name: "blobIndex",
			Type: "uint8",
		},
	}
)

var (
	blockParamsComponentsType, _     = abi.NewType("tuple", "TaikoData.BlockParams", blockParamsComponents)
	blockParamsComponentsArgs        = abi.Arguments{{Name: "TaikoData.BlockParams", Type: blockParamsComponentsType}}
	blockParamsV2ComponentsType, _   = abi.NewType("tuple", "TaikoData.BlockParamsV2", blockParamsV2Components)
	blockParamsV2ComponentsArgs      = abi.Arguments{{Name: "TaikoData.BlockParamsV2", Type: blockParamsV2ComponentsType}}
	blockMetadataComponentsType, _   = abi.NewType("tuple", "TaikoData.BlockMetadata", blockMetadataComponents)
	blockMetadataV2ComponentsType, _ = abi.NewType("tuple", "TaikoData.BlockMetadataV2", blockMetadataV2Components)
	transitionComponentsType, _      = abi.NewType("tuple", "TaikoData.Transition", transitionComponents)
	tierProofComponentsType, _       = abi.NewType("tuple", "TaikoData.TierProof", tierProofComponents)
	proveBlockInputArgs              = abi.Arguments{
		{Name: "TaikoData.BlockMetadata", Type: blockMetadataComponentsType},
		{Name: "TaikoData.Transition", Type: transitionComponentsType},
		{Name: "TaikoData.TierProof", Type: tierProofComponentsType},
	}
	proveOntakeBlockInputArgs = abi.Arguments{
		{Name: "TaikoData.BlockMetadataV2", Type: blockMetadataV2ComponentsType},
		{Name: "TaikoData.Transition", Type: transitionComponentsType},
		{Name: "TaikoData.TierProof", Type: tierProofComponentsType},
	}
	proveBlocksInputArgs = abi.Arguments{
		{Name: "TaikoData.BlockMetadata", Type: blockMetadataV2ComponentsType},
		{Name: "TaikoData.Transition", Type: transitionComponentsType},
	}
	proveBlocksBatchProofArgs = abi.Arguments{
		{Name: "TaikoData.TierProof", Type: tierProofComponentsType},
	}
)

// Contract ABIs.
var (
	TaikoL1ABI          *abi.ABI
	TaikoL2ABI          *abi.ABI
	TaikoTokenABI       *abi.ABI
	GuardianProverABI   *abi.ABI
	LibProposingABI     *abi.ABI
	LibProvingABI       *abi.ABI
	LibUtilsABI         *abi.ABI
	LibVerifyingABI     *abi.ABI
	SGXVerifierABI      *abi.ABI
	GuardianVerifierABI *abi.ABI
	ProverSetABI        *abi.ABI

	customErrorMaps []map[string]abi.Error
)

func init() {
	var err error

	if TaikoL1ABI, err = bindings.TaikoL1ClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoL1 ABI error", "error", err)
	}

	if TaikoL2ABI, err = bindings.TaikoL2ClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoL2 ABI error", "error", err)
	}

	if TaikoTokenABI, err = bindings.TaikoTokenMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoToken ABI error", "error", err)
	}

	if GuardianProverABI, err = bindings.GuardianProverMetaData.GetAbi(); err != nil {
		log.Crit("Get GuardianProver ABI error", "error", err)
	}

	if LibProposingABI, err = bindings.LibProposingMetaData.GetAbi(); err != nil {
		log.Crit("Get LibProposing ABI error", "error", err)
	}

	if LibProvingABI, err = bindings.LibProvingMetaData.GetAbi(); err != nil {
		log.Crit("Get LibProving ABI error", "error", err)
	}

	if LibUtilsABI, err = bindings.LibUtilsMetaData.GetAbi(); err != nil {
		log.Crit("Get LibUtils ABI error", "error", err)
	}

	if LibVerifyingABI, err = bindings.LibVerifyingMetaData.GetAbi(); err != nil {
		log.Crit("Get LibVerifying ABI error", "error", err)
	}

	if SGXVerifierABI, err = bindings.SgxVerifierMetaData.GetAbi(); err != nil {
		log.Crit("Get SGXVerifier ABI error", err)
	}

	if GuardianVerifierABI, err = bindings.GuardianVerifierMetaData.GetAbi(); err != nil {
		log.Crit("Get GuardianVerifier ABI error", "error", err)
	}

	if ProverSetABI, err = bindings.ProverSetMetaData.GetAbi(); err != nil {
		log.Crit("Get ProverSet ABI error", "error", err)
	}

	customErrorMaps = []map[string]abi.Error{
		TaikoL1ABI.Errors,
		TaikoL2ABI.Errors,
		GuardianProverABI.Errors,
		LibProposingABI.Errors,
		LibProvingABI.Errors,
		LibUtilsABI.Errors,
		LibVerifyingABI.Errors,
		SGXVerifierABI.Errors,
		GuardianVerifierABI.Errors,
		ProverSetABI.Errors,
	}
}

// EncodeBlockParams performs the solidity `abi.encode` for the given blockParams.
func EncodeBlockParams(params *BlockParams) ([]byte, error) {
	b, err := blockParamsComponentsArgs.Pack(params)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode block params, %w", err)
	}
	return b, nil
}

// EncodeBlockParamsOntake performs the solidity `abi.encode` for the given ontake blockParams.
func EncodeBlockParamsOntake(params *BlockParamsV2) ([]byte, error) {
	b, err := blockParamsV2ComponentsArgs.Pack(params)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode ontake block params, %w", err)
	}
	return b, nil
}

// EncodeProveBlockInput performs the solidity `abi.encode` for the given TaikoL1.proveBlock input.
func EncodeProveBlockInput(
	meta metadata.TaikoBlockMetaData,
	transition *bindings.TaikoDataTransition,
	tierProof *bindings.TaikoDataTierProof,
) ([]byte, error) {
	var (
		b   []byte
		err error
	)
	if meta.IsOntakeBlock() {
		if b, err = proveOntakeBlockInputArgs.Pack(
			meta.(*metadata.TaikoDataBlockMetadataOntake).InnerMetadata(),
			transition,
			tierProof,
		); err != nil {
			return nil, fmt.Errorf("failed to abi.encode TakoL1.proveBlock input after ontake fork, %w", err)
		}
	} else {
		if b, err = proveBlockInputArgs.Pack(
			meta.(*metadata.TaikoDataBlockMetadataLegacy).InnerMetadata(),
			transition,
			tierProof,
		); err != nil {
			return nil, fmt.Errorf("failed to abi.encode TakoL1.proveBlock input, %w", err)
		}
	}

	return b, nil
}

// EncodeProveBlocksInput performs the solidity `abi.encode` for the given TaikoL1.proveBlocks input.
func EncodeProveBlocksInput(
	metas []metadata.TaikoBlockMetaData,
	transitions []bindings.TaikoDataTransition,
) ([][]byte, error) {
	if len(metas) != len(transitions) {
		return nil, fmt.Errorf("both arrays of TaikoBlockMetaData and TaikoDataTransition must be equal in length")
	}
	b := make([][]byte, 0, len(metas))
	for i := range metas {
		input, err := proveBlocksInputArgs.Pack(
			metas[i].(*metadata.TaikoDataBlockMetadataOntake).InnerMetadata(),
			transitions[i],
		)
		if err != nil {
			return nil, fmt.Errorf("failed to abi.encode TaikoL1.proveBlocks input item after ontake fork, %w", err)
		}

		b = append(b, input)
	}

	return b, nil
}

// EncodeProveBlocksBatchProof performs the solidity `abi.encode` for the given TaikoL1.proveBlocks batchProof.
func EncodeProveBlocksBatchProof(
	tierProof *bindings.TaikoDataTierProof,
) ([]byte, error) {
	input, err := proveBlocksBatchProofArgs.Pack(
		tierProof,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode TaikoL1.proveBlocks input item after ontake fork, %w", err)
	}
	return input, nil
}

// UnpackTxListBytes unpacks the input data of a TaikoL1.proposeBlock transaction, and returns the txList bytes.
func UnpackTxListBytes(txData []byte) ([]byte, error) {
	method, err := TaikoL1ABI.MethodById(txData)
	if err != nil {
		return nil, err
	}

	// Only check for safety.
	if method.Name != "proposeBlock" {
		return nil, fmt.Errorf("invalid method name: %s", method.Name)
	}

	args := map[string]interface{}{}

	if err := method.Inputs.UnpackIntoMap(args, txData[4:]); err != nil {
		return nil, err
	}

	inputs, ok := args["_txList"].([]byte)

	if !ok {
		return nil, errors.New("failed to get txList bytes")
	}

	return inputs, nil
}
