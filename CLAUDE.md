# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Taiko is a based rollup on Ethereum that uses validity proofs for finalization. The monorepo uses pnpm workspaces and contains smart contracts (Foundry), Go services, and TypeScript frontends.

## Repository Structure

```
packages/
├── protocol/           # Core smart contracts (Solidity, Foundry)
├── taiko-client/      # Go client (driver, proposer, prover)
├── bridge-ui/         # Bridge frontend (SvelteKit)
├── relayer/           # Bridge message relayer (Go)
├── eventindexer/      # Event indexing service (Go)
└── [other packages]   # NFTs, monitoring, documentation
```

## Smart Contract Development (packages/protocol)

### Commands
```bash
# Compilation
pnpm compile              # All contracts
pnpm compile:l1          # Layer 1 only
pnpm compile:l2          # Layer 2 only

# Testing
pnpm test                # Run all tests
pnpm test:l1            # L1 tests (uses FOUNDRY_PROFILE=layer1)
pnpm test:l2            # L2 tests (uses FOUNDRY_PROFILE=layer2)
pnpm test:coverage      # Generate coverage report

# Single test execution
forge test --match-test <name>   # Test by name
forge test --match-path <path>   # Test by file
forge test -vvvv                # Debug with max verbosity

# Gas & Storage
pnpm snapshot:l1        # Generate gas report
pnpm layout             # Generate storage layouts (critical before upgrades)

# Code Quality
pnpm fmt:sol            # Format Solidity code
```

### pnpm and Foundry Integration

- Install pnpm packages first before working with Foundry: `pnpm install`
- Foundry relies on compiled dependencies and packages managed by pnpm
- Always run `pnpm compile` before Foundry commands to ensure all dependencies are correctly prepared
- Some Foundry commands like `forge test` will use compiled artifacts from the pnpm workspace
- When switching between Foundry profiles (L1/L2), ensure packages are installed and compiled

### Architecture & Standards

**Contract Structure:**
- Layer separation: `layer1/`, `layer2/`, `shared/`
- UUPS upgradeable pattern with OpenZeppelin
- Resolver pattern for cross-contract discovery
- Storage gaps (`uint256[50] __gap`) for upgrade safety

**Key Contracts:**
- `TaikoInbox`: Main L1 entry point for batch proposals/proofs
- `Bridge`: Cross-chain message passing infrastructure
- `SignalService`: Cross-chain signal propagation
- `Anchor`: L2 contracts that sync L1 state

**Testing Standards:**
- Tests mirror contract structure under `test/`
- Inherit from `CommonTest`, `Layer1Test`, or `Layer2Test`
- Use provided test accounts (Alice, Bob, Carol)
- Multi-chain testing with `onEthereum()`/`onTaiko()`

**Before Submitting Changes:**
1. Run full test suite: `pnpm test`
2. Check coverage: `pnpm test:coverage`
3. Verify storage layout: `pnpm layout` (compare before/after)
4. Format code: `pnpm fmt:sol`
5. Check gas impact: `pnpm snapshot:l1`

### Gas considerations
- Any contract that lives on the L1 needs to be optimized, and gas consumption is very important
- When working or reviewing gas optimizations always run:
   - `pnpm snapshot:l1` and review the diffs in gas consumption per function. You can find them in `packages/protocol/gas-reports/layer1-contracts.txt` file. This shows the gas used by each test.
   - You can also review the diffs in gas from the other folders inside `packages/protocol/gas-reports/`. These are written using Foundry's new `snapshotGas` cheatcodes and are inserted in strategic sections of the tests where we want to capture gas usage. These are updated automatically when running the tests.

## Taiko Client (packages/taiko-client)
```bash
# Build
make build

# Test
make test               # Integration tests
PACKAGE=<path> make test  # Specific package

# Development
make dev_net           # Start dev network
make lint              # Run linters
make gen_bindings      # Generate Go bindings
```

## Bridge UI (packages/bridge-ui)
```bash
# Development
pnpm dev               # Dev server
pnpm dev:a3           # A3 mode

# Build
pnpm build            # Production build
pnpm generate:abi     # Generate TypeScript bindings

# Test
pnpm test:unit        # Unit tests
pnpm test:pw          # E2E tests
pnpm test:unit:watch  # Watch mode

# Code quality
pnpm lint             # Check formatting
pnpm lint:fix        # Auto-fix issues
pnpm svelte:check     # Type-check
```

### Go Services (eventindexer, relayer, balance-monitor)
```bash
# Standard Go commands
go build ./...
go test ./...
go run ./cmd/main.go
```

## Architecture Overview

### Protocol Layer
- **TaikoInbox** (L1): Main protocol entry point, handles batch proposals and proofs
- **Verifiers**: Multiple proof verification strategies (SGX, SP1, RISC Zero)
- **Anchor Contracts** (L2): Sync L1 state to L2, implement EIP-1559
- **Fork Routers**: Handle protocol upgrades (Pacaya, Shasta)

### Bridge System
- **Bridge.sol**: Core cross-chain messaging with gas management
- **Token Vaults**: Handle ERC20/721/1155 token bridging
- **SignalService**: Cross-chain signal(message) propagation
- **Relayer**: Automated message processing service with MySQL storage

### Client Components
- **Driver**: Syncs L2 execution engine with TaikoInbox
- **Proposer**: Proposes blocks from L2 mempool (calldata/blob strategies)
- **Prover**: Generates proofs using configured backends

### Event Infrastructure
- **Eventindexer**: Captures blockchain events into MySQL
- **API Layer**: REST endpoints for querying indexed data
- **Balance Monitor**: Tracks address balances with Prometheus metrics

## Key Patterns

### Configuration
- Environment-based configs with JSON schemas
- Base64 encoding for complex configurations
- Separate configs per environment (dev/prod)

### Cross-Chain Communication
1. User initiates message on source chain
2. Bridge contract emits MessageSent event
3. Relayer indexes event and waits for confirmations
4. Relayer generates merkle proof
5. Relayer processes message on destination chain

### Testing Strategy
- Solidity: Foundry tests with pattern matching
- Go: testify suites with Docker integration
- Frontend: Vitest (unit) + Playwright (E2E)

### Database Schema
- Events table: Stores all indexed events
- Transactions table: Block metadata
- Account/Balance tables: Token holdings
- Migrations in each service's migrations/ directory


## Important Files and Directories

- `packages/protocol/contracts/layer1/inbox/TaikoInbox.sol` - Main protocol contract. It is the entrypoint for proposing and proving
- `packages/protocol/contracts/shared/signal/SignalService.sol` - Messaging service
- `packages/protocol/contracts/shared/bridge/Bridge.sol` - Bridge implementation
- `packages/taiko-client/driver/driver.go` - L2 sync logic
- `packages/bridge-ui/src/libs/bridge/` - Bridge frontend logic
- `packages/relayer/processor/process_message.go` - Message processing
- `packages/eventindexer/indexer/indexer.go` - Event indexing logic


## GitHub Interactions

- When interacting with gh use the github cli(`gh`) instead of doing direct api requests or curl requests. You can find the docs here: https://cli.github.com/manual/