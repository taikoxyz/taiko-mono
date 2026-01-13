package submitter

import (
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	cmap "github.com/orcaman/concurrent-map/v2"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

func TestProofDistributionWithOutOfOrderResponses(t *testing.T) {
	buffer := proofProducer.NewProofBuffer(8)
	cacheMap := cmap.New[*proofProducer.ProofResponse]()

	submitter := &ProofSubmitterShasta{
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			proofProducer.ProofTypeOp: buffer,
		},
		proofCacheMaps: map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse]{
			proofProducer.ProofTypeOp: cacheMap,
		},
		batchAggregationNotify:    make(chan proofProducer.ProofType, 1),
		flushCacheNotify:          make(chan proofProducer.ProofType, 1),
		forceBatchProvingInterval: time.Hour,
	}

	fromID := big.NewInt(1)

	responses := []*proofProducer.ProofResponse{
		newProofResponse(1),
		newProofResponse(3),
		newProofResponse(2),
	}

	metas := []metadata.TaikoProposalMetaData{
		newShastaMetaForTest(1),
		newShastaMetaForTest(3),
		newShastaMetaForTest(2),
	}

	for i := range responses {
		require.NoError(t, submitter.handleProofResponse(metas[i], fromID, responses[i]))
	}

	bufferItems, err := buffer.ReadAll()
	require.NoError(t, err)
	require.Len(t, bufferItems, 2)
	require.Equal(t, uint64(1), bufferItems[0].BatchID.Uint64())
	require.Equal(t, uint64(2), bufferItems[1].BatchID.Uint64())

	cachedProof, ok := cacheMap.Get("3")
	require.True(t, ok)
	require.Equal(t, uint64(3), cachedProof.BatchID.Uint64())
	require.Equal(t, 1, len(cacheMap.Keys()))
}

func newShastaMetaForTest(id int64) metadata.TaikoProposalMetaData {
	return metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{
			Id:       big.NewInt(id),
			Proposer: common.Address{},
		},
		0,
	)
}

func newProofResponse(id int64) *proofProducer.ProofResponse {
	return &proofProducer.ProofResponse{
		BatchID:   big.NewInt(id),
		ProofType: proofProducer.ProofTypeOp,
	}
}
