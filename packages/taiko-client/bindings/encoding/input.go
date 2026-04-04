package encoding

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// ABI arguments marshaling components.
var (
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
	SubProofShastaComponents = []abi.ArgumentMarshaling{
		{Name: "verifierId", Type: "uint8"},
		{Name: "proof", Type: "bytes"},
	}
)

var (
	BatchMetaDataComponentsArrayType, _   = abi.NewType("tuple[]", "ITaikoInbox.BatchMetadata", BatchMetaDataComponents)
	BatchTransitionComponentsArrayType, _ = abi.NewType("tuple[]", "ITaikoInbox.Transition", BatchTransitionComponents)
	SubProofsShastaComponentsArrayType, _ = abi.NewType("tuple[]", "ComposeVerifier.SubProof", SubProofShastaComponents)
	SubProofsShastaComponentsArrayArgs    = abi.Arguments{
		{Name: "ComposeVerifier.SubProof[]", Type: SubProofsShastaComponentsArrayType},
	}
	ProveBatchesInputArgs = abi.Arguments{
		{Name: "ITaikoInbox.BlockMetadata[]", Type: BatchMetaDataComponentsArrayType},
		{Name: "TaikoData.Transition[]", Type: BatchTransitionComponentsArrayType},
	}
	uint256Type, _            = abi.NewType("uint256", "", nil)
	ShastaDifficultyInputArgs = abi.Arguments{
		{Name: "parent.metadata.difficulty", Type: uint256Type},
		{Name: "block.number", Type: uint256Type},
	}
)

// Contract ABIs.
var (
	// Ontake fork
	TaikoL1ABI      *abi.ABI
	TaikoL2ABI      *abi.ABI
	LibProposingABI *abi.ABI
	LibProvingABI   *abi.ABI
	LibUtilsABI     *abi.ABI
	LibVerifyingABI *abi.ABI
	SGXVerifierABI  *abi.ABI
	ForkRouterABI   *abi.ABI

	// Pacaya fork
	TaikoInboxABI           *abi.ABI
	TaikoWrapperABI         *abi.ABI
	ForcedInclusionStoreABI *abi.ABI
	TaikoAnchorABI          *abi.ABI
	ResolverBaseABI         *abi.ABI
	ComposeVerifierABI      *abi.ABI
	PacayaForkRouterABI     *abi.ABI

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
		log.Crit("Get SGXVerifier ABI error", "error", err)
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

	if PacayaForkRouterABI, err = pacayaBindings.ForkRouterMetaData.GetAbi(); err != nil {
		log.Crit("Get Pacaya ForkRouter ABI error", "error", err)
	}

	if ShastaInboxABI, err = shastaBindings.ShastaInboxClientMetaData.GetAbi(); err != nil {
		log.Crit("Get inbox ABI error", "error", err)
	}

	if proposedEvent, ok := ShastaInboxABI.Events["Proposed"]; ok {
		ShastaProposedEventTopic = proposedEvent.ID
	} else {
		log.Crit("Proposed event not found in inbox ABI")
	}

	if provedEvent, ok := ShastaInboxABI.Events["Proved"]; ok {
		ShastaProvedEventTopic = provedEvent.ID
	} else {
		log.Crit("Proved event not found in inbox ABI")
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
		ForkRouterABI.Errors,
		TaikoInboxABI.Errors,
		TaikoWrapperABI.Errors,
		ForcedInclusionStoreABI.Errors,
		TaikoAnchorABI.Errors,
		ResolverBaseABI.Errors,
		ComposeVerifierABI.Errors,
		PacayaForkRouterABI.Errors,
		ShastaInboxABI.Errors,
		ShastaAnchorABI.Errors,
		BondManagerABI.Errors,
	}
}

// EncodeBatchesSubProofsShasta performs the solidity `abi.encode` for the given Shasta SubProof.
func EncodeBatchesSubProofsShasta(subProofs []SubProofShasta) ([]byte, error) {
	b, err := SubProofsShastaComponentsArrayArgs.Pack(subProofs)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode Shasta batch subproofs (count: %d), %w", len(subProofs), err)
	}
	return b, nil
}

// CalculateShastaDifficulty calculates the difficulty for the given Shasta block.
func CalculateShastaDifficulty(parentDifficulty *big.Int, blockNum *big.Int) ([]byte, error) {
	packed, err := ShastaDifficultyInputArgs.Pack(parentDifficulty, blockNum)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode Shasta block difficulty, %w", err)
	}

	return crypto.Keccak256(packed), nil
}
