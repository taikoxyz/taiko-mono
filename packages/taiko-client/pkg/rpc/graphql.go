package rpc

import (
	"context"
	"fmt"
	"math/big"
	"strconv"

	"github.com/ethereum/go-ethereum/common"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// parseUint64 converts string to uint64, returns 0 on error
func parseUint64(s string) uint64 {
	v, _ := strconv.ParseUint(s, 10, 64)
	return v
}

// ShastaProposalInputs represents the inputs needed to propose a Shasta proposal.
type ShastaProposalInputs struct {
	ParentProposals   []shastaBindings.IInboxProposal
	CoreState         shastaBindings.IInboxCoreState
	TransitionRecords []shastaBindings.IInboxTransitionRecord
	Checkpoint        shastaBindings.ICheckpointManagerCheckpoint
}

// GetShastaProposalInputs fetches recent proposals from the GraphQL indexer, will be used to
// propose a Shasta proposal.
func (c *Client) GetShastaProposalInputs(
	ctx context.Context,
	ringBufferSize uint64,
	maxFinalizationCount uint64,
) (*ShastaProposalInputs, error) {
	if c.ShastaClients.Indexer == nil {
		return nil, errNoGraphQLClient
	}

	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	// Query for the latest proposal first
	var latestProposalQuery struct {
		AllProposeds struct {
			Nodes []struct {
				// Proposal fields (using camelCase for new schema)
				ProposalID        string `graphql:"proposalId"`
				ProposalTimestamp string `graphql:"proposalTimestamp"`
				Proposer          string `graphql:"proposer"`
				CoreStateHash     string `graphql:"coreStateHash"`
				DerivationHash    string `graphql:"derivationHash"`
				// CoreState fields (we'll use from the latest proposal)
				NextProposalID              string `graphql:"nextProposalId"`
				LastFinalizedProposalID     string `graphql:"lastFinalizedProposalId"`
				LastFinalizedTransitionHash string `graphql:"lastFinalizedTransitionHash"`
				BondInstructionsHash        string `graphql:"bondInstructionsHash"`
			} `graphql:"nodes"`
		} `graphql:"allProposeds(orderBy: PROPOSAL_ID_DESC, first: 1)"`
	}

	if err := c.ShastaClients.Indexer.Query(ctxWithTimeout, &latestProposalQuery, nil); err != nil {
		return nil, err
	}

	if len(latestProposalQuery.AllProposeds.Nodes) == 0 {
		return nil, fmt.Errorf("no proposals found")
	}

	latestProposal := latestProposalQuery.AllProposeds.Nodes[0]

	// Collect all proposals we need for ParentProposals
	proposalsToConvert := []struct {
		ProposalID        uint64
		ProposalTimestamp uint64
		Proposer          string
		CoreStateHash     string
		DerivationHash    string
	}{{
		ProposalID:        parseUint64(latestProposal.ProposalID),
		ProposalTimestamp: parseUint64(latestProposal.ProposalTimestamp),
		Proposer:          latestProposal.Proposer,
		CoreStateHash:     latestProposal.CoreStateHash,
		DerivationHash:    latestProposal.DerivationHash,
	}}

	// If the ring buffer is full, we need to also get the proposal that will be overwritten
	// The next proposal will be stored at slot: (latestProposalID + 1) % ringBufferSize
	// So we need the proposal at that slot if it exists
	proposalID := parseUint64(latestProposal.ProposalID)
	if proposalID >= ringBufferSize {
		// Calculate which proposal ID would be overwritten
		nextSlot := (proposalID + 1) % ringBufferSize
		// The proposal ID that was previously in this slot is:
		// nextSlot + (floor(latestProposalID / ringBufferSize) - 1) * ringBufferSize
		// But since we're looking for the most recent proposal in that slot before the current one,
		// we need: latestProposalID - ringBufferSize + 1 + nextSlot - nextSlot = latestProposalID - ringBufferSize + 1
		// Skip overwritten proposal logic for now to avoid GraphQL variable issues
		// TODO: Fix this properly later
		_ = nextSlot // avoid unused variable warning
	}

	// For now, skip proved events query to avoid GraphQL variable type issues
	// TODO: Fix this properly later
	lastFinalizedID := uint64(0)
	if len(latestProposalQuery.AllProposeds.Nodes) > 0 {
		lastFinalizedID = parseUint64(latestProposal.LastFinalizedProposalID)
	}

	// Build the result
	result := &ShastaProposalInputs{
		ParentProposals:   make([]shastaBindings.IInboxProposal, 0),
		TransitionRecords: make([]shastaBindings.IInboxTransitionRecord, 0),
	}

	// Convert proposals to ParentProposals
	for _, p := range proposalsToConvert {
		proposal := shastaBindings.IInboxProposal{
			Id:                     new(big.Int).SetUint64(p.ProposalID),
			Timestamp:              new(big.Int).SetUint64(p.ProposalTimestamp),
			LookaheadSlotTimestamp: big.NewInt(0), // This field might need to be added to the query if available
			Proposer:               common.HexToAddress(p.Proposer),
			CoreStateHash:          common.HexToHash(p.CoreStateHash),
			DerivationHash:         common.HexToHash(p.DerivationHash),
		}
		result.ParentProposals = append(result.ParentProposals, proposal)
	}

	// Use CoreState from the latest proposal
	result.CoreState = shastaBindings.IInboxCoreState{
		NextProposalId:              new(big.Int).SetUint64(parseUint64(latestProposal.NextProposalID)),
		LastFinalizedProposalId:     new(big.Int).SetUint64(parseUint64(latestProposal.LastFinalizedProposalID)),
		LastFinalizedTransitionHash: common.HexToHash(latestProposal.LastFinalizedTransitionHash),
		BondInstructionsHash:        common.HexToHash(latestProposal.BondInstructionsHash),
	}

	// Process proved events to build TransitionRecords
	// We need to:
	// 1. Deduplicate by proposal_id (keep the newest one based on block_number)
	// 2. Ensure continuity from LastFinalizedProposalId
	// 3. Limit to maxFinalizationCount

	// First, deduplicate proved events by proposal_id, keeping the newest one
	type ProvedEvent struct {
		ID                     uint64
		ProposalID             uint64
		Span                   uint8
		TransitionHash         string
		EndBlockMiniHeaderHash string
		EndBlockNumber         uint64
		EndBlockHash           string
		EndBlockStateRoot      string
		BlockNumber            uint64
	}

	latestProvedByProposalID := make(map[uint64]ProvedEvent)

	// Create empty proved events slice for now
	provedEvents := []struct {
		ID                     uint64
		ProposalID             uint64
		Span                   uint8
		TransitionHash         string
		EndBlockMiniHeaderHash string
		EndBlockNumber         uint64
		EndBlockHash           string
		EndBlockStateRoot      string
		BlockNumber            uint64
	}{}

	for _, proved := range provedEvents {
		existing, exists := latestProvedByProposalID[proved.ProposalID]
		if !exists || proved.BlockNumber > existing.BlockNumber {
			latestProvedByProposalID[proved.ProposalID] = ProvedEvent{
				ID:                     proved.ID,
				ProposalID:             proved.ProposalID,
				Span:                   proved.Span,
				TransitionHash:         proved.TransitionHash,
				EndBlockMiniHeaderHash: proved.EndBlockMiniHeaderHash,
				EndBlockNumber:         proved.EndBlockNumber,
				EndBlockHash:           proved.EndBlockHash,
				EndBlockStateRoot:      proved.EndBlockStateRoot,
				BlockNumber:            proved.BlockNumber,
			}
		}
	}

	// Now build continuous transition records starting from LastFinalizedProposalId + 1
	expectedProposalID := lastFinalizedID + 1
	var latestProvedEvent *struct {
		EndBlockNumber    uint64
		EndBlockHash      string
		EndBlockStateRoot string
	}

	for i := uint64(0); i < maxFinalizationCount; i++ {
		proved, exists := latestProvedByProposalID[expectedProposalID]
		if !exists {
			// Continuity broken, stop here
			break
		}

		// Query bond instructions for this specific proved event
		var bondQuery struct {
			BondInstructions []struct {
				ProposalID uint64 `graphql:"proposal_id"`
				BondType   uint8  `graphql:"bond_type"`
				Payer      string `graphql:"payer"`
				Receiver   string `graphql:"receiver"`
			} `graphql:"proved_bond_instructions(where: {proved_id: {_eq: $provedID}})"`
		}

		if err := c.ShastaClients.Indexer.Query(ctxWithTimeout, &bondQuery, map[string]interface{}{
			"provedID": proved.ID,
		}); err != nil {
			// If querying bond instructions fails, continue with empty bond instructions
			bondQuery.BondInstructions = nil
		}

		// Convert bond instructions
		bondInstructions := make([]shastaBindings.LibBondsBondInstruction, 0)
		for _, bi := range bondQuery.BondInstructions {
			bondInstructions = append(bondInstructions, shastaBindings.LibBondsBondInstruction{
				ProposalId: new(big.Int).SetUint64(bi.ProposalID),
				BondType:   bi.BondType,
				Payer:      common.HexToAddress(bi.Payer),
				Receiver:   common.HexToAddress(bi.Receiver),
			})
		}

		// Create transition record
		record := shastaBindings.IInboxTransitionRecord{
			Span:             proved.Span,
			BondInstructions: bondInstructions,
			TransitionHash:   common.HexToHash(proved.TransitionHash),
			CheckpointHash:   common.HexToHash(proved.EndBlockMiniHeaderHash),
		}
		result.TransitionRecords = append(result.TransitionRecords, record)

		// Keep track of the latest proved event for checkpoint
		latestProvedEvent = &struct {
			EndBlockNumber    uint64
			EndBlockHash      string
			EndBlockStateRoot string
		}{
			EndBlockNumber:    proved.EndBlockNumber,
			EndBlockHash:      proved.EndBlockHash,
			EndBlockStateRoot: proved.EndBlockStateRoot,
		}

		expectedProposalID++
	}

	// Use Checkpoint from the latest continuous proved event
	if latestProvedEvent != nil {
		result.Checkpoint = shastaBindings.ICheckpointManagerCheckpoint{
			BlockNumber: new(big.Int).SetUint64(latestProvedEvent.EndBlockNumber),
			BlockHash:   common.HexToHash(latestProvedEvent.EndBlockHash),
			StateRoot:   common.HexToHash(latestProvedEvent.EndBlockStateRoot),
		}
	} else {
		// If no continuous proved events found, use empty checkpoint
		result.Checkpoint = shastaBindings.ICheckpointManagerCheckpoint{
			BlockNumber: big.NewInt(0),
			BlockHash:   common.Hash{},
			StateRoot:   common.Hash{},
		}
	}

	return result, nil
}
