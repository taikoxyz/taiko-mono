package rpc

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

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
		Proposals []struct {
			// Proposal fields
			ProposalID        uint64 `graphql:"proposal_id"`
			ProposalTimestamp uint64 `graphql:"proposal_timestamp"`
			Proposer          string `graphql:"proposer"`
			CoreStateHash     string `graphql:"core_state_hash"`
			DerivationHash    string `graphql:"derivation_hash"`
			// CoreState fields (we'll use from the latest proposal)
			NextProposalID              uint64 `graphql:"next_proposal_id"`
			LastFinalizedProposalID     uint64 `graphql:"last_finalized_proposal_id"`
			LastFinalizedTransitionHash string `graphql:"last_finalized_transition_hash"`
			BondInstructionsHash        string `graphql:"bond_instructions_hash"`
		} `graphql:"proposed(order_by: {proposal_id: desc}, limit: 1)"`
	}

	if err := c.ShastaClients.Indexer.Query(ctxWithTimeout, &latestProposalQuery, nil); err != nil {
		return nil, err
	}

	if len(latestProposalQuery.Proposals) == 0 {
		return nil, fmt.Errorf("no proposals found")
	}

	latestProposal := latestProposalQuery.Proposals[0]

	// Collect all proposals we need for ParentProposals
	proposalsToConvert := []struct {
		ProposalID        uint64
		ProposalTimestamp uint64
		Proposer          string
		CoreStateHash     string
		DerivationHash    string
	}{{
		ProposalID:        latestProposal.ProposalID,
		ProposalTimestamp: latestProposal.ProposalTimestamp,
		Proposer:          latestProposal.Proposer,
		CoreStateHash:     latestProposal.CoreStateHash,
		DerivationHash:    latestProposal.DerivationHash,
	}}

	// If the ring buffer is full, we need to also get the proposal that will be overwritten
	// The next proposal will be stored at slot: (latestProposalID + 1) % ringBufferSize
	// So we need the proposal at that slot if it exists
	if latestProposal.ProposalID >= ringBufferSize {
		// Calculate which proposal ID would be overwritten
		nextSlot := (latestProposal.ProposalID + 1) % ringBufferSize
		// The proposal ID that was previously in this slot is:
		// nextSlot + (floor(latestProposalID / ringBufferSize) - 1) * ringBufferSize
		// But since we're looking for the most recent proposal in that slot before the current one,
		// we need: latestProposalID - ringBufferSize + 1 + nextSlot - nextSlot = latestProposalID - ringBufferSize + 1
		// Actually, the proposal in the next slot is: nextSlot + floor(latestProposalID/ringBufferSize)*ringBufferSize
		// But if nextSlot > (latestProposalID % ringBufferSize), it's from the previous cycle
		overwrittenProposalID := nextSlot
		if nextSlot > (latestProposal.ProposalID % ringBufferSize) {
			// It's from the previous cycle
			overwrittenProposalID = nextSlot + ((latestProposal.ProposalID/ringBufferSize - 1) * ringBufferSize)
		} else {
			// It's from the current cycle
			overwrittenProposalID = nextSlot + ((latestProposal.ProposalID / ringBufferSize) * ringBufferSize)
		}

		// Query for the proposal that will be overwritten
		var overwrittenProposalQuery struct {
			Proposals []struct {
				ProposalID        uint64 `graphql:"proposal_id"`
				ProposalTimestamp uint64 `graphql:"proposal_timestamp"`
				Proposer          string `graphql:"proposer"`
				CoreStateHash     string `graphql:"core_state_hash"`
				DerivationHash    string `graphql:"derivation_hash"`
			} `graphql:"proposed(where: {proposal_id: {_eq: $proposalID}})"`
		}

		if err := c.ShastaClients.Indexer.Query(ctxWithTimeout, &overwrittenProposalQuery, map[string]interface{}{
			"proposalID": overwrittenProposalID,
		}); err == nil && len(overwrittenProposalQuery.Proposals) > 0 {
			overwritten := overwrittenProposalQuery.Proposals[0]
			proposalsToConvert = append(proposalsToConvert, struct {
				ProposalID        uint64
				ProposalTimestamp uint64
				Proposer          string
				CoreStateHash     string
				DerivationHash    string
			}{
				ProposalID:        overwritten.ProposalID,
				ProposalTimestamp: overwritten.ProposalTimestamp,
				Proposer:          overwritten.Proposer,
				CoreStateHash:     overwritten.CoreStateHash,
				DerivationHash:    overwritten.DerivationHash,
			})
		}
	}

	// Query for proved transitions starting from LastFinalizedProposalId + 1
	// We need to get all proved events after LastFinalizedProposalId to check continuity
	var provedQuery struct {
		ProvedEvents []struct {
			ID                     uint64 `graphql:"id"`
			ProposalID             uint64 `graphql:"proposal_id"`
			Span                   uint8  `graphql:"span"`
			TransitionHash         string `graphql:"transition_hash"`
			EndBlockMiniHeaderHash string `graphql:"end_block_mini_header_hash"`
			// Checkpoint fields (we'll use from the latest proved event)
			EndBlockNumber    uint64 `graphql:"end_block_number"`
			EndBlockHash      string `graphql:"end_block_hash"`
			EndBlockStateRoot string `graphql:"end_block_state_root"`
			BlockNumber       uint64 `graphql:"block_number"`
		} `graphql:"proved(where: {proposal_id: {_gt: $lastFinalizedId}}, order_by: {proposal_id: asc, block_number: desc})"`
	}

	lastFinalizedID := uint64(0)
	if len(latestProposalQuery.Proposals) > 0 {
		lastFinalizedID = latestProposal.LastFinalizedProposalID
	}

	if err := c.ShastaClients.Indexer.Query(ctxWithTimeout, &provedQuery, map[string]interface{}{
		"lastFinalizedId": lastFinalizedID,
	}); err != nil {
		return nil, err
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
		NextProposalId:              new(big.Int).SetUint64(latestProposal.NextProposalID),
		LastFinalizedProposalId:     new(big.Int).SetUint64(latestProposal.LastFinalizedProposalID),
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

	for _, proved := range provedQuery.ProvedEvents {
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
