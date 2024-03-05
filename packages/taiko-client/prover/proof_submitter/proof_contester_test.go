package submitter

import (
	"context"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/internal/testutils"
)

func (s *ProofSubmitterTestSuite) TestSubmitContestNoTransition() {
	s.NotNil(
		s.contester.SubmitContest(
			context.Background(),
			common.Big256,
			common.Big1,
			testutils.RandomHash(),
			&bindings.TaikoDataBlockMetadata{},
			encoding.TierOptimisticID,
		),
	)
}
