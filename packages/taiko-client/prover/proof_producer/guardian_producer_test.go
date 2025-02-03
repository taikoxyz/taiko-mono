package producer

import (
	"context"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

func TestGuardianProducerRequestProof(t *testing.T) {
	var (
		producer = NewGuardianProofProducer(encoding.TierGuardianMajorityID, false)
		blockID  = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProofRequestOptionsOntake{},
		blockID,
		&metadata.TaikoDataBlockMetadataOntake{},
		time.Now(),
	)
	require.Nil(t, err)

	require.Equal(t, res.BlockID, blockID)
	require.Equal(t, res.Tier, encoding.TierGuardianMajorityID)
	require.NotEmpty(t, res.Proof)
}

func TestGuardianProducerRequestProofReturnLivenessBond(t *testing.T) {
	var (
		producer = NewGuardianProofProducer(encoding.TierGuardianMajorityID, true)
		blockID  = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProofRequestOptionsOntake{},
		blockID,
		&metadata.TaikoDataBlockMetadataOntake{},
		time.Now(),
	)
	require.Nil(t, err)

	require.Equal(t, res.BlockID, blockID)
	require.Equal(t, res.Tier, encoding.TierGuardianMajorityID)
	require.NotEmpty(t, res.Proof)
	require.Equal(t, res.Proof, crypto.Keccak256([]byte("RETURN_LIVENESS_BOND")))
}

func TestMinorityRequestProof(t *testing.T) {
	var (
		producer = NewGuardianProofProducer(encoding.TierGuardianMinorityID, false)
		blockID  = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProofRequestOptionsOntake{},
		blockID,
		&metadata.TaikoDataBlockMetadataOntake{},
		time.Now(),
	)
	require.Nil(t, err)

	require.Equal(t, res.BlockID, blockID)
	require.Equal(t, res.Tier, encoding.TierGuardianMinorityID)
	require.NotEmpty(t, res.Proof)
}

func TestRequestMinorityProofReturnLivenessBond(t *testing.T) {
	var (
		producer = NewGuardianProofProducer(encoding.TierGuardianMinorityID, true)
		blockID  = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProofRequestOptionsOntake{},
		blockID,
		&metadata.TaikoDataBlockMetadataOntake{},
		time.Now(),
	)
	require.Nil(t, err)

	require.Equal(t, res.BlockID, blockID)
	require.Equal(t, res.Tier, encoding.TierGuardianMinorityID)
	require.NotEmpty(t, res.Proof)
	require.Equal(t, res.Proof, crypto.Keccak256([]byte("RETURN_LIVENESS_BOND")))
}
