# SafeCastUpgradeable







*Wrappers over Solidity&#39;s uintXX/intXX casting operators with added overflow checks. Downcasting from uint256/int256 in Solidity does not revert on overflow. This can easily result in undesired exploitation or bugs, since developers usually assume that overflows raise errors. `SafeCast` restores this intuition by reverting the transaction when such an operation overflows. Using this library instead of the unchecked operations eliminates an entire class of bugs, so it&#39;s recommended to use it always. Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing all math on `uint256` and `int256` and then downcasting.*



