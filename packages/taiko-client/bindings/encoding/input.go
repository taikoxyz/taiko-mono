package encoding

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// ABI arguments marshaling components.
var (
	BlockMetadataV2Components = []abi.ArgumentMarshaling{
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
	TransitionComponents = []abi.ArgumentMarshaling{
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
	TierProofComponents = []abi.ArgumentMarshaling{
		{
			Name: "tier",
			Type: "uint16",
		},
		{
			Name: "data",
			Type: "bytes",
		},
	}
	BlockParamsV2Components = []abi.ArgumentMarshaling{
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
	BatchParamsComponents = []abi.ArgumentMarshaling{
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
			Name: "lastBlockTimestamp",
			Type: "uint64",
		},
		{
			Name: "revertIfNotFirstProposal",
			Type: "bool",
		},
		{
			Name: "blobParams",
			Type: "tuple",
			Components: []abi.ArgumentMarshaling{
				{
					Name: "blobHashes",
					Type: "bytes32[]",
				},
				{
					Name: "firstBlobIndex",
					Type: "uint8",
				},
				{
					Name: "numBlobs",
					Type: "uint8",
				},
				{
					Name: "byteOffset",
					Type: "uint32",
				},
				{
					Name: "byteSize",
					Type: "uint32",
				},
				{
					Name: "createdIn",
					Type: "uint64",
				},
			},
		},
		{
			Name: "blocks",
			Type: "tuple[]",
			Components: []abi.ArgumentMarshaling{
				{
					Name: "numTransactions",
					Type: "uint16",
				},
				{
					Name: "timeShift",
					Type: "uint8",
				},
				{
					Name: "signalSlots",
					Type: "bytes32[]",
				},
			},
		},
	}
	BatchMetaDataComponents = []abi.ArgumentMarshaling{
		{
			Name: "infoHash",
			Type: "bytes32",
		},
		{
			Name: "proposer",
			Type: "address",
		},
		{
			Name: "batchId",
			Type: "uint64",
		},
		{
			Name: "proposedAt",
			Type: "uint64",
		},
	}
	BatchTransitionComponents = []abi.ArgumentMarshaling{
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
	}
	SubProofComponents = []abi.ArgumentMarshaling{
		{
			Name: "verifier",
			Type: "address",
		},
		{
			Name: "proof",
			Type: "bytes",
		},
	}
)

var (
	BlockParamsV2ComponentsType, _ = abi.NewType("tuple", "TaikoData.BlockParamsV2", BlockParamsV2Components)
	BlockParamsV2ComponentsArgs    = abi.Arguments{{Name: "TaikoData.BlockParamsV2", Type: BlockParamsV2ComponentsType}}
	BatchParamsComponentsType, _   = abi.NewType("tuple", "ITaikoInbox.BatchParams", BatchParamsComponents)
	BatchParamsComponentsArgs      = abi.Arguments{
		{Name: "ITaikoInbox.BatchParams", Type: BatchParamsComponentsType},
	}
	BlockMetadataV2ComponentsType, _      = abi.NewType("tuple", "TaikoData.BlockMetadataV2", BlockMetadataV2Components)
	BatchMetaDataComponentsArrayType, _   = abi.NewType("tuple[]", "ITaikoInbox.BatchMetadata", BatchMetaDataComponents)
	TransitionComponentsType, _           = abi.NewType("tuple", "TaikoData.Transition", TransitionComponents)
	BatchTransitionComponentsArrayType, _ = abi.NewType("tuple[]", "ITaikoInbox.Transition", BatchTransitionComponents)
	TierProofComponentsType, _            = abi.NewType("tuple", "TaikoData.TierProof", TierProofComponents)
	SubProofsComponentsArrayType, _       = abi.NewType("tuple[]", "ComposeVerifier.SubProof", SubProofComponents)
	SubProofsComponentsArrayArgs          = abi.Arguments{
		{Name: "ComposeVerifier.SubProof[]", Type: SubProofsComponentsArrayType},
	}
	ProveOntakeBlockInputArgs = abi.Arguments{
		{Name: "TaikoData.BlockMetadataV2", Type: BlockMetadataV2ComponentsType},
		{Name: "TaikoData.Transition", Type: TransitionComponentsType},
		{Name: "TaikoData.TierProof", Type: TierProofComponentsType},
	}
	ProveBlocksInputArgs = abi.Arguments{
		{Name: "TaikoData.BlockMetadata", Type: BlockMetadataV2ComponentsType},
		{Name: "TaikoData.Transition", Type: TransitionComponentsType},
	}
	ProveBlocksBatchProofArgs = abi.Arguments{
		{Name: "TaikoData.TierProof", Type: TierProofComponentsType},
	}
	ProveBatchesInputArgs = abi.Arguments{
		{Name: "ITaikoInbox.BlockMetadata[]", Type: BatchMetaDataComponentsArrayType},
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

// Contract ABIs.
var (
	// Ontake fork
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
	ForkRouterABI       *abi.ABI

	// Pacaya fork
	TaikoInboxABI           *abi.ABI
	TaikoWrapperABI         *abi.ABI
	ForcedInclusionStoreABI *abi.ABI
	TaikoAnchorABI          *abi.ABI
	ResloverBaseABI         *abi.ABI
	ComposeVerifierABI      *abi.ABI
	ForkRouterPacayaABI     *abi.ABI
	TaikoTokenPacayaABI     *abi.ABI
	ProverSetPacayaABI      *abi.ABI

	customErrorMaps []map[string]abi.Error
)

func init() {
	var err error

	if TaikoL1ABI, err = ontakeBindings.TaikoL1ClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoL1 ABI error", "error", err)
	}

	if TaikoL2ABI, err = ontakeBindings.TaikoL2ClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoL2 ABI error", "error", err)
	}

	if TaikoTokenABI, err = ontakeBindings.TaikoTokenMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoToken ABI error", "error", err)
	}

	if GuardianProverABI, err = ontakeBindings.GuardianProverMetaData.GetAbi(); err != nil {
		log.Crit("Get GuardianProver ABI error", "error", err)
	}

	if LibProposingABI, err = ontakeBindings.LibProposingMetaData.GetAbi(); err != nil {
		log.Crit("Get LibProposing ABI error", "error", err)
	}

	if LibProvingABI, err = ontakeBindings.LibProvingMetaData.GetAbi(); err != nil {
		log.Crit("Get LibProving ABI error", "error", err)
	}

	if LibUtilsABI, err = ontakeBindings.LibUtilsMetaData.GetAbi(); err != nil {
		log.Crit("Get LibUtils ABI error", "error", err)
	}

	if LibVerifyingABI, err = ontakeBindings.LibVerifyingMetaData.GetAbi(); err != nil {
		log.Crit("Get LibVerifying ABI error", "error", err)
	}

	if SGXVerifierABI, err = ontakeBindings.SgxVerifierMetaData.GetAbi(); err != nil {
		log.Crit("Get SGXVerifier ABI error", err)
	}

	if GuardianVerifierABI, err = ontakeBindings.GuardianVerifierMetaData.GetAbi(); err != nil {
		log.Crit("Get GuardianVerifier ABI error", "error", err)
	}

	if ProverSetABI, err = ontakeBindings.ProverSetMetaData.GetAbi(); err != nil {
		log.Crit("Get ProverSet ABI error", "error", err)
	}

	if ForkRouterABI, err = ontakeBindings.ForkRouterMetaData.GetAbi(); err != nil {
		log.Crit("Get ForkRouter ABI error", "error", err)
	}

	if TaikoInboxABI, err = pacayaBindings.TaikoInboxClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoInbox ABI error", "error", err)
	}

	if TaikoWrapperABI, err = pacayaBindings.TaikoWrapperClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoWrapper ABI error", "error", err)
	}

	if ForcedInclusionStoreABI, err = pacayaBindings.ForcedInclusionStoreMetaData.GetAbi(); err != nil {
		log.Crit("Get ForcedInclusionStore ABI error", "error", err)
	}

	if TaikoAnchorABI, err = pacayaBindings.TaikoAnchorClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoAnchor ABI error", "error", err)
	}

	if ResloverBaseABI, err = pacayaBindings.ResolverBaseMetaData.GetAbi(); err != nil {
		log.Crit("Get ResloverBase ABI error", "error", err)
	}

	if ComposeVerifierABI, err = pacayaBindings.ComposeVerifierMetaData.GetAbi(); err != nil {
		log.Crit("Get ComposeVerifier ABI error", "error", err)
	}

	if ForkRouterPacayaABI, err = pacayaBindings.ForkRouterMetaData.GetAbi(); err != nil {
		log.Crit("Get ForkRouter ABI error", "error", err)
	}

	if TaikoTokenPacayaABI, err = pacayaBindings.TaikoTokenMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoToken ABI error", "error", err)
	}

	if ProverSetPacayaABI, err = pacayaBindings.ProverSetMetaData.GetAbi(); err != nil {
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
		ForkRouterABI.Errors,
		TaikoInboxABI.Errors,
		TaikoWrapperABI.Errors,
		ForcedInclusionStoreABI.Errors,
		TaikoAnchorABI.Errors,
		ResloverBaseABI.Errors,
		ComposeVerifierABI.Errors,
		ForkRouterPacayaABI.Errors,
		TaikoTokenPacayaABI.Errors,
		ProverSetPacayaABI.Errors,
	}
}

