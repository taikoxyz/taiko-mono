package encoding

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
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
		{
			Name: "blobTxListOffset",
			Type: "uint32",
		},
		{
			Name: "blobTxListLength",
			Type: "uint32",
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
		{
			Name: "l1StateBlockNumber",
			Type: "uint32",
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
	proverAssignmentComponents = []abi.ArgumentMarshaling{
		{
			Name: "feeToken",
			Type: "address",
		},
		{
			Name: "expiry",
			Type: "uint64",
		},
		{
			Name: "maxBlockId",
			Type: "uint64",
		},
		{
			Name: "maxProposedIn",
			Type: "uint64",
		},
		{
			Name: "metaHash",
			Type: "bytes32",
		},
		{
			Name: "parentMetaHash",
			Type: "bytes32",
		},
		{
			Name: "tierFees",
			Type: "tuple[]",
			Components: []abi.ArgumentMarshaling{
				{
					Name: "tier",
					Type: "uint16",
				},
				{
					Name: "fee",
					Type: "uint128",
				},
			},
		},
		{
			Name: "signature",
			Type: "bytes",
		},
	}
	assignmentHookInputComponents = []abi.ArgumentMarshaling{
		{
			Name:       "assignment",
			Type:       "tuple",
			Components: proverAssignmentComponents,
		},
		{
			Name: "tip",
			Type: "uint256",
		},
	}
)

var (
	assignmentHookInputType, _   = abi.NewType("tuple", "AssignmentHook.Input", assignmentHookInputComponents)
	assignmentHookInputArgs      = abi.Arguments{{Name: "AssignmentHook.Input", Type: assignmentHookInputType}}
	blockParamsComponentsType, _ = abi.NewType("tuple", "TaikoData.BlockParams", blockParamsComponents)
	blockParamsComponentsArgs    = abi.Arguments{{Name: "TaikoData.BlockParams", Type: blockParamsComponentsType}}
	// ProverAssignmentPayload
	bytes32Type, _  = abi.NewType("bytes32", "", nil)
	addressType, _  = abi.NewType("address", "", nil)
	uint64Type, _   = abi.NewType("uint64", "", nil)
	tierFeesType, _ = abi.NewType(
		"tuple[]",
		"",
		[]abi.ArgumentMarshaling{
			{
				Name: "tier",
				Type: "uint16",
			},
			{
				Name: "fee",
				Type: "uint128",
			},
		},
	)
	proverAssignmentHashPayloadArgs = abi.Arguments{
		{Name: "_assignment.metaHash", Type: bytes32Type},
		{Name: "_assignment.parentMetaHash", Type: bytes32Type},
		{Name: "_assignment.feeToken", Type: addressType},
		{Name: "_assignment.expiry", Type: uint64Type},
		{Name: "_assignment.maxBlockId", Type: uint64Type},
		{Name: "_assignment.maxProposedIn", Type: uint64Type},
		{Name: "_assignment.tierFees", Type: tierFeesType},
	}
	blockMetadataComponentsType, _ = abi.NewType("tuple", "TaikoData.BlockMetadata", blockMetadataComponents)
	transitionComponentsType, _    = abi.NewType("tuple", "TaikoData.Transition", transitionComponents)
	tierProofComponentsType, _     = abi.NewType("tuple", "TaikoData.TierProof", tierProofComponents)
	proveBlockInputArgs            = abi.Arguments{
		{Name: "TaikoData.BlockMetadata", Type: blockMetadataComponentsType},
		{Name: "TaikoData.Transition", Type: transitionComponentsType},
		{Name: "TaikoData.TierProof", Type: tierProofComponentsType},
	}
)

// Contract ABIs.
var (
	TaikoL1ABI           *abi.ABI
	TaikoL2ABI           *abi.ABI
	TaikoTokenABI        *abi.ABI
	GuardianProverABI    *abi.ABI
	LibProposingABI      *abi.ABI
	LibProvingABI        *abi.ABI
	LibUtilsABI          *abi.ABI
	LibVerifyingABI      *abi.ABI
	AssignmentHookABI    *abi.ABI
	SGXVerifierABI       *abi.ABI
	GuardianVerifierABI  *abi.ABI
	ProverSetABI         *abi.ABI
	SequencerRegistryABI *abi.ABI

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

	if AssignmentHookABI, err = bindings.AssignmentHookMetaData.GetAbi(); err != nil {
		log.Crit("Get AssignmentHook ABI error", "error", err)
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

	if SequencerRegistryABI, err = bindings.SequencerRegistryMetaData.GetAbi(); err != nil {
		log.Crit("Get SequencerRegistry ABI error", "error", err)
	}

	customErrorMaps = []map[string]abi.Error{
		TaikoL1ABI.Errors,
		TaikoL2ABI.Errors,
		GuardianProverABI.Errors,
		LibProposingABI.Errors,
		LibProvingABI.Errors,
		LibUtilsABI.Errors,
		LibVerifyingABI.Errors,
		AssignmentHookABI.Errors,
		SGXVerifierABI.Errors,
		GuardianVerifierABI.Errors,
		ProverSetABI.Errors,
		SequencerRegistryABI.Errors,
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

// EncodeAssignmentHookInput performs the solidity `abi.encode` for the given input
func EncodeAssignmentHookInput(input *AssignmentHookInput) ([]byte, error) {
	b, err := assignmentHookInputArgs.Pack(input)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode assignment hook input params, %w", err)
	}
	return b, nil
}

// EncodeProverAssignmentPayload performs the solidity `abi.encode` for the given proverAssignment payload.
func EncodeProverAssignmentPayload(
	chainID uint64,
	taikoAddress common.Address,
	assignmentHookAddress common.Address,
	blockProposer common.Address,
	assignedProver common.Address,
	blobHash common.Hash,
	feeToken common.Address,
	expiry uint64,
	maxBlockID uint64,
	maxProposedIn uint64,
	tierFees []TierFee,
) ([]byte, error) {
	hashBytesPayload, err := proverAssignmentHashPayloadArgs.Pack(
		common.Hash{},
		common.Hash{},
		feeToken,
		expiry,
		maxBlockID,
		maxProposedIn,
		tierFees,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode prover assignment hash payload, %w", err)
	}

	chainIDBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(chainIDBytes, chainID)

	return bytes.Join([][]byte{
		common.RightPadBytes([]byte("PROVER_ASSIGNMENT"), 32),
		chainIDBytes,
		taikoAddress.Bytes(),
		blockProposer.Bytes(),
		assignedProver.Bytes(),
		blobHash.Bytes(),
		crypto.Keccak256Hash(hashBytesPayload).Bytes(),
		assignmentHookAddress.Bytes(),
	}, nil), nil
}

// EncodeProveBlockInput performs the solidity `abi.encode` for the given TaikoL1.proveBlock input.
func EncodeProveBlockInput(
	meta *bindings.TaikoDataBlockMetadata,
	transition *bindings.TaikoDataTransition,
	tierProof *bindings.TaikoDataTierProof,
) ([]byte, error) {
	b, err := proveBlockInputArgs.Pack(meta, transition, tierProof)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode TakoL1.proveBlock input, %w", err)
	}
	return b, nil
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
