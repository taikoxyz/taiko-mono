# Incremental Implementation Plan

## Overview

This document outlines a step-by-step approach to building the Taiko L1 Cost Calculator, starting with basic event monitoring and progressively adding features.

## Step 1: Barebone Event Subscription (Current)

**Goal**: Subscribe to TaikoInbox events and print them to console

### Features:

- Connect to Ethereum RPC
- Subscribe to BatchProposed, BatchesProved, and BatchesVerified events
- Print raw event data to console
- Handle block ranges (historical and live monitoring)

### Files to create:

- `step1_event_monitor.py` - Main script
- `requirements.txt` - Dependencies
- `.env.example` - Configuration template

## Step 2: Event Data Analysis

**Goal**: Parse events and calculate costs without database

### Features:

- Parse event data structures
- Calculate transaction costs (gas \* price)
- Allocate costs across multiple batches/events
- Track transition IDs in memory
- Display formatted cost information

### Enhancements:

- Add cost calculation logic
- Format output with batch IDs, costs, addresses
- Track state in memory (batch -> transitions mapping)

## Step 3: Contract State Queries

**Goal**: Query TaikoInbox for verification data

### Features:

- Query v4GetBatchVerifyingTransition for verified batches
- Match verifying transitions with proving costs
- Calculate final batch costs (proposing + proving)
- Display complete batch lifecycle

### Enhancements:

- Add contract ABI and interaction
- Implement verification logic
- Show which transition verified each batch

## Step 4: Database Persistence

**Goal**: Store all data in MySQL

### Features:

- Database schema creation
- Store batches, transitions, and state
- Handle reorgs (delete and reprocess blocks)
- Implement CLI with resume/restart options
- Add summary tables

### Enhancements:

- Add database layer
- Implement transaction management
- Add CLI interaction for startup options
- Continuous monitoring with state persistence

## Step 5: Production Ready (Optional)

**Goal**: Production deployment features

### Features:

- Comprehensive error handling
- Logging configuration
- Docker support
- Monitoring/metrics
- Performance optimizations
