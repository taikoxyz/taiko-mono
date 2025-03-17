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

func TestComposeProducerRequestProof(t *testing.T) {
	var (
		producer = &ComposeProofProducer{
			IsOp:               true,
			DummyProofProducer: DummyProofProducer{},
			PivotProducer:      &PivotProofProducer{Dummy: true},
		}
		blockID = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProofRequestOptionsPacaya{},
		blockID,
		&metadata.TaikoDataBlockMetadataPacaya{},
		time.Now(),
	)
	require.Nil(t, err)

	require.Equal(t, res.BlockID, blockID)
	require.Equal(t, res.Tier, encoding.TierDeprecated)
	require.NotEmpty(t, res.Proof)
}
