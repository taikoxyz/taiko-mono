# Database Migrations

This directory contains SQL migrations for the Shasta Indexer database with custom fields.

## Structure

- `001_create_schema.sql` - Creates the indexer_shasta_inbox schema
- `002_create_tables.sql` - Creates all tables with custom fields
- `003_create_views.sql` - Creates useful views and materialized views
- `init.sh` - Shell script to run all migrations

## Custom Fields Added

### `proposed` Table
- `data_size` - Auto-calculated size of proposal data
- `is_large_proposal` - Boolean flag for proposals > 1000 bytes
- `proposal_type` - Categorization (small/medium/large)
- `proposal_hash` - Optional hash of the proposal
- `processed_at` - Timestamp when the event was processed
- `processing_status` - Status of processing (pending/completed/failed)
- `metadata` - JSONB field for additional metadata

### `proved` Table
- `proof_size` - Auto-calculated size of proof data
- `proof_type` - Type of proof submitted
- `verification_status` - Verification status (unverified/verified/failed)
- `verified_at` - Timestamp of verification
- `processed_at` - Processing timestamp
- `metadata` - JSONB field for additional metadata

### `bond_instructed` Table
- `event_count` - Number of events in this transaction
- `processed_at` - Processing timestamp
- `processing_status` - Status of processing
- `metadata` - JSONB field for additional metadata

## Usage

### Quick Setup

```bash
# Set environment variables
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=shasta_indexer
export DB_USER=postgres
export DB_PASSWORD=yourpassword

# Run all migrations
cd migrations
./init.sh
```

### Manual Setup

```bash
# Connect to your database
psql -U postgres -d shasta_indexer

# Run each SQL file in order
\i 001_create_schema.sql
\i 002_create_tables.sql
\i 003_create_views.sql
```

### Docker Setup

```bash
# Using docker-compose
docker-compose exec postgres psql -U postgres -d shasta_indexer -f /migrations/001_create_schema.sql
docker-compose exec postgres psql -U postgres -d shasta_indexer -f /migrations/002_create_tables.sql
docker-compose exec postgres psql -U postgres -d shasta_indexer -f /migrations/003_create_views.sql
```

## Views

### `proposal_summary`
Daily aggregation of proposals by type and network.

### `recent_activity`
Shows the last 100 events across all tables.

### `verification_stats`
Daily statistics for proof verification.

### `performance_metrics` (Materialized)
Hourly performance metrics. Refresh with:
```sql
REFRESH MATERIALIZED VIEW indexer_shasta_inbox.performance_metrics;
```

## Notes

1. **Generated Columns**: Some fields like `data_size` and `proposal_type` are automatically calculated using PostgreSQL's GENERATED ALWAYS AS feature.

2. **Indexes**: All tables have indexes on commonly queried fields for optimal performance.

3. **JSONB Metadata**: The `metadata` field allows storing arbitrary JSON data without schema changes.

4. **Unique Constraints**: Each table has a unique constraint on `(tx_hash, log_index)` to prevent duplicate events.

## Maintenance

### Drop and Recreate
```bash
psql -U postgres -d shasta_indexer -c "DROP SCHEMA indexer_shasta_inbox CASCADE;"
./init.sh
```

### Add New Custom Fields
1. Create a new migration file (e.g., `004_add_custom_fields.sql`)
2. Use ALTER TABLE commands to add fields
3. Update the handler code to populate the new fields

### Backup
```bash
pg_dump -U postgres -d shasta_indexer -n indexer_shasta_inbox > backup.sql
```