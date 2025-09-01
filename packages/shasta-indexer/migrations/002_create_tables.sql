-- Set schema
SET search_path TO indexer_shasta_inbox, public;

-- Drop tables if exists (optional, remove in production)
DROP TABLE IF EXISTS bond_instructed CASCADE;
DROP TABLE IF EXISTS proposed CASCADE;
DROP TABLE IF EXISTS proved CASCADE;

-- ============================================================================
-- PROPOSED EVENT TABLE
-- Stores both raw event and decoded ProposedEventPayload data
-- ============================================================================
CREATE TABLE proposed (
    id BIGSERIAL PRIMARY KEY,

    -- Raw event data
    data BYTEA NOT NULL, -- The encoded bytes from the event

    -- Decoded Proposal fields
    proposal_id BIGINT NOT NULL, -- uint48
    proposer VARCHAR(42) NOT NULL,
    proposal_timestamp BIGINT NOT NULL, -- uint48
    core_state_hash CHAR(66) NOT NULL,
    derivation_hash CHAR(66) NOT NULL,

    -- Decoded Derivation fields
    origin_block_number BIGINT NOT NULL, -- uint48
    origin_block_hash CHAR(66), -- Not in compact encoding, can be NULL
    is_forced_inclusion BOOLEAN NOT NULL,
    basefee_sharing_pctg SMALLINT NOT NULL, -- uint8

    -- Decoded BlobSlice fields
    blob_hashes TEXT[], -- Array of bytes32 as hex strings
    blob_offset INTEGER NOT NULL, -- uint24
    blob_timestamp BIGINT NOT NULL, -- uint48

    -- Decoded CoreState fields
    next_proposal_id BIGINT NOT NULL, -- uint48
    last_finalized_proposal_id BIGINT NOT NULL, -- uint48
    last_finalized_transition_hash CHAR(66) NOT NULL,
    bond_instructions_hash CHAR(66) NOT NULL,

    -- Transaction metadata
    contract_address VARCHAR(42) NOT NULL,
    tx_hash CHAR(66) NOT NULL,
    block_number BIGINT NOT NULL,
    block_timestamp TIMESTAMP WITH TIME ZONE,
    block_hash CHAR(66) NOT NULL,
    network VARCHAR(50) NOT NULL,
    tx_index BIGINT NOT NULL,
    log_index NUMERIC NOT NULL,

    -- Processing metadata
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Computed fields
    blob_count INTEGER GENERATED ALWAYS AS (array_length(blob_hashes, 1)) STORED,
    data_size INTEGER GENERATED ALWAYS AS (octet_length(data)) STORED,

    -- Constraints
    CONSTRAINT unique_proposed UNIQUE (tx_hash, log_index),
    CONSTRAINT check_proposal_id CHECK (proposal_id >= 0),
    CONSTRAINT check_basefee_sharing CHECK (basefee_sharing_pctg >= 0 AND basefee_sharing_pctg <= 255)
);

-- ============================================================================
-- PROVED EVENT TABLE
-- Stores both raw event and decoded ProvedEventPayload data including bond instructions
-- ============================================================================
CREATE TABLE proved (
    id BIGSERIAL PRIMARY KEY,

    -- Raw event data
    data BYTEA NOT NULL, -- The encoded bytes from the event

    -- Decoded fields
    proposal_id BIGINT NOT NULL, -- uint48

    -- Transition fields
    proposal_hash CHAR(66) NOT NULL,
    parent_transition_hash CHAR(66) NOT NULL,

    -- endBlockMiniHeader fields
    end_block_number BIGINT NOT NULL, -- uint48
    end_block_hash CHAR(66) NOT NULL,
    end_block_state_root CHAR(66) NOT NULL,

    -- Prover fields
    designated_prover VARCHAR(42) NOT NULL,
    actual_prover VARCHAR(42) NOT NULL,

    -- TransitionRecord fields
    span SMALLINT NOT NULL, -- uint8
    transition_hash CHAR(66) NOT NULL,
    end_block_mini_header_hash CHAR(66) NOT NULL,

    -- Bond instructions (stored as JSONB array for flexibility)
    bond_instructions JSONB NOT NULL DEFAULT '[]'::JSONB,
    bond_instruction_count INTEGER NOT NULL DEFAULT 0,

    -- Transaction metadata
    contract_address VARCHAR(42) NOT NULL,
    tx_hash CHAR(66) NOT NULL,
    block_number BIGINT NOT NULL,
    block_timestamp TIMESTAMP WITH TIME ZONE,
    block_hash CHAR(66) NOT NULL,
    network VARCHAR(50) NOT NULL,
    tx_index BIGINT NOT NULL,
    log_index NUMERIC NOT NULL,

    -- Processing metadata
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Computed fields
    data_size INTEGER GENERATED ALWAYS AS (octet_length(data)) STORED,
    is_designated_prover BOOLEAN GENERATED ALWAYS AS (designated_prover = actual_prover) STORED,

    -- Constraints
    CONSTRAINT unique_proved UNIQUE (tx_hash, log_index),
    CONSTRAINT check_proved_proposal_id CHECK (proposal_id >= 0),
    CONSTRAINT check_span CHECK (span >= 0 AND span <= 255)
);

