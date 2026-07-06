# PROPOSAL-0005: Transfer TAIKO Tokens from Controller back to Treasury

## Executive Summary

This proposal transfers all TAIKO tokens held by the DAO Controller (controller.taiko.eth) -- approximately 94 million TAIKO tokens -- to the Taiko Foundation Treasury (treasury.taiko.eth). This transfer aligns with the Foundation's governance framework for treasury asset management. The transfer is a non-voting organizational measure that does not affect token voting dynamics or token supply, as both the Controller and Treasury addresses are non-voting accounts.

### Address Verification

| Entity              | Address                                      | ENS Name             |
| ------------------- | -------------------------------------------- | -------------------- |
| TAIKO Token         | `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` | token.taiko.eth      |
| DAO Multisig        | `0x9CDf589C941ee81D75F34d3755671d614f7cf261` | dao.taiko.eth        |
| DAO Controller      | `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` | controller.taiko.eth |
| Foundation Treasury | `0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da` | treasury.taiko.eth   |

## Impact Analysis

### Governance Impact

- **No Change to Voting Power**: Both the Controller and Treasury addresses are non-voting accounts, so this transfer does not affect token voting dynamics
- **DAO Governance Remains Unchanged**: The DAO multisig (dao.taiko.eth) continues to control the Controller contract and can approve future proposals

### Token Holder Impact

- **No Impact on Token Holders**: This is an internal reorganization that does not affect external token holders
- **No Supply Change**: Total token supply remains unchanged

## Verification Procedures

To verify the proposal before execution:

1. Check the current TAIKO token balance of the Controller address:

   ```
   cast call 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 "balanceOf(address)" 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a --rpc-url <ETHEREUM_RPC>
   ```

2. Verify the proposal action data:

   ```
   P=0005 pnpm proposal
   ```

3. Dryrun the proposal on L1:
   ```
   P=0005 pnpm proposal:dryrun:l1
   ```

## Security Contacts

- Primary: security@taiko.xyz
- Bug Bounty Program: [Taiko Immunefi Program](https://immunefi.com/bounty/taiko/)
