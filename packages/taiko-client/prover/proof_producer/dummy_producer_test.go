package producer

import (
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

func TestDummyProducerRequestProof(t *testing.T) {
	var (
		producer        = DummyProofProducer{}
		tier     uint16 = 1024
		blockID         = common.Big32
	)
	res, err := producer.RequestProof(
		&ProofRequestOptionsOntake{},
		blockID,
		&metadata.TaikoDataBlockMetadataOntake{},
		tier,
		time.Now(),
	)
	require.Nil(t, err)

	require.Equal(t, res.BlockID, blockID)
	require.Equal(t, tier, res.Tier)
	require.NotEmpty(t, res.Proof)
}
