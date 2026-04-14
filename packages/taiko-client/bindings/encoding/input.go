package encoding

import (
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// ABI arguments marshaling components.
var (
	SubProofShastaComponents = []abi.ArgumentMarshaling{
		{Name: "verifierId", Type: "uint8"},
		{Name: "proof", Type: "bytes"},
	}
)

var (
	SubProofsShastaComponentsArrayType, _ = abi.NewType("tuple[]", "ComposeVerifier.SubProof", SubProofShastaComponents)
	SubProofsShastaComponentsArrayArgs    = abi.Arguments{
		{Name: "ComposeVerifier.SubProof[]", Type: SubProofsShastaComponentsArrayType},
	}
	uint256Type, _         = abi.NewType("uint256", "", nil)
	ShastaMixHashInputArgs = abi.Arguments{
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
	TaikoAnchorABI *abi.ABI

	// Shasta / Uzen fork
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

	if TaikoAnchorABI, err = pacayaBindings.TaikoAnchorClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoAnchor ABI error", "error", err)
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
		log.Crit("Get Anchor ABI error", "error", err)
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
		TaikoAnchorABI.Errors,
		ShastaInboxABI.Errors,
		ShastaAnchorABI.Errors,
		BondManagerABI.Errors,
	}
}

// EncodeBatchesSubProofs performs the solidity `abi.encode` for the given SubProof.
func EncodeBatchesSubProofs(subProofs []SubProofShasta) ([]byte, error) {
	b, err := SubProofsShastaComponentsArrayArgs.Pack(subProofs)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode batch subproofs (count: %d), %w", len(subProofs), err)
	}
	return b, nil
}

// CalculateShastaMixHash calculates the mixHash for the given block.
func CalculateShastaMixHash(parentDifficulty *big.Int, blockNum *big.Int) ([]byte, error) {
	packed, err := ShastaMixHashInputArgs.Pack(parentDifficulty, blockNum)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode block difficulty, %w", err)
	}

	return crypto.Keccak256(packed), nil
}

// EncodeShastaExtraData encodes basefeeSharingPctg and proposal ID into extraData.
// Format (7 bytes):
//   - Byte 0: basefeeSharingPctg (uint8)
//   - Bytes 1-6: proposalID (uint48, big-endian)
func EncodeShastaExtraData(basefeeSharingPctg uint8, proposalID *big.Int) ([]byte, error) {
	if proposalID == nil {
		return nil, errors.New("proposal ID is nil")
	}
	if proposalID.Sign() < 0 {
		return nil, fmt.Errorf("proposal ID is negative: %s", proposalID.String())
	}
	if proposalID.BitLen() > params.ShastaExtraDataProposalIDLength*8 {
		return nil, fmt.Errorf("proposal ID too large for extraData: %s", proposalID.String())
	}

	extraData := make([]byte, params.ShastaExtraDataLen)
	extraData[params.ShastaExtraDataBasefeeSharingPctgIndex] = basefeeSharingPctg

	proposalBytes := proposalID.Bytes()
	offset := params.ShastaExtraDataProposalIDIndex + params.ShastaExtraDataProposalIDLength - len(proposalBytes)
	copy(extraData[offset:offset+len(proposalBytes)], proposalBytes)

	return extraData, nil
}
