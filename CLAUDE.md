# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🎯 Project Overview

Taiko is a based rollup on Ethereum that uses validity proofs for finalization. It's designed to be a type-1 (fully Ethereum-equivalent) ZK-EVM.

**Key Technical Aspects:**

- Based rollup architecture (L1-sequenced)
- Uses SGX and ZK proofs for block verification
- Multi-proof system supporting different proof tiers
- Contestable validity proofs with bonding mechanism
- Native Ethereum equivalence (type-1 ZK-EVM)

## 📦 Monorepo Architecture

```
packages/
├── protocol/           # Core smart contracts (Solidity, Foundry)
├── taiko-client/       # Go client (driver, proposer, prover)
├── taiko-client-rs/    # Rust client implementation
├── relayer/            # Bridge message relayer (Go)
├── eventindexer/       # Event indexing service (Go)
├── blobindexer-rs/     # Blob indexer (Rust)
├── bridge-ui/          # Bridge frontend (SvelteKit)
└── [other packages]    # UIs, NFTs, monitoring, tools
```

**Technology Stack:**

- Smart contracts: Solidity + Foundry
- Backend services: Go, Rust
- Frontend applications: TypeScript/SvelteKit
- Package management: pnpm workspaces

## 🚀 Essential Monorepo Commands

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

## 📋 Cross-Package Development Guidelines

- Changes affecting multiple packages should be tested together
- Use `pnpm link` for local package development
- Run integration tests when modifying shared dependencies
- Update package versions consistently
- Install pnpm packages first before working with Foundry: `pnpm install`

## 🔧 Tool Configuration & Usage

- **GitHub**: Use the GitHub CLI (`gh`) instead of direct API requests or curl requests
- **Package Management**: Use pnpm commands at the monorepo root for cross-package operations
- **Development**: Prefer package-specific commands when working within a single package
- **IDE**: Leverage VS Code extensions for Solidity, Go, Rust, and TypeScript development

## 🐛 Debugging Strategies

- **Smart contracts**: Use `forge test -vvvv` for maximum verbosity
- **Go services**: Use `dlv` debugger or extensive logging
- **Rust services**: Use `cargo test`, `RUST_BACKTRACE=1`, or `rust-lldb`
- **Frontend**: Use browser DevTools and SvelteKit's built-in debugging
- **General**: Use proper debuggers over console.log debugging

## 🔒 Security Best Practices

- Never commit sensitive data (private keys, API keys, etc.)
- Always validate user inputs
- Follow security best practices for each language/framework
- Implement rate limiting and DoS protection

## ⚡ Performance Optimization Principles

- Use efficient algorithms and data structures
- Profile and benchmark critical paths
- Consider caching strategies for frequently accessed data
- Optimize database queries in backend services

## 📝 Documentation Standards

- Update README files when adding new features
- Document complex algorithms and business logic
- Keep API documentation up to date
- Add inline comments for non-obvious code
- Update CHANGELOG.md for significant changes
- **ALWAYS** prefer simple, efficient code

### Solidity NatSpec Requirements

All Solidity functions must have NatSpec documentation following these rules:

1. **Interface functions**: Full NatSpec documentation (`@notice`, `@dev`, `@param`, `@return`) should be placed in the interface
2. **Implementation of interface functions**: Use `@inheritdoc InterfaceName` to inherit documentation from the interface. Only add additional `@dev` comments if there's implementation-specific behavior not covered by the interface
3. **Internal and private functions**: Only use `@dev`, `@param`, and `@return` tags (not `@notice`)

```solidity
// In interface
/// @notice Deposits tokens into the vault
/// @param _amount The amount to deposit
/// @return success_ Whether the deposit succeeded
function deposit(uint256 _amount) external returns (bool success_);

// In implementation
/// @inheritdoc IVault
function deposit(uint256 _amount) external returns (bool success_) { ... }

// Internal function
/// @dev Validates the deposit amount against minimum requirements
/// @param _amount The amount to validate
/// @return valid_ Whether the amount is valid
function _validateAmount(uint256 _amount) internal pure returns (bool valid_) { ... }
```

## ✅ CI/CD Requirements

### Testing Standards

- All tests must pass before merging
- Maintain test coverage above threshold (aim for >95%)
- Include unit, integration, and performance tests
- Test edge cases and error conditions
- Follow structured test patterns with proper isolation

### Code Review Checklist

- Review for security vulnerabilities
- Check for proper error handling
- Verify gas optimization for L1 contracts
- Ensure code follows style guidelines
- Look for potential race conditions in concurrent code
- Validate test quality and coverage

## 🔨 Troubleshooting Common Issues

1. **Compilation errors**: Run `pnpm clean` and `pnpm install`
2. **Test failures**: Check for recent dependency updates
3. **Gas limit issues**: Optimize contract code and storage usage
4. **Type errors**: Ensure TypeScript definitions are up to date
5. **Build failures**: Verify all dependencies are installed correctly

## 📬 Getting Help

- Check existing issues on GitHub
- Review documentation in each package
- Ask in developer channels
- Contact security team for security issues: security@taiko.xyz

---

**Note**: For protocol-specific development guidance, see `packages/protocol/CLAUDE.md`