// EncodeBlockParamsOntake performs the solidity `abi.encode` for the given ontake blockParams.
func EncodeBlockParamsOntake(params *BlockParamsV2) ([]byte, error) {
	b, err := BlockParamsV2ComponentsArgs.Pack(params)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode ontake block params, %w", err)
	}
	return b, nil
}

// EncodeBatchParamsWithForcedInclusion performs the solidity `abi.encode` for the given two pacaya batchParams.
func EncodeBatchParamsWithForcedInclusion(paramsForcedInclusion, params *BatchParams) ([]byte, error) {
	var (
		x   []byte
		err error
	)
	if paramsForcedInclusion != nil {
		if x, err = BatchParamsComponentsArgs.Pack(paramsForcedInclusion); err != nil {
			return nil, fmt.Errorf("failed to abi.encode pacaya batch params, %w", err)
		}
	}
	y, err := BatchParamsComponentsArgs.Pack(params)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode pacaya batch params, %w", err)
	}
	return batchParamsWithForcedInclusionArgs.Pack(x, y)
}

// EncodeBatchesSubProofs performs the solidity `abi.encode` for the given pacaya batchParams.
func EncodeBatchesSubProofs(subProofs []SubProof) ([]byte, error) {
	b, err := SubProofsComponentsArrayArgs.Pack(subProofs)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode pacaya batch subproofs, %w", err)
	}
	return b, nil
}

