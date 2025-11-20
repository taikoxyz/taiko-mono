# Optaiko

> A clean-room implementation of a Panoptic-style options protocol built on Uniswap V4

## Overview

Optaiko is an options trading protocol that leverages Uniswap V4 liquidity positions to create perpetual options with streaming premia. Unlike traditional options protocols, Optaiko represents options as positions within Uniswap V4 pools, where:

- **Short options** = Providing liquidity to earn fees (streaming premium)
- **Long options** = Conceptually "borrowing" liquidity (paying streaming premium)

## Key Features

- ✅ **Clean-Room Design**: Built from first principles without reference to existing implementations
- ✅ **Uniswap V4 Native**: Fully integrated with Uniswap V4's PoolManager
- ✅ **UUPS Upgradeable**: Uses OpenZeppelin's UUPS proxy pattern for safe upgradeability
- ✅ **Multi-Leg Positions**: Support for complex strategies (spreads, straddles, etc.)
- ✅ **Streaming Premia**: Continuous premium payments based on fee accrual
- ✅ **Comprehensive Documentation**: Full NatSpec and inline comments

## Architecture

### Core Components

```
contracts/
├── OptaikoCore.sol              # Main upgradeable contract
├── interfaces/
│   └── IOptaiko.sol            # External interface
└── libraries/
    ├── Errors.sol              # Custom errors
    └── PositionUtils.sol       # Position encoding/validation
```

### Contract Flow

1. **Mint Option**: User creates a position with one or more legs
   - Each leg defines: Long/Short, Tick Range, Liquidity
   - Short legs deposit liquidity to Uniswap V4
   - Long legs track borrowed liquidity

2. **Accrue Premia**: Streaming premia accumulates over time
   - Short positions earn fees from the pool
   - Long positions pay based on utilization

3. **Burn Option**: User closes their position
   - Removes liquidity from Uniswap V4
   - Settles all outstanding premia
   - Returns funds to user

## Installation

```bash
# Install dependencies
pnpm install

# Build contracts
pnpm build

# Run tests
pnpm test
```

## Usage

### Deploying the Contract

```solidity
// Deploy implementation
OptaikoCore implementation = new OptaikoCore();

// Deploy proxy
ERC1967Proxy proxy = new ERC1967Proxy(
    address(implementation),
    abi.encodeWithSelector(
        OptaikoCore.initialize.selector,
        poolManagerAddress,
        ownerAddress
    )
);

OptaikoCore optaiko = OptaikoCore(address(proxy));
```

### Minting an Option

```solidity
// Create a long call option
PositionUtils.Leg[] memory legs = new PositionUtils.Leg[](1);
legs[0] = PositionUtils.Leg({
    isLong: true,
    tickLower: -60,
    tickUpper: 60,
    liquidity: 1000e18
});

bytes32 poolId = /* Uniswap V4 pool ID */;
uint256 positionId = optaiko.mintOption(poolId, legs);
```

### Closing a Position

```solidity
optaiko.burnOption(positionId);
```

## Testing

The test suite includes:

- ✅ Deployment and initialization
- ✅ Single-leg option minting
- ✅ Multi-leg strategies
- ✅ Position burning
- ✅ UUPS upgradeability
- ✅ Access control

Run tests with:

```bash
forge test -vv
```

## Security

- **Upgradeability**: Only the contract owner can authorize upgrades
- **Reentrancy Protection**: All external functions use `nonReentrant` modifier
- **Access Control**: Owner-only admin functions
- **Validation**: Comprehensive input validation on all user actions

## Conceptual Model

This implementation is based on the following principles:

1. **Options as Liquidity Positions**: Options are represented as ranges of liquidity in Uniswap V4 pools
2. **Streaming Premia**: Instead of one-time premiums, premia streams continuously based on fees
3. **Multi-Leg Strategies**: Complex strategies are built by combining multiple simple positions
4. **Collateralization**: Positions are fully collateralized through Uniswap V4 liquidity

## Development Status

This is an initial implementation focusing on:
- ✅ Core architecture and upgradeability
- ✅ Comprehensive documentation
- ✅ Basic position management
- 🚧 Full Uniswap V4 integration (requires actual PoolManager deployment)
- 🚧 Premium calculation logic
- 🚧 Collateral management
- 🚧 Liquidation mechanisms

## License

MIT

## Contributing

This is a clean-room implementation. All contributions must be original work and cannot reference existing protocol implementations.

---

Built with ❤️ by the Optaiko team
