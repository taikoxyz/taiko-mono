package encoding

import (
	"bytes"
	"fmt"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/taikoxyz/taiko-client/bindings"
)

// ABI arguments marshaling components.
var (
	blockMetadataComponents = []abi.ArgumentMarshaling{
		{
			Name: "id",
			Type: "uint256",
		},
		{
			Name: "l1Height",
			Type: "uint256",
		},
		{
			Name: "l1Hash",
			Type: "bytes32",
		},
		{
			Name: "beneficiary",
			Type: "address",
		},
		{
			Name: "txListHash",
			Type: "bytes32",
		},
		{
			Name: "mixHash",
			Type: "bytes32",
		},
		{
			Name: "extraData",
			Type: "bytes",
		},
		{
			Name: "gasLimit",
			Type: "uint64",
		},
		{
			Name: "timestamp",
			Type: "uint64",
		},
		{
			Name: "commitHeight",
			Type: "uint64",
		},
		{
			Name: "commitSlot",
			Type: "uint64",
		},
	}
	blockHeaderComponents = []abi.ArgumentMarshaling{
		{
			Name: "parentHash",
			Type: "bytes32",
		},
		{
			Name: "ommersHash",
			Type: "bytes32",
		},
		{
			Name: "beneficiary",
			Type: "address",
		},
		{
			Name: "stateRoot",
			Type: "bytes32",
		},
		{
			Name: "transactionsRoot",
			Type: "bytes32",
		},
		{
			Name: "receiptsRoot",
			Type: "bytes32",
		},
		{
			Name: "logsBloom",
			Type: "bytes32[8]",
		},
		{
			Name: "difficulty",
			Type: "uint256",
		},
		{
			Name: "height",
			Type: "uint128",
		},
		{
			Name: "gasLimit",
			Type: "uint64",
		},
		{
			Name: "gasUsed",
			Type: "uint64",
		},
		{
			Name: "timestamp",
			Type: "uint64",
		},
		{
			Name: "extraData",
			Type: "bytes",
		},
		{
			Name: "mixHash",
			Type: "bytes32",
		},
		{
			Name: "nonce",
			Type: "uint64",
		},
		{
			Name: "baseFeePerGas",
			Type: "uint256",
		},
	}
	evidenceComponents = []abi.ArgumentMarshaling{
		{
			Name:       "meta",
			Type:       "tuple",
			Components: blockMetadataComponents,
		},
		{
			Name:       "header",
			Type:       "tuple",
			Components: blockHeaderComponents,
		},
		{
			Name: "prover",
			Type: "address",
		},
		{
			Name: "proofs",
			Type: "bytes[]",
		},
		{
			Name: "circuits",
			Type: "uint16",
		},
	}
)

var (
	// BlockMetadata
	blockMetadataType, _ = abi.NewType("tuple", "LibData.BlockMetadata", blockMetadataComponents)
	blockMetadataArgs    = abi.Arguments{{Name: "BlockMetadata", Type: blockMetadataType}}
	// Evidence
	EvidenceType, _ = abi.NewType("tuple", "V1Proving.Evidence", evidenceComponents)
	EvidenceArgs    = abi.Arguments{{Name: "Evidence", Type: EvidenceType}}
)

// Contract ABIs.
var (
	TaikoL1ABI *abi.ABI
	TaikoL2ABI *abi.ABI
)

func init() {
	var err error

	if TaikoL1ABI, err = bindings.TaikoL1ClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoL1 ABI error", "error", err)
	}

	if TaikoL2ABI, err = bindings.TaikoL2ClientMetaData.GetAbi(); err != nil {
		log.Crit("Get TaikoL2 ABI error", "error", err)
	}
}

// EncodeBlockMetadata performs the solidity `abi.encode` for the given blockMetadata.
func EncodeBlockMetadata(meta *bindings.TaikoDataBlockMetadata) ([]byte, error) {
	b, err := blockMetadataArgs.Pack(meta)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode block metadata, %w", err)
	}
	return b, nil
}

