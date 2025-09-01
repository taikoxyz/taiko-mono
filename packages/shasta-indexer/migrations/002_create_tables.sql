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
-- Stores both raw event and decoded ProvedEventPayload data
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
-- PROVED BOND INSTRUCTIONS TABLE
-- Stores individual bond instructions from Proved events
-- ============================================================================
CREATE TABLE proved_bond_instructions (
    id BIGSERIAL PRIMARY KEY,

    -- Reference to the proved event
    proved_id BIGINT NOT NULL REFERENCES proved(id) ON DELETE CASCADE,

    -- BondInstruction fields
    proposal_id BIGINT NOT NULL, -- uint48
    bond_type SMALLINT NOT NULL, -- BondType enum (uint8)
    bond_type_name VARCHAR(20) NOT NULL, -- Human-readable bond type
    payer VARCHAR(42) NOT NULL, -- address
    receiver VARCHAR(42) NOT NULL, -- address

    -- Transaction metadata (for convenience)
    tx_hash CHAR(66) NOT NULL,
    block_number BIGINT NOT NULL,

    -- Constraints
    CONSTRAINT check_proved_bond_type CHECK (bond_type >= 0 AND bond_type <= 255)
);

-- ============================================================================
-- BOND INSTRUCTED EVENT TABLE
-- Stores individual bond instructions from BondInstructed events
-- Each row represents one BondInstruction
-- ============================================================================
CREATE TABLE bond_instructed (
    id BIGSERIAL PRIMARY KEY,

    -- BondInstruction fields
    proposal_id BIGINT NOT NULL, -- uint48
    bond_type SMALLINT NOT NULL, -- BondType enum (uint8)
    bond_type_name VARCHAR(20) NOT NULL, -- Human-readable bond type
    payer VARCHAR(42) NOT NULL, -- address
    receiver VARCHAR(42) NOT NULL, -- address

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
CREATE INDEX idx_proposed_core_state_hash ON proposed(core_state_hash);

-- Indexes for proved table
CREATE INDEX idx_proved_proposal_id ON proved(proposal_id);
CREATE INDEX idx_proved_block_number ON proved(block_number);
CREATE INDEX idx_proved_tx_hash ON proved(tx_hash);
CREATE INDEX idx_proved_transition_hash ON proved(transition_hash);

-- Indexes for proved_bond_instructions table
CREATE INDEX idx_proved_bond_instructions_proved_id ON proved_bond_instructions(proved_id);
CREATE INDEX idx_proved_bond_instructions_proposal_id ON proved_bond_instructions(proposal_id);
CREATE INDEX idx_proved_bond_instructions_block_numbe ON proved_bond_instructions(block_number);
CREATE INDEX idx_proved_bond_instructions_tx_hash ON proved_bond_instructions(tx_hash);

-- Indexes for bond_instructed table
CREATE INDEX idx_bond_instructed_proposal_id ON bond_instructed(proposal_id);
CREATE INDEX idx_bond_instructed_block_number ON bond_instructed(block_number);
CREATE INDEX idx_bond_instructed_tx_hash ON bond_instructed(tx_hash);
