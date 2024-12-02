---
title: TaikoL2
description: Taiko protocol page for "TaikoL2.sol".
---

## TaikoL2

[TaikoL2](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/contracts/layer2/based/TaikoL2.sol) is a smart contract that handles cross-layer message verification and manages EIP-1559 gas pricing for Taiko operations. It is used to anchor the latest L1 block details to L2 for cross-layer communication, manage EIP-1559 parameters for gas pricing, and store verified L1 block information.

### Core Purpose:

`Anchor`: Due to its based rollup nature, Taiko needs the latest L1 block details to continue. The first transaction of each block is always this anchor, otherwise all calls will revert with `L2_PUBLIC_INPUT_HASH_MISMATCH`.


`getBasefee`: Calculates the base fee and gas excess using EIP-1559 configuration for the given paramateres such as `_parentGasUsed`, `_baseFeeConfig` etc.

Please see [Bridging](/taiko-protocol/bridging) page for information about L1<>L2 communication.
