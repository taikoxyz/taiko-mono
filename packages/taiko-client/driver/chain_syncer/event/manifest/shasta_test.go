package manifest

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
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
	m := &manifest.DerivationSourceManifest{
		Blocks: []*manifest.BlockManifest{{
			Timestamp:         testutils.RandomHash().Big().Uint64(),
			Coinbase:          common.BytesToAddress(testutils.RandomBytes(20)),
			AnchorBlockNumber: testutils.RandomHash().Big().Uint64(),
			GasLimit:          testutils.RandomHash().Big().Uint64(),
			Transactions:      types.Transactions{},
		}},
	}
	b, err := builder.EncodeSourceManifestShasta(m)
	s.Nil(err)
	s.NotEmpty(b)

	meta := &metadata.TaikoProposalMetadataShasta{
		IInboxDerivation: shastaBindings.IInboxDerivation{
			OriginBlockNumber: big.NewInt(0),
			Sources: []shastaBindings.IInboxDerivationSource{
				{
					BlobSlice: shastaBindings.LibBlobsBlobSlice{
						Offset:    big.NewInt(0),
						Timestamp: big.NewInt(0),
					},
				},
			},
		},
	}
	decoded, err := new(ShastaDerivationSourceFetcher).manifestFromBlobBytes(b, meta, 0)
	s.Nil(err)
	s.False(decoded.Default)
	s.Equal(len(m.Blocks), len(decoded.BlockPayloads))
	s.Equal(m.Blocks[0].Timestamp, decoded.BlockPayloads[0].Timestamp)
	s.Equal(m.Blocks[0].Coinbase, decoded.BlockPayloads[0].Coinbase)
	s.Equal(m.Blocks[0].AnchorBlockNumber, decoded.BlockPayloads[0].AnchorBlockNumber)
	s.Equal(m.Blocks[0].GasLimit, decoded.BlockPayloads[0].GasLimit)
	s.Equal(len(m.Blocks[0].Transactions), len(decoded.BlockPayloads[0].Transactions))
}

func (s *ShastaManifestFetcherTestSuite) TestExtractVersionAndSize() {
	version := uint32(1)
	size := uint64(1024) // Use a reasonable test size since ProposalMaxBytes was removed
	sourceManifestBytes := testutils.RandomBytes(int(size))

	versionBytes := make([]byte, 32)
	versionBytes[31] = byte(version)

	lenBytes := make([]byte, 32)
	lenBig := new(big.Int).SetUint64(uint64(len(sourceManifestBytes)))
	lenBig.FillBytes(lenBytes)

	blobBytesPrefix := make([]byte, 0, 64)
	blobBytesPrefix = append(blobBytesPrefix, versionBytes...)
	blobBytesPrefix = append(blobBytesPrefix, lenBytes...)

	decodedVersion, decodedSize, err := ExtractVersionAndSize(blobBytesPrefix, 0)
	s.Nil(err)
	s.Equal(version, decodedVersion)
	s.Equal(uint64(len(sourceManifestBytes)), decodedSize)
}

func TestShastaManifestFetcherTestSuite(t *testing.T) {
	suite.Run(t, new(ShastaManifestFetcherTestSuite))
}

