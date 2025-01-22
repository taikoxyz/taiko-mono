package handler

import (
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

func (s *EventHandlerTestSuite) TestBlockVerifiedHandle() {
	handler := &BlockVerifiedEventHandler{}
	id := testutils.RandomHash().Big().Uint64()
	s.NotPanics(func() {
		handler.Handle(&bindings.TaikoL1ClientBlockVerifiedV2{
			BlockId: testutils.RandomHash().Big(),
			Raw: types.Log{
				BlockHash:   testutils.RandomHash(),
				BlockNumber: id,
			},
		})
	})
}
