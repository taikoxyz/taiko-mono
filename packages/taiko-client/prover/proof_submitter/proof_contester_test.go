package submitter

import (
	"context"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

func (s *ProofSubmitterTestSuite) TestSubmitContestNoTransition() {
	s.NotNil(
		s.contester.SubmitContest(
			context.Background(),
			common.Big256,
			common.Big1,
			testutils.RandomHash(),
			&metadata.TaikoDataBlockMetadataLegacy{},
			encoding.TierOptimisticID,
		),
	)
}