func (s *ShastaManifestFetcherTestSuite) TestValidateMetadataTimestamp() {
	forkTime := uint64(0)
	parentTime := testutils.RandomHash().Big().Uint64() % 10000
	proposalTimestamp := big.NewInt(int64(parentTime + testutils.RandomHash().Big().Uint64()%5000 + 1000))

	// Test upper bound enforcement
	sourcePayload := &ShastaDerivationSourcePayload{
		ParentBlock: types.NewBlock(&types.Header{Time: parentTime}, &types.Body{}, nil, nil),
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				Timestamp: proposalTimestamp.Uint64() + testutils.RandomHash().Big().Uint64()%1000 + 1,
			}},
		},
	}

	proposal := shastaBindings.IInboxProposal{Timestamp: proposalTimestamp}

	s.False(validateMetadataTimestamp(sourcePayload, proposal, forkTime))

	// Test lower bound enforcement with TIMESTAMP_MAX_OFFSET
	// Calculate what the expected lower bound will be
	expectedLowerBound := max(parentTime+1, proposalTimestamp.Uint64()-manifest.TimestampMaxOffset)
	// Set lowTimestamp to be safely below the lower bound but above 0
	offsetFromLowerBound := testutils.RandomHash().Big().Uint64()%100 + 10
	lowTimestamp := expectedLowerBound - offsetFromLowerBound
	if lowTimestamp > expectedLowerBound || lowTimestamp == 0 {
		// Fallback to a safe value if calculation went wrong
		lowTimestamp = max(1, expectedLowerBound-50)
	}
	sourcePayload = &ShastaDerivationSourcePayload{
		ParentBlock: types.NewBlock(&types.Header{Time: parentTime}, &types.Body{}, nil, nil),
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				Timestamp: lowTimestamp,
			}},
		},
	}

	s.False(validateMetadataTimestamp(sourcePayload, proposal, forkTime))

	// Test sequential block validation (parent timestamp updates)
	lowerBoundFirst := max(parentTime+1, proposalTimestamp.Uint64()-manifest.TimestampMaxOffset)
	firstBlockTime := lowerBoundFirst + testutils.RandomHash().Big().Uint64()%100 + 10
	if firstBlockTime > proposalTimestamp.Uint64() {
		firstBlockTime = proposalTimestamp.Uint64() - testutils.RandomHash().Big().Uint64()%50 - 1
	}

	// Second block timestamp too low, should return default manifest
	secondBlockTime := firstBlockTime - testutils.RandomHash().Big().Uint64()%50 - 10
	sourcePayload = &ShastaDerivationSourcePayload{
		ParentBlock: types.NewBlock(&types.Header{Time: parentTime}, &types.Body{}, nil, nil),
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{Timestamp: firstBlockTime}},
			{BlockManifest: manifest.BlockManifest{Timestamp: secondBlockTime}},
		},
	}

	s.False(validateMetadataTimestamp(sourcePayload, proposal, forkTime))
}

func (s *ShastaManifestFetcherTestSuite) TestValidateAnchorBlockNumber() {
	originBlockNumber := uint64(1000)
	parentAnchorBlockNumber := uint64(900)
	proposalID := testutils.RandomHash().Big()

	// Test 1: Non-monotonic progression - should be adjusted and return false (no progression)
	sourcePayload := &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				AnchorBlockNumber: 850, // Less than parent, should be adjusted
			}},
		},
	}

	proposal := shastaBindings.IInboxProposal{Id: proposalID}
	result := validateAnchorBlockNumber(sourcePayload, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result) // Should return default manifest

	// Test 2: Future reference - should return default manifest
	futureAnchor := originBlockNumber - manifest.AnchorMinOffset + 1 // 999, violates future reference
	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				AnchorBlockNumber: futureAnchor,
			}},
		},
	}

	result = validateAnchorBlockNumber(sourcePayload, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result) // Should return false since no progression beyond parent

	// Test 3: Excessive lag - should return default manifest
	lagAnchor := originBlockNumber - manifest.AnchorMaxOffset - 1 // 871, excessive lag
	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				AnchorBlockNumber: lagAnchor,
			}},
		},
	}

	result = validateAnchorBlockNumber(sourcePayload, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result) // Should return false since no progression beyond parent

	// Test 4: Valid anchor block number - should remain unchanged
	validAnchor := uint64(950) // Between parent (900) and max allowed (998)
	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				AnchorBlockNumber: validAnchor,
			}},
		},
	}

	result = validateAnchorBlockNumber(sourcePayload, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.True(result)
	s.Equal(validAnchor, sourcePayload.BlockPayloads[0].AnchorBlockNumber)

	// Test 5: Forced inclusion protection - non-forced proposal with no progression should return false
	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				AnchorBlockNumber: parentAnchorBlockNumber, // Same as parent, no progression
			}},
		},
	}

	result = validateAnchorBlockNumber(sourcePayload, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result) // Should return false for non-forced inclusion without progression

	// Test 6: Forced inclusion should always return true
	result = validateAnchorBlockNumber(sourcePayload, originBlockNumber, parentAnchorBlockNumber, proposal, true)
	s.True(result) // Should return true for forced inclusion even without progression
}

