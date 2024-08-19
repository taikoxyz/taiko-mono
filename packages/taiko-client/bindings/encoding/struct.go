package encoding

import (
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	v1 "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/v1"
	v2 "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/v2"
)

// Tier IDs defined in protocol.
var (
	TierOptimisticID       uint16 = 100
	TierSgxID              uint16 = 200
	TierZkVMRisc0ID        uint16 = 290
	TierSgxAndZkVMID       uint16 = 300
	TierGuardianMinorityID uint16 = 900
	TierGuardianMajorityID uint16 = 1000
	GoldenTouchPrivKey            = "92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38"
)

// HookCall should be same with TaikoData.HookCall
type HookCall struct {
	Hook common.Address
	Data []byte
}

// BlockParams should be same with TaikoData.BlockParams.
type BlockParams struct {
	AssignedProver common.Address
	Coinbase       common.Address
	ExtraData      [32]byte
	ParentMetaHash [32]byte
	HookCalls      []HookCall
	Signature      []byte
}

// BlockParamsV2 should be same with TaikoData.BlockParamsV2.
type BlockParamsV2 struct {
	Coinbase         common.Address
	ParentMetaHash   [32]byte
	AnchorBlockId    uint64
	Timestamp        uint64
	BlobTxListOffset uint32
	BlobTxListLength uint32
	BlobIndex        uint8
}

// TierFee should be same with TaikoData.TierFee.
type TierFee struct {
	Tier uint16
	Fee  *big.Int
}

// ToExecutableData converts a GETH *types.Header to *engine.ExecutableData.
func ToExecutableData(header *types.Header) *engine.ExecutableData {
	executableData := &engine.ExecutableData{
		ParentHash:    header.ParentHash,
		FeeRecipient:  header.Coinbase,
		StateRoot:     header.Root,
		ReceiptsRoot:  header.ReceiptHash,
		LogsBloom:     header.Bloom.Bytes(),
		Random:        header.MixDigest,
		Number:        header.Number.Uint64(),
		GasLimit:      header.GasLimit,
		GasUsed:       header.GasUsed,
		Timestamp:     header.Time,
		ExtraData:     header.Extra,
		BaseFeePerGas: header.BaseFee,
		BlockHash:     header.Hash(),
		TxHash:        header.TxHash,
	}

	if header.WithdrawalsHash != nil {
		executableData.WithdrawalsHash = *header.WithdrawalsHash
	}

	return executableData
}

// TransitionProvedEventToV2 converts a *bindings.TaikoL1ClientTransitionProved
// to *bindings.TaikoL1ClientTransitionProvedV2.
func TransitionProvedEventToV2(
	e *v1.TaikoL1ClientTransitionProved,
	proposedIn uint64,
) *v2.TaikoL1ClientTransitionProvedV2 {
	return &v2.TaikoL1ClientTransitionProvedV2{
		BlockId: e.BlockId,
		Tran: v2.TaikoDataTransition{
			ParentHash: e.Tran.ParentHash,
			BlockHash:  e.Tran.BlockHash,
			StateRoot:  e.Tran.StateRoot,
			Graffiti:   e.Tran.Graffiti,
		},
		Prover:       e.Prover,
		ValidityBond: e.ValidityBond,
		Tier:         e.Tier,
		ProposedIn:   proposedIn,
		Raw:          e.Raw,
	}
}

// TransitionContestedEventToV2 converts a *bindings.TaikoL1ClientTransitionContested
// to *bindings.TaikoL1ClientTransitionContestedV2.
func TransitionContestedEventToV2(
	e *v1.TaikoL1ClientTransitionContested,
	proposedIn uint64,
) *v2.TaikoL1ClientTransitionContestedV2 {
	return &v2.TaikoL1ClientTransitionContestedV2{
		BlockId: e.BlockId,
		Tran: v2.TaikoDataTransition{
			ParentHash: e.Tran.ParentHash,
			BlockHash:  e.Tran.BlockHash,
			StateRoot:  e.Tran.StateRoot,
			Graffiti:   e.Tran.Graffiti,
		},
		Contester:   e.Contester,
		ContestBond: e.ContestBond,
		Tier:        e.Tier,
		ProposedIn:  proposedIn,
		Raw:         e.Raw,
	}
}

// BlockVerifiedEventToV2 converts a *bindings.TaikoL1ClientBlockVerified to *bindings.TaikoL1ClientBlockVerifiedV2.
func BlockVerifiedEventToV2(e *v1.TaikoL1ClientBlockVerified) *v2.TaikoL1ClientBlockVerifiedV2 {
	return &v2.TaikoL1ClientBlockVerifiedV2{
		BlockId:   e.BlockId,
		Prover:    e.Prover,
		BlockHash: e.BlockHash,
		Tier:      e.Tier,
		Raw:       e.Raw,
	}
}

// BlockVerifiedEventToV2 converts a *bindings.TaikoDataBlock to *bindings.TaikoDataBlockV2.
func TaikoDataBlockToV2(b *v1.TaikoDataBlock) *v2.TaikoDataBlockV2 {
	return &v2.TaikoDataBlockV2{
		MetaHash:             b.MetaHash,
		AssignedProver:       b.AssignedProver,
		LivenessBond:         b.LivenessBond,
		BlockId:              b.BlockId,
		ProposedAt:           b.ProposedAt,
		ProposedIn:           b.ProposedIn,
		NextTransitionId:     big.NewInt(int64(b.NextTransitionId)),
		LivenessBondReturned: false,
		VerifiedTransitionId: big.NewInt(int64(b.VerifiedTransitionId)),
	}
}

// BloomToBytes converts a types.Bloom to [8][32]byte slice.
func BloomToBytes(bloom types.Bloom) [8][32]byte {
	b := [8][32]byte{}

	for i := 0; i < 8; i++ {
		copy(b[i][:], bloom[i*32:(i+1)*32])
	}

	return b
}

// BytesToBloom converts a [8][32]byte slice to types.Bloom.
func BytesToBloom(b [8][32]byte) types.Bloom {
	bytes := []byte{}

	for i := 0; i < 8; i++ {
		bytes = append(bytes, b[i][:]...)
	}

	return types.BytesToBloom(bytes)
}
