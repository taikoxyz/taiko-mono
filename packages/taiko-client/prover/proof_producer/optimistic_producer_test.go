package producer

import (
	"context"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

func TestOptimisticRequestProof(t *testing.T) {
	var (
		producer = &OptimisticProofProducer{}
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
	require.Equal(t, res.Tier, encoding.TierOptimisticID)
	require.NotEmpty(t, res.Proof)
}

func TestProofCancel(t *testing.T) {
	var (
		optimisticProofProducer = &OptimisticProofProducer{}
		blockID                 = common.Big32
	)
	_, err := optimisticProofProducer.RequestProof(
		context.Background(),
		&ProofRequestOptionsOntake{},
		blockID,
		&metadata.TaikoDataBlockMetadataOntake{},
		time.Now(),
	)
	require.Nil(t, err)
}