func (s *ShastaManifestFetcherTestSuite) TestValidateGasLimit() {
	parentGasLimit := uint64(30_000_000)
	parentBlockNumber := big.NewInt(1001) // After fork

	// When parent block is after Shasta fork, AnchorV4GasLimit is subtracted
	// Based on the log output, we can see the effective parent gas limit is 29,000,000 (0x1ba8140)
	effectiveParentGasLimit := uint64(29_000_000) // This is what actually gets used

	// Calculate expected bounds (0.001% change = 10 millionths) based on effective parent gas limit
	expectedLowerBound := max(
		effectiveParentGasLimit*(manifest.GasLimitChangeDenominator-manifest.MaxBlockGasLimitChangePermyriad)/
			manifest.GasLimitChangeDenominator,
		manifest.MinBlockGasLimit,
	)
	expectedUpperBound := effectiveParentGasLimit *
		(manifest.GasLimitChangeDenominator + manifest.MaxBlockGasLimitChangePermyriad) / manifest.GasLimitChangeDenominator

	// Test 1: Zero gas limit - should return default manifest
	sourcePayload := &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				GasLimit: 0,
			}},
		},
	}

	s.False(validateGasLimit(sourcePayload, parentBlockNumber, parentGasLimit))

	// Test 2: Gas limit below lower bound - should return default manifest
	lowGasLimit := expectedLowerBound - 1000
	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				GasLimit: lowGasLimit,
			}},
		},
	}

	s.False(validateGasLimit(sourcePayload, parentBlockNumber, parentGasLimit))

	// Test 3: Gas limit above upper bound - should return default manifest
	highGasLimit := expectedUpperBound + 1000
	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				GasLimit: highGasLimit,
			}},
		},
	}

	s.False(validateGasLimit(sourcePayload, parentBlockNumber, parentGasLimit))

	// Test 4: Valid gas limit within bounds - should remain unchanged
	validGasLimit := expectedLowerBound
	if expectedUpperBound > expectedLowerBound {
		span := expectedUpperBound - expectedLowerBound
		increment := max(uint64(1), span/2)
		validGasLimit = min(expectedUpperBound, expectedLowerBound+increment)
	}
	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				GasLimit: validGasLimit,
			}},
		},
	}

	s.True(validateGasLimit(sourcePayload, parentBlockNumber, parentGasLimit))

	// Test 5: Sequential blocks - parent gas limit should return default manifest
	firstBlockGasLimit := validGasLimit
	secondBlockGasLimit := uint64(0) // Should return default manifest

	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				GasLimit: firstBlockGasLimit,
			}},
			{BlockManifest: manifest.BlockManifest{
				GasLimit: secondBlockGasLimit,
			}},
		},
	}

	s.False(validateGasLimit(sourcePayload, parentBlockNumber, parentGasLimit)) // Should return default manifest

	// Test 6: Minimum gas limit enforcement
	if manifest.MinBlockGasLimit > expectedLowerBound {
		sourcePayload = &ShastaDerivationSourcePayload{
			BlockPayloads: []*ShastaBlockPayload{
				{BlockManifest: manifest.BlockManifest{
					GasLimit: 5_000_000, // Very low, should return default manifest
				}},
			},
		}

		s.False(validateGasLimit(sourcePayload, parentBlockNumber, parentGasLimit))
	}
}

func (s *ShastaManifestFetcherTestSuite) TestValidateMetadata() {
	// Empty manifest
	s.NotNil(ValidateMetadata(
		context.Background(),
		s.RPCClient,
		nil,
		false,
		shastaBindings.IInboxProposal{},
		0,
		0,
		0),
	)
}
