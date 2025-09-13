package manifest

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

type ShastaManifestFetcherTestSuite struct {
	testutils.ClientTestSuite
}

func (s *ShastaManifestFetcherTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()
}

func (s *ShastaManifestFetcherTestSuite) TestManifestEncodeDecode() {
	m := &manifest.ProtocolProposalManifest{
		ProverAuthBytes: testutils.RandomBytes(32),
		Blocks: []*manifest.ProtocolBlockManifest{{
			Timestamp:         testutils.RandomHash().Big().Uint64(),
			Coinbase:          common.BytesToAddress(testutils.RandomBytes(20)),
			AnchorBlockNumber: testutils.RandomHash().Big().Uint64(),
			GasLimit:          testutils.RandomHash().Big().Uint64(),
			Transactions:      types.Transactions{},
		}},
	}
	b, err := builder.EncodeProposalManifestShasta(m)
	s.Nil(err)
	s.NotEmpty(b)

	decoded, err := new(ShastaManifestFetcher).manifestFromBlobBytes(b, 0)
	s.Nil(err)
	s.Equal(m.ProverAuthBytes, decoded.ProverAuthBytes)
	s.Equal(len(m.Blocks), len(decoded.Blocks))
	s.Equal(m.Blocks[0].Timestamp, decoded.Blocks[0].Timestamp)
	s.Equal(m.Blocks[0].Coinbase, decoded.Blocks[0].Coinbase)
	s.Equal(m.Blocks[0].AnchorBlockNumber, decoded.Blocks[0].AnchorBlockNumber)
	s.Equal(m.Blocks[0].GasLimit, decoded.Blocks[0].GasLimit)
	s.Equal(len(m.Blocks[0].Transactions), len(decoded.Blocks[0].Transactions))
}

func (s *ShastaManifestFetcherTestSuite) TestExtractVersionAndSize() {
	version := uint32(1)
	size := manifest.ProposalMaxBytes
	proposalManifestBytes := testutils.RandomBytes(int(size))

	versionBytes := make([]byte, 32)
	versionBytes[31] = byte(version)

	lenBytes := make([]byte, 32)
	lenBig := new(big.Int).SetUint64(uint64(len(proposalManifestBytes)))
	lenBig.FillBytes(lenBytes)

	blobBytesPrefix := make([]byte, 0, 64)
	blobBytesPrefix = append(blobBytesPrefix, versionBytes...)
	blobBytesPrefix = append(blobBytesPrefix, lenBytes...)

	decodedVersion, decodedSize, err := ExtractVersionAndSize(blobBytesPrefix, 0)
	s.Nil(err)
	s.Equal(version, decodedVersion)
	s.Equal(uint64(len(proposalManifestBytes)), decodedSize)
}

func TestShastaManifestFetcherTestSuite(t *testing.T) {
	suite.Run(t, new(ShastaManifestFetcherTestSuite))
}

func (s *ShastaManifestFetcherTestSuite) TearValidateMetadata() {
	// Empty manifest
	s.NotNil(ValidateMetadata(
		context.Background(),
		s.RPCClient,
		nil,
		false,
		shastaBindings.IInboxProposal{},
		0,
		shastaBindings.ShastaAnchorState{}),
	)
}
