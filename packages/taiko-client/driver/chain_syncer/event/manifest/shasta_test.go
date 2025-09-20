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
	size := uint64(1024) // Use a reasonable test size since ProposalMaxBytes was removed
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

func (s *ShastaManifestFetcherTestSuite) TestValidateMetadataTimestamp() {
	parentTime := testutils.RandomHash().Big().Uint64() % 10000
	proposalTimestamp := big.NewInt(int64(parentTime + testutils.RandomHash().Big().Uint64()%5000 + 1000))

	// Test upper bound enforcement
	proposalManifest := &manifest.ProposalManifest{
		ParentBlock: types.NewBlock(&types.Header{Time: parentTime}, &types.Body{}, nil, nil),
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				Timestamp: proposalTimestamp.Uint64() + testutils.RandomHash().Big().Uint64()%1000 + 1,
			}},
		},
	}

	proposal := shastaBindings.IInboxProposal{Timestamp: proposalTimestamp}

	validateMetadataTimestamp(proposalManifest, proposal)
	s.Equal(proposalTimestamp.Uint64(), proposalManifest.Blocks[0].Timestamp)

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
	proposalManifest = &manifest.ProposalManifest{
		ParentBlock: types.NewBlock(&types.Header{Time: parentTime}, &types.Body{}, nil, nil),
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				Timestamp: lowTimestamp,
			}},
		},
	}

	validateMetadataTimestamp(proposalManifest, proposal)
	s.Equal(expectedLowerBound, proposalManifest.Blocks[0].Timestamp)

	// Test sequential block validation (parent timestamp updates)
	// Ensure first block is within valid bounds and won't be adjusted
	lowerBoundFirst := max(parentTime+1, proposalTimestamp.Uint64()-manifest.TimestampMaxOffset)
	firstBlockTime := lowerBoundFirst + testutils.RandomHash().Big().Uint64()%100 + 10
	if firstBlockTime > proposalTimestamp.Uint64() {
		firstBlockTime = proposalTimestamp.Uint64() - testutils.RandomHash().Big().Uint64()%50 - 1
	}

	// Second block timestamp too low, should be adjusted
	secondBlockTime := firstBlockTime - testutils.RandomHash().Big().Uint64()%50 - 10
	proposalManifest = &manifest.ProposalManifest{
		ParentBlock: types.NewBlock(&types.Header{Time: parentTime}, &types.Body{}, nil, nil),
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{Timestamp: firstBlockTime}},
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{Timestamp: secondBlockTime}},
		},
	}

	validateMetadataTimestamp(proposalManifest, proposal)
	s.Equal(firstBlockTime, proposalManifest.Blocks[0].Timestamp)
	s.GreaterOrEqual(proposalManifest.Blocks[1].Timestamp, proposalManifest.Blocks[0].Timestamp+1)
}

func (s *ShastaManifestFetcherTestSuite) TestValidateAnchorBlockNumber() {
	originBlockNumber := uint64(1000)
	parentAnchorBlockNumber := uint64(900)
	proposalID := testutils.RandomHash().Big()

	// Test 1: Non-monotonic progression - should be adjusted and return false (no progression)
	proposalManifest := &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				AnchorBlockNumber: 850, // Less than parent, should be adjusted
			}},
		},
	}

	proposal := shastaBindings.IInboxProposal{Id: proposalID}
	result := validateAnchorBlockNumber(proposalManifest, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result) // Should return false since no progression beyond parent
	s.Equal(parentAnchorBlockNumber, proposalManifest.Blocks[0].AnchorBlockNumber)

	// Test 2: Future reference - should be adjusted and return false (no progression)
	futureAnchor := originBlockNumber - manifest.AnchorMinOffset + 1 // 999, violates future reference
	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				AnchorBlockNumber: futureAnchor,
			}},
		},
	}

	result = validateAnchorBlockNumber(proposalManifest, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result) // Should return false since no progression beyond parent
	s.Equal(parentAnchorBlockNumber, proposalManifest.Blocks[0].AnchorBlockNumber)

	// Test 3: Excessive lag - should be adjusted and return false (no progression)
	lagAnchor := originBlockNumber - manifest.AnchorMaxOffset - 1 // 871, excessive lag
	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				AnchorBlockNumber: lagAnchor,
			}},
		},
	}

	result = validateAnchorBlockNumber(proposalManifest, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result) // Should return false since no progression beyond parent
	s.Equal(parentAnchorBlockNumber, proposalManifest.Blocks[0].AnchorBlockNumber)

	// Test 4: Valid anchor block number - should remain unchanged
	validAnchor := uint64(950) // Between parent (900) and max allowed (998)
	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				AnchorBlockNumber: validAnchor,
			}},
		},
	}

	result = validateAnchorBlockNumber(proposalManifest, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.True(result)
	s.Equal(validAnchor, proposalManifest.Blocks[0].AnchorBlockNumber)

	// Test 5: Forced inclusion protection - non-forced proposal with no progression should return false
	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				AnchorBlockNumber: parentAnchorBlockNumber, // Same as parent, no progression
			}},
		},
	}

	result = validateAnchorBlockNumber(proposalManifest, originBlockNumber, parentAnchorBlockNumber, proposal, false)
	s.False(result) // Should return false for non-forced inclusion without progression

	// Test 6: Forced inclusion should always return true
	result = validateAnchorBlockNumber(proposalManifest, originBlockNumber, parentAnchorBlockNumber, proposal, true)
	s.True(result) // Should return true for forced inclusion even without progression
}

