## V1Utils

### MASK_HALT

```solidity
uint64 MASK_HALT
```

### WhitelistingEnabled

```solidity
event WhitelistingEnabled(bool whitelistProposers, bool whitelistProvers)
```

### ProposerWhitelisted

```solidity
event ProposerWhitelisted(address proposer, bool whitelisted)
```

### ProverWhitelisted

```solidity
event ProverWhitelisted(address prover, bool whitelisted)
```

### Halted

```solidity
event Halted(bool halted)
```

### enableWhitelisting

```solidity
function enableWhitelisting(struct LibData.TentativeState tentative, bool whitelistProposers, bool whitelistProvers) internal
```

### whitelistProposer

```solidity
function whitelistProposer(struct LibData.TentativeState tentative, address proposer, bool whitelisted) internal
```

### whitelistProver

```solidity
function whitelistProver(struct LibData.TentativeState tentative, address prover, bool whitelisted) internal
```

### halt

```solidity
function halt(struct LibData.State state, bool toHalt) internal
```

### isHalted

```solidity
function isHalted(struct LibData.State state) internal view returns (bool)
```

### isProposerWhitelisted

```solidity
function isProposerWhitelisted(struct LibData.TentativeState tentative, address proposer) internal view returns (bool)
```

### isProverWhitelisted

```solidity
function isProverWhitelisted(struct LibData.TentativeState tentative, address prover) internal view returns (bool)
```

### uncleProofDeadline

```solidity
function uncleProofDeadline(struct LibData.State state, struct LibData.ForkChoice fc) internal view returns (uint64)
```

### setBit

```solidity
function setBit(struct LibData.State state, uint64 mask, bool one) private
```

### isBitOne

```solidity
function isBitOne(struct LibData.State state, uint64 mask) private view returns (bool)
```

