-- Set schema
SET search_path TO indexer_shasta_inbox, public;

-- ============================================================================
-- PROPOSAL ANALYSIS VIEWS
-- ============================================================================

-- Daily summary of proposals
CREATE OR REPLACE VIEW proposal_summary AS
SELECT 
    DATE(block_timestamp) as date,
    network,
    COUNT(*) as proposal_count,
    COUNT(*) FILTER (WHERE is_forced_inclusion) as forced_inclusion_count,
    AVG(data_size) as avg_data_size,
    MAX(data_size) as max_data_size,
    MIN(data_size) as min_data_size,
    AVG(blob_count) as avg_blob_count,
    MAX(blob_count) as max_blob_count,
    COUNT(DISTINCT proposer) as unique_proposers
FROM proposed
GROUP BY DATE(block_timestamp), network;

-- Proposer activity analysis
CREATE OR REPLACE VIEW proposer_activity AS
SELECT 
    proposer,
    network,
    COUNT(*) as total_proposals,
    COUNT(*) FILTER (WHERE is_forced_inclusion) as forced_proposals,
    AVG(data_size) as avg_proposal_size,
    MIN(proposal_timestamp) as first_proposal_time,
    MAX(proposal_timestamp) as last_proposal_time,
    COUNT(DISTINCT DATE(block_timestamp)) as active_days
FROM proposed
GROUP BY proposer, network;

-- ============================================================================
-- PROOF ANALYSIS VIEWS
-- ============================================================================

-- Prover performance statistics
CREATE OR REPLACE VIEW prover_stats AS
SELECT 
    designated_prover,
    actual_prover,
    network,
    COUNT(*) as proof_count,
    COUNT(*) FILTER (WHERE is_designated_prover) as self_proven_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_designated_prover) / COUNT(*), 2) as self_proof_rate,
    AVG(data_size) as avg_proof_size,
    AVG(bond_instruction_count) as avg_bond_instructions,
    COUNT(DISTINCT proposal_id) as unique_proposals_proved
FROM proved
GROUP BY designated_prover, actual_prover, network;

-- Daily proof statistics
CREATE OR REPLACE VIEW proof_daily_stats AS
SELECT 
    DATE(block_timestamp) as date,
    network,
    COUNT(*) as total_proofs,
    COUNT(DISTINCT actual_prover) as unique_provers,
    COUNT(*) FILTER (WHERE is_designated_prover) as self_proofs,
    AVG(bond_instruction_count) as avg_bond_instructions,
    MAX(bond_instruction_count) as max_bond_instructions
FROM proved
GROUP BY DATE(block_timestamp), network;

-- ============================================================================
-- BOND INSTRUCTION ANALYSIS
-- ============================================================================

-- Bond instructions from all sources (proved and bond_instructed events)
CREATE OR REPLACE VIEW all_bond_instructions AS
SELECT 
    'proved' as source_type,
    p.id as source_id,
    p.tx_hash,
    p.block_number,
    p.block_timestamp,
    jsonb_array_elements(p.bond_instructions) as instruction
FROM proved p
WHERE jsonb_array_length(p.bond_instructions) > 0
UNION ALL
SELECT 
    'bond_instructed' as source_type,
    b.id as source_id,
    b.tx_hash,
    b.block_number,
    b.block_timestamp,
    jsonb_array_elements(b.bond_instructions) as instruction
FROM bond_instructed b
WHERE jsonb_array_length(b.bond_instructions) > 0;

-- Bond type statistics
CREATE OR REPLACE VIEW bond_type_stats AS
SELECT 
    instruction->>'bond_type_name' as bond_type_name,
    (instruction->>'bond_type')::int as bond_type,
    source_type,
    COUNT(*) as instruction_count,
    COUNT(DISTINCT (instruction->>'proposal_id')::bigint) as unique_proposals,
    COUNT(DISTINCT instruction->>'payer') as unique_payers,
    COUNT(DISTINCT instruction->>'receiver') as unique_receivers
FROM all_bond_instructions
GROUP BY instruction->>'bond_type_name', (instruction->>'bond_type')::int, source_type;

-- Payer/Receiver activity
CREATE OR REPLACE VIEW bond_participant_activity AS
SELECT 
    participant_address,
    participant_role,
    COUNT(*) as total_instructions,
    COUNT(DISTINCT (instruction->>'proposal_id')::bigint) as unique_proposals,
    COUNT(DISTINCT counterparty) as unique_counterparties
FROM (
    SELECT 
        instruction->>'payer' as participant_address,
        'payer' as participant_role,
        instruction->>'proposal_id' as proposal_id,
        instruction->>'receiver' as counterparty,
        instruction
    FROM all_bond_instructions
    UNION ALL
    SELECT 
        instruction->>'receiver' as participant_address,
        'receiver' as participant_role,
        instruction->>'proposal_id' as proposal_id,
        instruction->>'payer' as counterparty,
        instruction
    FROM all_bond_instructions
) participants
GROUP BY participant_address, participant_role;