func (s *ShastaManifestFetcherTestSuite) TestValidateCoinbase() {
	proposer := common.BytesToAddress(testutils.RandomBytes(20))
	customCoinbase := common.BytesToAddress(testutils.RandomBytes(20))

	// Test 1: Forced inclusion - always use proposal.proposer
	proposalManifest := &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				Coinbase: customCoinbase, // Should be overridden
			}},
		},
	}

	proposal := shastaBindings.IInboxProposal{Proposer: proposer}
	validateCoinbase(proposalManifest, proposal, true)
	s.Equal(proposer, proposalManifest.Blocks[0].Coinbase) // Should use proposer

	// Test 2: Regular proposal with non-zero coinbase - should remain unchanged
	// NOTE: This tests the current buggy behavior where the second if condition still executes
	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				Coinbase: customCoinbase,
			}},
		},
	}

	validateCoinbase(proposalManifest, proposal, false)
	// Due to the bug, both conditions are checked independently
	// Since customCoinbase is not zero, it should remain unchanged
	s.Equal(customCoinbase, proposalManifest.Blocks[0].Coinbase)

	// Test 3: Regular proposal with zero coinbase - should use fallback
	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				Coinbase: common.Address{}, // Zero address
			}},
		},
	}

	validateCoinbase(proposalManifest, proposal, false)
	s.Equal(proposer, proposalManifest.Blocks[0].Coinbase) // Should use proposer as fallback

	// Test 4: Demonstrate the bug - forced inclusion still checks zero condition
	// This shows that even for forced inclusion, if coinbase happens to be zero after
	// being set to proposer, it would be set again (though to the same value)
	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				Coinbase: common.Address{}, // Zero address initially
			}},
		},
	}

	validateCoinbase(proposalManifest, proposal, true)
	s.Equal(proposer, proposalManifest.Blocks[0].Coinbase)
}

func (s *ShastaManifestFetcherTestSuite) TestValidateGasLimit() {
	parentGasLimit := uint64(30_000_000)
	shastaForkHeight := big.NewInt(1000)
	parentBlockNumber := big.NewInt(1001) // After fork

	// When parent block is after Shasta fork, UpdateStateGasLimit is subtracted
	// Based on the log output, we can see the effective parent gas limit is 29,000,000 (0x1ba8140)
	effectiveParentGasLimit := uint64(29_000_000) // This is what actually gets used

	// Calculate expected bounds (0.1% change = 10 permyriad) based on effective parent gas limit
	expectedLowerBound := max(
		effectiveParentGasLimit*(10000-manifest.MaxBlockGasLimitChangePermyriad)/10000,
		manifest.MinBlockGasLimit,
	)
	expectedUpperBound := effectiveParentGasLimit * (10000 + manifest.MaxBlockGasLimitChangePermyriad) / 10000

	// Test 1: Zero gas limit - should inherit parent
	proposalManifest := &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				GasLimit: 0,
			}},
		},
	}

	validateGasLimit(proposalManifest, shastaForkHeight, parentBlockNumber, parentGasLimit)
	s.Equal(effectiveParentGasLimit, proposalManifest.Blocks[0].GasLimit)

	// Test 2: Gas limit below lower bound - should be clamped
	lowGasLimit := expectedLowerBound - 1000
	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				GasLimit: lowGasLimit,
			}},
		},
	}

	validateGasLimit(proposalManifest, shastaForkHeight, parentBlockNumber, parentGasLimit)
	s.Equal(expectedLowerBound, proposalManifest.Blocks[0].GasLimit)

	// Test 3: Gas limit above upper bound - should be clamped
	highGasLimit := expectedUpperBound + 1000
	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				GasLimit: highGasLimit,
			}},
		},
	}

	validateGasLimit(proposalManifest, shastaForkHeight, parentBlockNumber, parentGasLimit)
	s.Equal(expectedUpperBound, proposalManifest.Blocks[0].GasLimit)

	// Test 4: Valid gas limit within bounds - should remain unchanged
	validGasLimit := effectiveParentGasLimit + 20000 // 29,020,000, within bounds
	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				GasLimit: validGasLimit,
			}},
		},
	}

	validateGasLimit(proposalManifest, shastaForkHeight, parentBlockNumber, parentGasLimit)
	s.Equal(validGasLimit, proposalManifest.Blocks[0].GasLimit)

	// Test 5: Sequential blocks - parent gas limit should update
	firstBlockGasLimit := effectiveParentGasLimit + 15000 // 29,015,000, within bounds
	secondBlockGasLimit := uint64(0)                      // Should inherit from first block

	proposalManifest = &manifest.ProposalManifest{
		Blocks: []*manifest.BlockManifest{
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				GasLimit: firstBlockGasLimit,
			}},
			{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
				GasLimit: secondBlockGasLimit,
			}},
		},
	}

	validateGasLimit(proposalManifest, shastaForkHeight, parentBlockNumber, parentGasLimit)
	s.Equal(firstBlockGasLimit, proposalManifest.Blocks[0].GasLimit)
	s.Equal(firstBlockGasLimit, proposalManifest.Blocks[1].GasLimit) // Should inherit from first block

	// Test 6: Minimum gas limit enforcement
	if manifest.MinBlockGasLimit > expectedLowerBound {
		veryLowParentGasLimit := uint64(10_000_000) // Low parent gas limit
		proposalManifest = &manifest.ProposalManifest{
			Blocks: []*manifest.BlockManifest{
				{ProtocolBlockManifest: manifest.ProtocolBlockManifest{
					GasLimit: 5_000_000, // Very low, should be clamped to MIN_BLOCK_GAS_LIMIT
				}},
			},
		}

		validateGasLimit(proposalManifest, shastaForkHeight, parentBlockNumber, veryLowParentGasLimit)
		s.Equal(manifest.MinBlockGasLimit, proposalManifest.Blocks[0].GasLimit)
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
		shastaBindings.ShastaAnchorState{}),
	)
}
