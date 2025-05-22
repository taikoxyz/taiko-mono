package handler

import (
	"context"

	"github.com/ethereum/go-ethereum/core/types"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

func (s *EventHandlerTestSuite) TestBatchesVerifiedHandle() {
	handler := NewBatchesVerifiedEventHandler(s.RPCClient)
	id := testutils.RandomHash().Big().Uint64()
	s.NotPanics(func() {
		s.NotNil(handler.HandlePacaya(context.Background(), &pacayaBindings.TaikoInboxClientBatchesVerified{
			BatchId: testutils.RandomHash().Big().Uint64(),
			Raw:     types.Log{BlockHash: testutils.RandomHash(), BlockNumber: id},
		}))
	})
}
