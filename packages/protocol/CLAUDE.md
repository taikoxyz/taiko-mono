# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Taiko is a based rollup on Ethereum that uses validity proofs for finalization. It's designed to be a type-1 (fully Ethereum-equivalent) ZK-EVM.

**Key Technical Aspects:**

- Based rollup architecture (L1-sequenced)
- Uses SGX and ZK proofs for block verification
- Multi-proof system supporting different proof tiers
- Contestable validity proofs with bonding mechanism
- Native Ethereum equivalence (type-1 ZK-EVM)

**Monorepo Structure:**

- Uses pnpm workspaces for package management
- Smart contracts built with Foundry
- Backend services written in Go
- Frontend applications using TypeScript/SvelteKit

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

### Coding Style

- Use newer solidity syntax
- Private state variables and private or internal functions should be prefixed with an underscore
- Event names should be in the past tense
- Use named imports
  - YES: `import {Contract} from "./contract.sol"`
  - NO: `import "./contract.sol"`
- Prefer straightforward custom errors over require strings and avoid natspec comments for errors, always put errors at the end of the implementation file, not in the interface.
- For larger files, have clear separators between external & public, internal, private functions, and errors.
  ```
  // -------------------------------------------------------------------------
  // Group label
  // -------------------------------------------------------------------------
  ```
- Always make sure there is a "/// @custom:security-contact security@taiko.xyz" for solidity files (test not included), and ensure license is MIT (all solidity files)
- Use `///` comments for natspec. Only external and public functions should have a `@notice`, while internal or private only have `@dev`
- Use named parameters on mapping definitions
- Function parameters should always start with "_", and return values should always end with "_"
- Always use `require` statements with custom errors instead of `if-revert` patterns
  - YES: `require(condition, ErrorName())`
  - NO: `if (!condition) revert ErrorName()`
- Use consistent code separators for larger files with these exact labels only:

  ```
  // -------------------------------------------------------------------------
  // Group Labels
  // -------------------------------------------------------------------------
  ```

  Where only the following labels are used:

  - Structs
  - Events
  - Variables
  - Constants
  - Immutables
  - State variables
  - Constructor
  - External functions
  - Internal functions
  - Private functions
  - Errors

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
- Compile contracts and run tests using pnpm commands (that will use forge under the hood with the right profiles)

### Architecture & Standards

**Contract Structure:**

- Layer separation: `layer1/`, `layer2/`, `shared/`
- UUPS upgradeable pattern with OpenZeppelin
- Resolver pattern for cross-contract discovery
- Storage gaps (`uint256[50] __gap`) for upgrade safety (applicable only to upgradeable contracts)

**Testing Standards:**

- Tests mirror contract structure under `test/`
- Inherit from `CommonTest`, `Layer1Test`, or `Layer2Test`
- Use provided test accounts (Alice, Bob, Carol)
- Multi-chain testing with `onEthereum()`/`onTaiko()`

**Before Submitting Changes:**

1. Format code: `pnpm fmt:sol`
2. Run full test suite: `pnpm test`
3. Check coverage: `pnpm test:coverage`
4. Verify storage layout: `pnpm layout` (compare before/after)
5. Check gas impact: `pnpm snapshot:l1`

### Gas Considerations

- Any contract that lives on the L1 needs to be optimized, and gas consumption is very important. Minimize storage writes and reads as much as possible.
- When working or reviewing gas optimizations always run:
  - `pnpm snapshot:l1` and review the diffs in gas consumption per test. You can find them in `packages/protocol/gas-reports/layer1-contracts.txt` file. This shows the gas used by each test.
  - You can also review the diffs in gas from the other files inside `packages/protocol/gas-reports/`. These are written using Foundry's new `snapshotGas` cheatcodes and are inserted in strategic sections of the tests where we want to capture gas usage. These are updated automatically when running `forge test`.

## Common Tasks

### Working with the Monorepo

```bash
# Install all dependencies
pnpm install

# Build all packages
pnpm build

# Run specific package commands
pnpm --filter @taiko/protocol test
pnpm --filter @taiko/bridge-ui dev
pnpm --filter @taiko/taiko-client build

# Clean and reinstall
pnpm clean && pnpm install
```

### Cross-Package Development

- Changes affecting multiple packages should be tested together
- Use `pnpm link` for local package development
- Run integration tests when modifying shared dependencies
- Update package versions consistently

### Debugging Tips

- For smart contracts: Use `forge test -vvvv` for maximum verbosity
- For Go services: Use `dlv` debugger or extensive logging
- For frontend: Use browser DevTools and SvelteKit's built-in debugging
- Use `console.log` debugging sparingly, prefer proper debuggers

## Important Notes

### Security

- Never commit sensitive data (private keys, API keys, etc.)
- Always validate user inputs
- Follow security best practices for each language/framework
- Use the security contact for any security-related issues
- Run security audits on smart contracts before deployment
- Implement rate limiting and DoS protection

### Performance

- L1 contracts must be gas-optimized
- Minimize storage operations in smart contracts
- Use efficient algorithms and data structures
- Profile and benchmark critical paths
- Consider caching strategies for frequently accessed data
- Optimize database queries in backend services

### Documentation

- Update README files when adding new features
- Document complex algorithms and business logic
- Keep API documentation up to date
- Add inline comments for non-obvious code
- Update CHANGELOG.md for significant changes

## CI/CD and Deployment

### Testing Requirements

- All tests must pass before merging
- Maintain test coverage above threshold
- Include unit and integration tests
- Test edge cases and error conditions

### Code Review Guidelines

- Review for security vulnerabilities
- Check for proper error handling
- Verify gas optimization for L1 contracts
- Ensure code follows style guidelines
- Look for potential race conditions in concurrent code

## Tool Usage

- When interacting with GitHub, use the GitHub CLI (`gh`) instead of doing direct API requests or curl requests. You can find the docs here: https://cli.github.com/manual/
- Use pnpm commands at the monorepo root for cross-package operations
- Prefer package-specific commands when working within a single package
- Use appropriate debugging tools for each technology stack
- Leverage VS Code extensions for Solidity, Go, and TypeScript development

## Troubleshooting

### Common Issues

1. **Compilation errors**: Run `pnpm clean` and `pnpm install`
2. **Test failures**: Check for recent dependency updates
3. **Gas limit issues**: Optimize contract code and storage usage
4. **Type errors**: Ensure TypeScript definitions are up to date
5. **Build failures**: Verify all dependencies are installed correctly

### Getting Help

- Check existing issues on GitHub
- Review documentation in each package
- Ask in developer channels
- Contact security team for security issues: security@taiko.xyz
