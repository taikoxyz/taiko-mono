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
├── taiko-client/      # Go client (driver, proposer, prover)
├── bridge-ui/         # Bridge frontend (SvelteKit)
├── relayer/           # Bridge message relayer (Go)
├── eventindexer/      # Event indexing service (Go)
└── [other packages]   # NFTs, monitoring, documentation
```

**Technology Stack:**

- Smart contracts: Solidity + Foundry
- Backend services: Go
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
- **IDE**: Leverage VS Code extensions for Solidity, Go, and TypeScript development

## 🐛 Debugging Strategies

- **Smart contracts**: Use `forge test -vvvv` for maximum verbosity
- **Go services**: Use `dlv` debugger or extensive logging
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