// EncodeEvidence performs the solidity `abi.encode` for the given evidence.
func EncodeEvidence(e *TaikoL1Evidence) ([]byte, error) {
	b, err := EvidenceArgs.Pack(e)
	if err != nil {
		return nil, fmt.Errorf("failed to abi.encode evidence, %w", err)
	}
	return b, nil
}

// EncodeCommitHash performs the solidity `abi.encodePacked` for the given
// commitHash components.
func EncodeCommitHash(beneficiary common.Address, txListHash [32]byte) []byte {
	// keccak256(abi.encodePacked(beneficiary, txListHash));
	return crypto.Keccak256(
		bytes.Join([][]byte{beneficiary.Bytes(), txListHash[:]}, nil),
	)
}

// EncodeProposeBlockInput encodes the input params for TaikoL1.proposeBlock.
func EncodeProposeBlockInput(meta *bindings.TaikoDataBlockMetadata, txListBytes []byte) ([][]byte, error) {
	metaBytes, err := EncodeBlockMetadata(meta)
	if err != nil {
		return nil, err
	}
	return [][]byte{metaBytes, txListBytes}, nil
}

// EncodeProveBlockInput encodes the input params for TaikoL1.proveBlock.
func EncodeProveBlockInput(
	evidence *TaikoL1Evidence,
	anchorTx *types.Transaction,
	anchorReceipt *types.Receipt,
) ([][]byte, error) {
	evidenceBytes, err := EncodeEvidence(evidence)
	if err != nil {
		return nil, err
	}

	anchorTxBytes, err := rlp.EncodeToBytes(anchorTx)
	if err != nil {
		return nil, err
	}

	anchorReceiptBytes, err := rlp.EncodeToBytes(anchorReceipt)
	if err != nil {
		return nil, err
	}

	return [][]byte{evidenceBytes, anchorTxBytes, anchorReceiptBytes}, nil
}

// EncodeProveBlockInvalidInput encodes the input params for TaikoL1.proveBlockInvalid.
func EncodeProveBlockInvalidInput(
	evidence *TaikoL1Evidence,
	target *bindings.TaikoDataBlockMetadata,
	receipt *types.Receipt,
) ([][]byte, error) {
	evidenceBytes, err := EncodeEvidence(evidence)
	if err != nil {
		return nil, err
	}

	metaBytes, err := EncodeBlockMetadata(target)
	if err != nil {
		return nil, err
	}

	receiptBytes, err := rlp.EncodeToBytes(receipt)
	if err != nil {
		return nil, err
	}

	return [][]byte{evidenceBytes, metaBytes, receiptBytes}, nil
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

	inputs, ok := args["inputs"].([][]byte)

	if !ok || len(inputs) < 2 {
		return nil, fmt.Errorf("invalid transaction inputs map length, get: %d", len(inputs))
	}

	return inputs[1], nil
}

// UnpackEvidenceHeader unpacks the evidence data of a TaikoL1.proveBlock transaction, and returns
// the block header inside.
func UnpackEvidenceHeader(txData []byte) (*BlockHeader, error) {
	method, err := TaikoL1ABI.MethodById(txData)
	if err != nil {
		return nil, err
	}

	// Only check for safety.
	if method.Name != "proveBlock" {
		return nil, fmt.Errorf("invalid method name: %s", method.Name)
	}

	args := map[string]interface{}{}

	if err := method.Inputs.UnpackIntoMap(args, txData[4:]); err != nil {
		return nil, err
	}

	inputs, ok := args["inputs"].([][]byte)

	if !ok || len(inputs) < 3 {
		return nil, fmt.Errorf("invalid transaction inputs map length, get: %d", len(inputs))
	}

	return decodeEvidenceHeader(inputs[0])
}

// decodeEvidenceHeader decodes the encoded evidence bytes, and then returns its inner header.
func decodeEvidenceHeader(evidenceBytes []byte) (*BlockHeader, error) {
	unpacked, err := EvidenceArgs.Unpack(evidenceBytes)
	if err != nil {
		return nil, fmt.Errorf("failed to decode evidence meta")
	}

	evidence := new(TaikoL1Evidence)
	if err := EvidenceArgs.Copy(&evidence, unpacked); err != nil {
		return nil, err
	}

	return &evidence.Header, nil
}
