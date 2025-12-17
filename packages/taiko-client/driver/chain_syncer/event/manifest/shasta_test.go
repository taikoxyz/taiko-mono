package manifest

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
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
		ShastaInboxClientProposed: &shastaBindings.ShastaInboxClientProposed{
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
	parentTime := uint64(1_000)
	proposalTimestamp := parentTime + manifest.TimestampMaxOffset + 100
	forkTime := proposalTimestamp - 50
	proposal := &shastaBindings.ShastaInboxClientProposed{}

	// Timestamp above proposal timestamp should fail.
	sourcePayload := &ShastaDerivationSourcePayload{
		ParentBlock: types.NewBlock(&types.Header{Time: parentTime}, &types.Body{}, nil, nil),
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{Timestamp: proposalTimestamp + 1}},
		},
	}
	s.False(validateMetadataTimestamp(sourcePayload, proposal, proposalTimestamp, forkTime))

	// Timestamp below lower bound should fail.
	expectedLowerBound := max(parentTime+1, proposalTimestamp-manifest.TimestampMaxOffset)
	expectedLowerBound = max(expectedLowerBound, forkTime)
	sourcePayload = &ShastaDerivationSourcePayload{
		ParentBlock: types.NewBlock(&types.Header{Time: parentTime}, &types.Body{}, nil, nil),
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{Timestamp: expectedLowerBound - 1}},
		},
	}
	s.False(validateMetadataTimestamp(sourcePayload, proposal, proposalTimestamp, forkTime))

	// Valid payload passes.
	validTimestamp := expectedLowerBound + 10
	sourcePayload = &ShastaDerivationSourcePayload{
		ParentBlock: types.NewBlock(&types.Header{Time: parentTime}, &types.Body{}, nil, nil),
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{Timestamp: validTimestamp}},
		},
	}
	s.True(validateMetadataTimestamp(sourcePayload, proposal, proposalTimestamp, forkTime))
	s.Equal(validTimestamp, sourcePayload.BlockPayloads[0].Timestamp)
}

func (s *ShastaManifestFetcherTestSuite) TestValidateAnchorBlockNumber() {
	originBlockNumber := uint64(1000)
	parentAnchorBlockNumber := uint64(900)
	proposalID := testutils.RandomHash().Big()
	parentTime := uint64(1_000)
	proposer := common.BytesToAddress(testutils.RandomBytes(20))

	// Test 1: Non-monotonic progression - should return false
	sourcePayload := &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				AnchorBlockNumber: 850, // Less than parent, should be adjusted
			}},
		},
	}

	proposal := &shastaBindings.ShastaInboxClientProposed{Id: proposalID, Proposer: proposer}
	result := validateAnchorBlockNumber(sourcePayload, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result)

	// Test 2: Future reference - anchor newer than origin block
	futureAnchor := originBlockNumber + 1 // 1001, cannot be newer than origin
	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				AnchorBlockNumber: futureAnchor,
			}},
		},
	}

	result = validateAnchorBlockNumber(sourcePayload, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result)

	// Test 3: Excessive lag - should be adjusted and return false (no progression)
	lagAnchor := originBlockNumber - manifest.AnchorMaxOffset - 1 // 871, excessive lag
	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				AnchorBlockNumber: lagAnchor,
			}},
		},
	}

	result = validateAnchorBlockNumber(sourcePayload, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result)

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

	// Test 6: Forced inclusion should pass once inherited metadata is applied
	sourcePayload = &ShastaDerivationSourcePayload{
		ParentBlock: types.NewBlock(
			&types.Header{Number: big.NewInt(int64(parentAnchorBlockNumber)), Time: parentTime, GasLimit: 30_000_000},
			&types.Body{},
			nil,
			nil,
		),
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				AnchorBlockNumber: 0, // Forced inclusion inherits parent anchor
			}},
		},
	}
	ApplyInheritedMetadata(
		sourcePayload,
		proposal,
		parentTime+5,
		parentAnchorBlockNumber,
		parentTime,
	)
	result = validateAnchorBlockNumber(sourcePayload, originBlockNumber, parentAnchorBlockNumber, proposal, true)
	s.True(result)
	s.Equal(parentAnchorBlockNumber, sourcePayload.BlockPayloads[0].AnchorBlockNumber)
}