-- ============================================================================
-- BOND INSTRUCTED EVENT TABLE
-- Stores both raw event and decoded bond instructions
-- ============================================================================
CREATE TABLE bond_instructed (
    id BIGSERIAL PRIMARY KEY,

    -- Raw event data (contains array of BondInstruction)
    data BYTEA NOT NULL,

    -- Bond instructions (stored as JSONB array for flexibility)
    bond_instructions JSONB NOT NULL DEFAULT '[]'::JSONB,
    instruction_count INTEGER NOT NULL DEFAULT 0,

    -- Transaction metadata
    contract_address VARCHAR(42) NOT NULL,
    tx_hash CHAR(66) NOT NULL,
    block_number BIGINT NOT NULL,
    block_timestamp TIMESTAMP WITH TIME ZONE,
    block_hash CHAR(66) NOT NULL,
    network VARCHAR(50) NOT NULL,
    tx_index BIGINT NOT NULL,
    log_index NUMERIC NOT NULL,

    -- Processing metadata
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Constraints
    CONSTRAINT unique_bond_instructed UNIQUE (tx_hash, log_index)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Indexes for proposed table
CREATE INDEX idx_proposed_proposal_id ON proposed(proposal_id);
CREATE INDEX idx_proposed_proposer ON proposed(proposer);
CREATE INDEX idx_proposed_block_number ON proposed(block_number);
CREATE INDEX idx_proposed_tx_hash ON proposed(tx_hash);
CREATE INDEX idx_proposed_contract_address ON proposed(contract_address);
CREATE INDEX idx_proposed_core_state_hash ON proposed(core_state_hash);
CREATE INDEX idx_proposed_derivation_hash ON proposed(derivation_hash);
CREATE INDEX idx_proposed_is_forced_inclusion ON proposed(is_forced_inclusion);
CREATE INDEX idx_proposed_processed_at ON proposed(processed_at);

-- Indexes for proved table
CREATE INDEX idx_proved_proposal_id ON proved(proposal_id);
CREATE INDEX idx_proved_block_number ON proved(block_number);
CREATE INDEX idx_proved_tx_hash ON proved(tx_hash);
CREATE INDEX idx_proved_contract_address ON proved(contract_address);
CREATE INDEX idx_proved_designated_prover ON proved(designated_prover);
CREATE INDEX idx_proved_actual_prover ON proved(actual_prover);
CREATE INDEX idx_proved_transition_hash ON proved(transition_hash);
CREATE INDEX idx_proved_is_designated_prover ON proved(is_designated_prover);
CREATE INDEX idx_proved_processed_at ON proved(processed_at);
-- GIN index for JSONB bond_instructions
CREATE INDEX idx_proved_bond_instructions ON proved USING GIN (bond_instructions);

-- Indexes for bond_instructed table
CREATE INDEX idx_bond_instructed_block_number ON bond_instructed(block_number);
CREATE INDEX idx_bond_instructed_tx_hash ON bond_instructed(tx_hash);
CREATE INDEX idx_bond_instructed_contract_address ON bond_instructed(contract_address);
-- GIN index for JSONB bond_instructions
CREATE INDEX idx_bond_instructed_bond_instructions ON bond_instructed USING GIN (bond_instructions);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE proposed IS 'Stores Proposed events from ShastaInbox contract with decoded ProposedEventPayload data';
COMMENT ON TABLE proved IS 'Stores Proved events from ShastaInbox contract with decoded ProvedEventPayload data including bond instructions';
COMMENT ON TABLE bond_instructed IS 'Stores BondInstructed events from ShastaInbox contract with decoded bond instructions';

COMMENT ON COLUMN proposed.proposal_id IS 'The proposal ID (uint48 from Proposal.id)';
COMMENT ON COLUMN proposed.blob_hashes IS 'Array of blob hashes from BlobSlice.blobHashes';
COMMENT ON COLUMN proposed.is_forced_inclusion IS 'Whether this is a forced inclusion from Derivation.isForcedInclusion';

COMMENT ON COLUMN proved.span IS 'The span value from TransitionRecord.span';
COMMENT ON COLUMN proved.is_designated_prover IS 'True if the designated prover and actual prover are the same';
COMMENT ON COLUMN proved.bond_instructions IS 'JSONB array of bond instructions with structure: {proposal_id, bond_type, bond_type_name, payer, receiver}';

COMMENT ON COLUMN bond_instructed.bond_instructions IS 'JSONB array of bond instructions with structure: {proposal_id, bond_type, bond_type_name, payer, receiver}';