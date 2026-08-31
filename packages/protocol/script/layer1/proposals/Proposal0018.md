# PROPOSAL-0018: Unpause L1 Bridge and ERC20Vault

## Executive Summary

This proposal resumes Taiko bridge operations after the emergency pause proposals for the
[L1 Bridge](https://dao.taiko.xyz/plugins/community-proposals/#/proposals/29) and
[ERC20Vault](https://dao.taiko.xyz/plugins/community-proposals/#/proposals/30).

It executes **2 L1 actions** and **no L2 actions**:

1. Call `Bridge.unpause()`.
2. Call `ERC20Vault.unpause()`.

This resumes operations completely on chain and allows any user to bridge ETH and ERC20 tokens in
and out of Taiko freely.

## Actions

| Target        | Address                                      | Call        |
| ------------- | -------------------------------------------- | ----------- |
| `Bridge`      | `0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC` | `unpause()` |
| `ERC20Vault`  | `0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab` | `unpause()` |

There are no contract upgrades, parameter changes, token transfers, or L2 actions.