func (s *ShastaManifestFetcherTestSuite) TestApplyInheritedMetadata() {
	parentTime := uint64(1_000 + manifest.TimestampMaxOffset)
	parentHeader := &types.Header{
		Number:   big.NewInt(1),
		GasLimit: 30_000_000,
		Time:     parentTime,
	}
	parentBlock := types.NewBlockWithHeader(parentHeader)
	proposer := common.BytesToAddress(testutils.RandomBytes(20))

	proposal := shastaBindings.IInboxProposal{
		Timestamp: big.NewInt(int64(parentTime + 20)),
		Proposer:  proposer,
	}

	sourcePayload := &ShastaDerivationSourcePayload{
		ParentBlock: parentBlock,
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{Transactions: types.Transactions{}}},
			{BlockManifest: manifest.BlockManifest{Transactions: types.Transactions{}}},
		},
	}

	expectedLowerBound := max(parentTime+1, proposal.Timestamp.Uint64()-manifest.TimestampMaxOffset)
	ApplyInheritedMetadata(
		sourcePayload,
		&shastaBindings.ShastaInboxClientProposed{Proposer: proposal.Proposer},
		proposal.Timestamp.Uint64(),
		900,
		parentTime-10,
	)
	s.Equal(proposer, sourcePayload.BlockPayloads[0].Coinbase)
	s.Equal(uint64(900), sourcePayload.BlockPayloads[0].AnchorBlockNumber)
	s.Equal(expectedLowerBound, sourcePayload.BlockPayloads[0].Timestamp)
	s.Equal(sourcePayload.BlockPayloads[0].GasLimit, sourcePayload.BlockPayloads[1].GasLimit)
	s.Greater(sourcePayload.BlockPayloads[1].Timestamp, sourcePayload.BlockPayloads[0].Timestamp)

	// When lower bound exceeds proposal timestamp, metadata still uses the computed lower bound.
	proposal.Timestamp = big.NewInt(int64(parentTime))
	sourcePayload = &ShastaDerivationSourcePayload{
		ParentBlock: parentBlock,
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{}},
		},
	}
	exceedingFork := proposal.Timestamp.Uint64() + 1
	ApplyInheritedMetadata(
		sourcePayload,
		&shastaBindings.ShastaInboxClientProposed{Proposer: proposal.Proposer},
		proposal.Timestamp.Uint64(),
		900,
		exceedingFork,
	)
	s.Equal(proposer, sourcePayload.BlockPayloads[0].Coinbase)
	s.Equal(max(parentTime+1, exceedingFork), sourcePayload.BlockPayloads[0].Timestamp)
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

	// Test 1: Zero gas limit - should fail
	sourcePayload := &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				GasLimit: 0,
			}},
		},
	}

	s.False(validateGasLimit(sourcePayload, parentBlockNumber, parentGasLimit))

	// Test 2: Gas limit below lower bound - should fail
	lowGasLimit := expectedLowerBound - 1000
	sourcePayload = &ShastaDerivationSourcePayload{
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				GasLimit: lowGasLimit,
			}},
		},
	}

	s.False(validateGasLimit(sourcePayload, parentBlockNumber, parentGasLimit))

	// Test 3: Gas limit above upper bound - should fail
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
	s.Equal(validGasLimit, sourcePayload.BlockPayloads[0].GasLimit)

	// Test 5: Sequential blocks - parent gas limit should update
	firstBlockGasLimit := validGasLimit
	secondBlockGasLimit := validGasLimit

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

	s.True(validateGasLimit(sourcePayload, parentBlockNumber, parentGasLimit))
	s.Equal(firstBlockGasLimit, sourcePayload.BlockPayloads[0].GasLimit)
	s.Equal(firstBlockGasLimit, sourcePayload.BlockPayloads[1].GasLimit) // Should inherit from first block

	// Test 6: Minimum gas limit enforcement returns false when below MIN_BLOCK_GAS_LIMIT
	if manifest.MinBlockGasLimit > expectedLowerBound {
		veryLowParentGasLimit := uint64(10_000_000) // Low parent gas limit
		sourcePayload = &ShastaDerivationSourcePayload{
			BlockPayloads: []*ShastaBlockPayload{
				{BlockManifest: manifest.BlockManifest{
					GasLimit: 5_000_000, // Very low, should be clamped to MIN_BLOCK_GAS_LIMIT
				}},
			},
		}

		s.False(validateGasLimit(sourcePayload, parentBlockNumber, veryLowParentGasLimit))
	}
}

func (s *ShastaManifestFetcherTestSuite) TestValidateMetadata() {
	parentTime := uint64(1_000)
	parentHeader := &types.Header{
		Number:   big.NewInt(0),
		GasLimit: 30_000_000,
		Time:     parentTime,
	}
	parentBlock := types.NewBlockWithHeader(parentHeader)

	sourcePayload := &ShastaDerivationSourcePayload{
		ParentBlock: parentBlock,
		BlockPayloads: []*ShastaBlockPayload{
			{BlockManifest: manifest.BlockManifest{
				Timestamp:         parentTime + 10,
				Coinbase:          common.BytesToAddress(testutils.RandomBytes(20)),
				AnchorBlockNumber: 950,
				GasLimit:          30_000_000,
			}},
		},
	}

	proposal := shastaBindings.IInboxProposal{
		Id:        big.NewInt(1),
		Timestamp: big.NewInt(int64(parentTime + 20)),
		Proposer:  common.BytesToAddress(testutils.RandomBytes(20)),
	}
	proposalEvent := &shastaBindings.ShastaInboxClientProposed{Id: proposal.Id, Proposer: proposal.Proposer}
	proposalTimestamp := proposal.Timestamp.Uint64()

	rpcClient := &rpc.Client{
		ShastaClients: &rpc.ShastaClients{ForkTime: parentTime},
	}

	s.True(ValidateMetadata(
		rpcClient,
		sourcePayload,
		proposalEvent,
		proposalTimestamp,
		1_000,
		900,
		false,
	))

	// Anchor block number without progression should invalidate the source.
	sourcePayload.BlockPayloads[0].AnchorBlockNumber = 900
	s.False(ValidateMetadata(
		rpcClient,
		sourcePayload,
		proposalEvent,
		proposalTimestamp,
		1_000,
		900,
		false,
	))
}