-- ============================================================================
-- CROSS-EVENT ANALYSIS
-- ============================================================================

-- Recent activity across all event types
CREATE OR REPLACE VIEW recent_activity AS
SELECT 
    'proposed' as event_type,
    proposal_id::TEXT as event_id,
    proposer as primary_address,
    contract_address,
    tx_hash,
    block_number,
    block_timestamp,
    processed_at
FROM proposed
UNION ALL
SELECT 
    'proved' as event_type,
    proposal_id::TEXT as event_id,
    actual_prover as primary_address,
    contract_address,
    tx_hash,
    block_number,
    block_timestamp,
    processed_at
FROM proved
UNION ALL
SELECT 
    'bond_instructed' as event_type,
    'batch' as event_id,
    NULL as primary_address,
    contract_address,
    tx_hash,
    block_number,
    block_timestamp,
    processed_at
FROM bond_instructed
ORDER BY block_number DESC, processed_at DESC
LIMIT 100;

-- Proposal lifecycle view (join proposed and proved events)
CREATE OR REPLACE VIEW proposal_lifecycle AS
SELECT 
    p.proposal_id,
    p.proposer,
    p.proposal_timestamp,
    p.block_number as proposed_block,
    p.block_timestamp as proposed_time,
    pr.actual_prover,
    pr.designated_prover,
    pr.block_number as proved_block,
    pr.block_timestamp as proved_time,
    pr.bond_instruction_count,
    (EXTRACT(EPOCH FROM (pr.block_timestamp - p.block_timestamp))) as proof_delay_seconds,
    p.is_forced_inclusion,
    p.blob_count,
    pr.is_designated_prover
FROM proposed p
LEFT JOIN proved pr ON p.proposal_id = pr.proposal_id AND p.network = pr.network;

-- ============================================================================
-- PERFORMANCE METRICS
-- ============================================================================

-- Materialized view for performance analytics (refresh periodically)
DROP MATERIALIZED VIEW IF EXISTS performance_metrics;
CREATE MATERIALIZED VIEW performance_metrics AS
SELECT 
    network,
    DATE_TRUNC('hour', block_timestamp) as hour,
    COUNT(DISTINCT block_number) as blocks_processed,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE event_type = 'proposed') as proposed_events,
    COUNT(*) FILTER (WHERE event_type = 'proved') as proved_events,
    COUNT(*) FILTER (WHERE event_type = 'bond_instructed') as bond_events,
    AVG(EXTRACT(EPOCH FROM (processed_at - block_timestamp))) as avg_processing_delay_seconds
FROM (
    SELECT 'proposed' as event_type, network, block_number, block_timestamp, processed_at FROM proposed
    UNION ALL
    SELECT 'proved' as event_type, network, block_number, block_timestamp, processed_at FROM proved
    UNION ALL
    SELECT 'bond_instructed' as event_type, network, block_number, block_timestamp, processed_at FROM bond_instructed
) events
GROUP BY network, DATE_TRUNC('hour', block_timestamp);

-- Create index on materialized view
CREATE INDEX idx_performance_metrics_hour ON performance_metrics(hour);
CREATE INDEX idx_performance_metrics_network ON performance_metrics(network);

-- ============================================================================
-- BOND INSTRUCTION DETAILS VIEW
-- ============================================================================

-- Detailed view of all bond instructions with expanded fields
CREATE OR REPLACE VIEW bond_instruction_details AS
SELECT 
    source_type,
    source_id,
    tx_hash,
    block_number,
    block_timestamp,
    (instruction->>'proposal_id')::bigint as proposal_id,
    (instruction->>'bond_type')::int as bond_type,
    instruction->>'bond_type_name' as bond_type_name,
    instruction->>'payer' as payer,
    instruction->>'receiver' as receiver
FROM all_bond_instructions
ORDER BY block_number DESC, source_id;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON VIEW proposal_summary IS 'Daily summary of proposal events with key metrics';
COMMENT ON VIEW proposer_activity IS 'Activity statistics per proposer address';
COMMENT ON VIEW prover_stats IS 'Performance statistics for provers';
COMMENT ON VIEW proof_daily_stats IS 'Daily aggregated proof statistics';
COMMENT ON VIEW all_bond_instructions IS 'Combined view of bond instructions from both proved and bond_instructed events';
COMMENT ON VIEW bond_type_stats IS 'Statistics by bond instruction type';
COMMENT ON VIEW bond_participant_activity IS 'Activity for payers and receivers in bond instructions';
COMMENT ON VIEW recent_activity IS 'Most recent 100 events across all tables';
COMMENT ON VIEW proposal_lifecycle IS 'Combined view showing proposal and proof events';
COMMENT ON MATERIALIZED VIEW performance_metrics IS 'Hourly performance metrics - refresh with: REFRESH MATERIALIZED VIEW performance_metrics;';
COMMENT ON VIEW bond_instruction_details IS 'Detailed view of all bond instructions with expanded fields';