# PROPOSAL-0008: Reduce DAO Voting Period from 21 to 10 Days

## Executive Summary

This proposal reduces the DAO voting period (`destinationProposalDuration`) from 21 days (1,814,400 seconds) to 10 days (864,000 seconds) on the Standard Multisig plugin.

## Rationale

We're proposing to reduce Taiko's veto period from 21 days to 10 days while keeping the 7-day timelock unchanged. This change would cut our total governance cycle from 28 days to 17 days—a 40% reduction—without compromising security.

Why now? Because:

1. Veto-based voting doesn't need long periods (no quorum to reach for passing proposal)
2. Most major DAOs uses shorter windows than we do
3. 21 days is holding us back from shipping improvements and making Taiko more competitive
4. The 7-day timelock already provides exit protection according to stage 1 [requirements](https://forum.l2beat.com/t/the-stages-framework/291#p-516-stage-1-requirements-3)

## Technical Specification

**Single L1 action** — call `updateMultisigSettings` on the Standard Multisig plugin:

- **Target**: `0xD7dA1C25E915438720692bC55eb3a7170cA90321` (DAO Standard Multisig)
- **Function**: `updateMultisigSettings((bool,uint16,uint32,address,uint32))`

### Current vs. New Settings

| Parameter                     | Current Value                                | New Value           |
| ----------------------------- | -------------------------------------------- | ------------------- |
| `onlyListed`                  | `true`                                       | `true`              |
| `minApprovals`                | `5`                                          | `5`                 |
| `destinationProposalDuration` | `1,814,400` (21 days)                        | `864,000` (10 days) |
| `signerList`                  | `0x0F95E6968EC1B28c794CF1aD99609431de5179c2` | unchanged           |
| `proposalExpirationPeriod`    | `1,209,600` (14 days)                        | `1,209,600`         |

## Verification

1. Generate proposal calldata:

   ```
   P=0008 pnpm proposal
   ```

2. Dryrun on L1 fork:

   ```
   P=0008 pnpm proposal:dryrun:l1
   ```

3. Verify current settings on-chain:
   ```
   cast call 0xD7dA1C25E915438720692bC55eb3a7170cA90321 "multisigSettings()" --rpc-url <ETHEREUM_RPC>
   ```

## Forum Discussion

[Forum Discussion](https://community.taiko.xyz/t/proposal-increasing-governance-agility-reducing-the-veto-period-to-10-days/3900)

## Security Contacts

- Primary: security@taiko.xyz