// EncodeProveBlockInput performs the solidity `abi.encode` for the given TaikoL1.proveBlock input.
func EncodeProveBlockInput(
	meta metadata.TaikoProposalMetaData,
	transition *ontakeBindings.TaikoDataTransition,
	tierProof *ontakeBindings.TaikoDataTierProof,
) ([]byte, error) {
	var (
		b   []byte
		err error
	)
	if b, err = ProveOntakeBlockInputArgs.Pack(
		meta.(*metadata.TaikoDataBlockMetadataOntake).InnerMetadata(),
		transition,
		tierProof,
	); err != nil {
		return nil, fmt.Errorf("failed to abi.encode TakoL1.proveBlock input after ontake fork, %w", err)
	}

	return b, nil
}

// EncodeProveBlocksInput performs the solidity `abi.encode` for the given TaikoL1.proveBlocks input.
func EncodeProveBlocksInput(
	metas []metadata.TaikoProposalMetaData,
	transitions []ontakeBindings.TaikoDataTransition,
) ([][]byte, error) {
	if len(metas) != len(transitions) {
		return nil, fmt.Errorf("both arrays of TaikoBlockMetaData and TaikoDataTransition must be equal in length")
	}
	b := make([][]byte, 0, len(metas))
	for i := range metas {
		input, err := ProveBlocksInputArgs.Pack(
			metas[i].Ontake().InnerMetadata(),
			transitions[i],
		)
		if err != nil {
			return nil, fmt.Errorf("failed to abi.encode TaikoL1.proveBlocks input item after ontake fork, %w", err)
		}

		b = append(b, input)
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
	input, err := ProveBatchesInputArgs.Pack(
		pacayaMetas,
		transitions,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode TaikoInbox.proveBatches input item after pacaya fork, %w", err)
	}

	return input, nil
}

// EncodeProveBlocksBatchProof performs the solidity `abi.encode` for the given TaikoL1.proveBlocks batchProof.
func EncodeProveBlocksBatchProof(
	tierProof *ontakeBindings.TaikoDataTierProof,
) ([]byte, error) {
	input, err := ProveBlocksBatchProofArgs.Pack(
		tierProof,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode TaikoL1.proveBlocks input item after ontake fork, %w", err)
	}
	return input, nil
}

// CalculatePacayaDifficulty calculates the difficulty for the given pacaya block.
func CalculatePacayaDifficulty(blockNum *big.Int) ([]byte, error) {
	packed, err := PacayaDifficultyInputArgs.Pack("TAIKO_DIFFICULTY", blockNum)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode pacaya difficulty, %w", err)
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
