package encoding

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// ABI arguments marshaling components.
var (
	BatchParamsComponents = []abi.ArgumentMarshaling{
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
	BatchMetaDataComponents = []abi.ArgumentMarshaling{
		{Name: "infoHash", Type: "bytes32"},
		{Name: "proposer", Type: "address"},
		{Name: "batchId", Type: "uint64"},
		{Name: "proposedAt", Type: "uint64"},
	}
	BatchTransitionComponents = []abi.ArgumentMarshaling{
		{Name: "parentHash", Type: "bytes32"},
		{Name: "blockHash", Type: "bytes32"},
		{Name: "stateRoot", Type: "bytes32"},
	}
	SubProofPacayaComponents = []abi.ArgumentMarshaling{
		{Name: "verifier", Type: "address"},
		{Name: "proof", Type: "bytes"},
	}
	SubProofShastaComponents = []abi.ArgumentMarshaling{
		{Name: "verifierId", Type: "uint8"},
		{Name: "proof", Type: "bytes"},
	}
)

var (
	BatchParamsComponentsType, _ = abi.NewType("tuple", "ITaikoInbox.BatchParams", BatchParamsComponents)
	BatchParamsComponentsArgs    = abi.Arguments{
		{Name: "ITaikoInbox.BatchParams", Type: BatchParamsComponentsType},
	}
	BatchMetaDataComponentsArrayType, _   = abi.NewType("tuple[]", "ITaikoInbox.BatchMetadata", BatchMetaDataComponents)
	BatchTransitionComponentsArrayType, _ = abi.NewType("tuple[]", "ITaikoInbox.Transition", BatchTransitionComponents)
	SubProofsPacayaComponentsArrayType, _ = abi.NewType("tuple[]", "ComposeVerifier.SubProof", SubProofPacayaComponents)
	SubProofsShastaComponentsArrayType, _ = abi.NewType("tuple[]", "ComposeVerifier.SubProof", SubProofShastaComponents)
	SubProofsPacayaComponentsArrayArgs    = abi.Arguments{
		{Name: "ComposeVerifier.SubProof[]", Type: SubProofsPacayaComponentsArrayType},
	}
	SubProofsShastaComponentsArrayArgs = abi.Arguments{
		{Name: "ComposeVerifier.SubProof[]", Type: SubProofsShastaComponentsArrayType},
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
	ShastaDifficultyInputArgs = abi.Arguments{
		{Name: "parent.metadata.difficulty", Type: uint256Type},
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
	TaikoL1ABI      *abi.ABI
	TaikoL2ABI      *abi.ABI
	TaikoTokenABI   *abi.ABI
	LibProposingABI *abi.ABI
	LibProvingABI   *abi.ABI
	LibUtilsABI     *abi.ABI
	LibVerifyingABI *abi.ABI
	SGXVerifierABI  *abi.ABI
	ProverSetABI    *abi.ABI
	ForkRouterABI   *abi.ABI

	// Pacaya fork
	TaikoInboxABI           *abi.ABI
	TaikoWrapperABI         *abi.ABI
	ForcedInclusionStoreABI *abi.ABI
	TaikoAnchorABI          *abi.ABI
	ResolverBaseABI         *abi.ABI
	ComposeVerifierABI      *abi.ABI
	ForkRouterPacayaABI     *abi.ABI
	TaikoTokenPacayaABI     *abi.ABI
	ProverSetPacayaABI      *abi.ABI

	// Shasta fork
	ShastaInboxABI           *abi.ABI
	ShastaAnchorABI          *abi.ABI
	BondManagerABI           *abi.ABI
	ShastaProposedEventTopic common.Hash
	ShastaProvedEventTopic   common.Hash

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

	if ProverSetABI, err = ontakeBindings.ProverSetMetaData.GetAbi(); err != nil {
		log.Crit("Get ProverSet ABI error", "error", err)
	}

	if ForkRouterABI, err = ontakeBindings.ForkRouterMetaData.GetAbi(); err != nil {
		log.Crit("Get ForkRouter ABI error", "error", err)
	}

	if TaikoInboxABI, err = pacayaBindings.TaikoInboxClientMetaData.GetAbi(); err != nil {
		log.Crit("Get Pacaya TaikoInbox ABI error", "error", err)
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

	if ResolverBaseABI, err = pacayaBindings.ResolverBaseMetaData.GetAbi(); err != nil {
		log.Crit("Get ResolverBase ABI error", "error", err)
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

	if ShastaInboxABI, err = shastaBindings.ShastaInboxClientMetaData.GetAbi(); err != nil {
		log.Crit("Get Shasta Inbox ABI error", "error", err)
	}

	if proposedEvent, ok := ShastaInboxABI.Events["Proposed"]; ok {
		ShastaProposedEventTopic = proposedEvent.ID
	} else {
		log.Crit("Proposed event not found in Shasta inbox ABI")
	}

	if provedEvent, ok := ShastaInboxABI.Events["Proved"]; ok {
		ShastaProvedEventTopic = provedEvent.ID
	} else {
		log.Crit("Proved event not found in Shasta inbox ABI")
	}

	if ShastaAnchorABI, err = shastaBindings.ShastaAnchorMetaData.GetAbi(); err != nil {
		log.Crit("Get Shasta Anchor ABI error", "error", err)
	}

	if BondManagerABI, err = shastaBindings.BondManagerMetaData.GetAbi(); err != nil {
		log.Crit("Get BondManager ABI error", "error", err)
	}

	customErrorMaps = []map[string]abi.Error{
		TaikoL1ABI.Errors,
		TaikoL2ABI.Errors,
		LibProposingABI.Errors,
		LibProvingABI.Errors,
		LibUtilsABI.Errors,
		LibVerifyingABI.Errors,
		SGXVerifierABI.Errors,
		ProverSetABI.Errors,
		ForkRouterABI.Errors,
		TaikoInboxABI.Errors,
		TaikoWrapperABI.Errors,
		ForcedInclusionStoreABI.Errors,
		TaikoAnchorABI.Errors,
		ResolverBaseABI.Errors,
		ComposeVerifierABI.Errors,
		ForkRouterPacayaABI.Errors,
		TaikoTokenPacayaABI.Errors,
		ProverSetPacayaABI.Errors,
		ShastaInboxABI.Errors,
		ShastaAnchorABI.Errors,
		BondManagerABI.Errors,
	}
}

// EncodeBatchParamsWithForcedInclusion performs the solidity `abi.encode` for the given two Pacaya batchParams.
func EncodeBatchParamsWithForcedInclusion(paramsForcedInclusion, params *BatchParams) ([]byte, error) {
	var (
		x   []byte
		err error
	)
	if paramsForcedInclusion != nil {
		if x, err = BatchParamsComponentsArgs.Pack(paramsForcedInclusion); err != nil {
			return nil, fmt.Errorf("failed to abi.encode Pacaya batch params, %w", err)
		}
	}
	y, err := BatchParamsComponentsArgs.Pack(params)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode Pacaya batch params, %w", err)
	}
	return batchParamsWithForcedInclusionArgs.Pack(x, y)
}

// EncodeBatchesSubProofsPacaya performs the solidity `abi.encode` for the given Pacaya SubProof.
func EncodeBatchesSubProofsPacaya(subProofs []SubProofPacaya) ([]byte, error) {
	b, err := SubProofsPacayaComponentsArrayArgs.Pack(subProofs)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode Pacaya batch subproofs (count: %d), %w", len(subProofs), err)
	}
	return b, nil
}

// EncodeBatchesSubProofsShasta performs the solidity `abi.encode` for the given Shasta SubProof.
func EncodeBatchesSubProofsShasta(subProofs []SubProofShasta) ([]byte, error) {
	b, err := SubProofsShastaComponentsArrayArgs.Pack(subProofs)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode Shasta batch subproofs (count: %d), %w", len(subProofs), err)
	}
	return b, nil
}

// EncodeProveBatchesInput performs the solidity `abi.encode` for the given Pacaya `TaikoInbox.proveBatches` input.
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
		return nil, fmt.Errorf("failed to abi.encode Pacaya TaikoInbox.proveBatches input item after pacaya fork, %w", err)
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

// CalculateShastaDifficulty calculates the difficulty for the given Shasta block.
func CalculateShastaDifficulty(parentDifficulty *big.Int, blockNum *big.Int) ([]byte, error) {
	packed, err := ShastaDifficultyInputArgs.Pack(parentDifficulty, blockNum)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode Shasta block difficulty, %w", err)
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
