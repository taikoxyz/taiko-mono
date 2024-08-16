package producer

import (
	"context"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

func TestGuardianProducerRequestProof(t *testing.T) {
	header := &types.Header{
		ParentHash:  randHash(),
		UncleHash:   randHash(),
		Coinbase:    common.BytesToAddress(randHash().Bytes()),
		Root:        randHash(),
		TxHash:      randHash(),
		ReceiptHash: randHash(),
		Difficulty:  common.Big0,
		Number:      common.Big256,
		GasLimit:    1024,
		GasUsed:     1024,
		Time:        uint64(time.Now().Unix()),
		Extra:       randHash().Bytes(),
		MixDigest:   randHash(),
		Nonce:       types.BlockNonce{},
	}

	var (
		producer = NewGuardianProofProducer(encoding.TierGuardianMajorityID, false)
		blockID  = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProofRequestOptions{},
		blockID,
		&metadata.TaikoDataBlockMetadataLegacy{},
		header,
	)
	require.Nil(t, err)

	require.Equal(t, res.BlockID, blockID)
	require.Equal(t, res.Header, header)
	require.Equal(t, res.Tier, encoding.TierGuardianMajorityID)
	require.NotEmpty(t, res.Proof)
}

func TestGuardianProducerRequestProofReturnLivenessBond(t *testing.T) {
	header := &types.Header{
		ParentHash:  randHash(),
		UncleHash:   randHash(),
		Coinbase:    common.BytesToAddress(randHash().Bytes()),
		Root:        randHash(),
		TxHash:      randHash(),
		ReceiptHash: randHash(),
		Difficulty:  common.Big0,
		Number:      common.Big256,
		GasLimit:    1024,
		GasUsed:     1024,
		Time:        uint64(time.Now().Unix()),
		Extra:       randHash().Bytes(),
		MixDigest:   randHash(),
		Nonce:       types.BlockNonce{},
	}

	var (
		producer = NewGuardianProofProducer(encoding.TierGuardianMajorityID, true)
		blockID  = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProofRequestOptions{},
		blockID,
		&metadata.TaikoDataBlockMetadataLegacy{},
		header,
	)
	require.Nil(t, err)

	require.Equal(t, res.BlockID, blockID)
	require.Equal(t, res.Header, header)
	require.Equal(t, res.Tier, encoding.TierGuardianMajorityID)
	require.NotEmpty(t, res.Proof)
	require.Equal(t, res.Proof, crypto.Keccak256([]byte("RETURN_LIVENESS_BOND")))
}

func TestMinorityRequestProof(t *testing.T) {
	header := &types.Header{
		ParentHash:  randHash(),
		UncleHash:   randHash(),
		Coinbase:    common.BytesToAddress(randHash().Bytes()),
		Root:        randHash(),
		TxHash:      randHash(),
		ReceiptHash: randHash(),
		Difficulty:  common.Big0,
		Number:      common.Big256,
		GasLimit:    1024,
		GasUsed:     1024,
		Time:        uint64(time.Now().Unix()),
		Extra:       randHash().Bytes(),
		MixDigest:   randHash(),
		Nonce:       types.BlockNonce{},
	}

	var (
		producer = NewGuardianProofProducer(encoding.TierGuardianMinorityID, false)
		blockID  = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProofRequestOptions{},
		blockID,
		&metadata.TaikoDataBlockMetadataLegacy{},
		header,
	)
	require.Nil(t, err)

	require.Equal(t, res.BlockID, blockID)
	require.Equal(t, res.Header, header)
	require.Equal(t, res.Tier, encoding.TierGuardianMinorityID)
	require.NotEmpty(t, res.Proof)
}

func TestRequestMinorityProofReturnLivenessBond(t *testing.T) {
	header := &types.Header{
		ParentHash:  randHash(),
		UncleHash:   randHash(),
		Coinbase:    common.BytesToAddress(randHash().Bytes()),
		Root:        randHash(),
		TxHash:      randHash(),
		ReceiptHash: randHash(),
		Difficulty:  common.Big0,
		Number:      common.Big256,
		GasLimit:    1024,
		GasUsed:     1024,
		Time:        uint64(time.Now().Unix()),
		Extra:       randHash().Bytes(),
		MixDigest:   randHash(),
		Nonce:       types.BlockNonce{},
	}

	var (
		producer = NewGuardianProofProducer(encoding.TierGuardianMinorityID, true)
		blockID  = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProofRequestOptions{},
		blockID,
		&metadata.TaikoDataBlockMetadataLegacy{},
		header,
	)
	require.Nil(t, err)

	require.Equal(t, res.BlockID, blockID)
	require.Equal(t, res.Header, header)
	require.Equal(t, res.Tier, encoding.TierGuardianMinorityID)
	require.NotEmpty(t, res.Proof)
	require.Equal(t, res.Proof, crypto.Keccak256([]byte("RETURN_LIVENESS_BOND")))
}
