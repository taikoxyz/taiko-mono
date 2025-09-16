package producer

import (
	"context"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

func TestDummyProducerRequestProof(t *testing.T) {
	var (
		producer = DummyProofProducer{}
		blockID  = common.Big32
	)
	res, err := producer.RequestProof(
		context.Background(),
		&ProofRequestOptionsPacaya{},
		blockID,
		&metadata.TaikoDataBlockMetadataPacaya{},
		time.Now(),
	)
	require.Nil(t, err)

	require.Equal(t, res.BatchID, blockID)
	require.NotEmpty(t, res.Proof)
}
