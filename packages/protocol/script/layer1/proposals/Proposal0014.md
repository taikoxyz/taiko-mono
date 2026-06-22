# PROPOSAL-0014: Upgrade Shasta Inbox Implementation

## Executive Summary

This proposal upgrades the L1 Shasta `Inbox` proxy to a new implementation through the DAO Controller.

It executes **1 L1 action** and **no L2 actions**:

1. Upgrade `L1.INBOX` to `INBOX_NEW_IMPL`.

The new implementation address is `0x349Ae3578f48F758d79451EeAB61Cdd5fedD0098`.

## Rationale

Following the security incident (https://x.com/taikoxyz/status/2068858818352865626?s=20), this
upgrade temporarily disables:

- Permissionless proposing
- Permissionless proving
- Forced inclusions

This narrows the protocol surface while proof soundness is reviewed.

## Technical Specification

### Address Constants

| Constant         | Value                                        | Notes                              |
| ---------------- | -------------------------------------------- | ---------------------------------- |
| `L1.INBOX`       | `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | L1 Shasta Inbox proxy              |
| `INBOX_NEW_IMPL` | `0x349Ae3578f48F758d79451EeAB61Cdd5fedD0098` | New L1 Shasta Inbox implementation |

### L1 Actions (1 total)

1. Call `upgradeTo(INBOX_NEW_IMPL)` on `L1.INBOX`.

There are no L2 actions in this proposal.

## Verification

Before submission:

1. Confirm bytecode exists at the implementation address:

   ```bash
   cast code 0x349Ae3578f48F758d79451EeAB61Cdd5fedD0098 --rpc-url <RPC_URL>
   ```

2. Confirm the Inbox proxy is owned by the DAO Controller:

   ```bash
   cast call 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f \
     "owner()(address)" \
     --rpc-url <RPC_URL>
   ```

   Expected: `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a`.

3. Generate proposal calldata:

   ```bash
   P=0014 pnpm proposal
   ```

4. Dryrun on L1:

   ```bash
   P=0014 pnpm proposal:dryrun:l1
   ```

After execution:

1. Confirm the proxy implementation:

   ```bash
   cast call 0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f \
     "impl()(address)" \
     --rpc-url <RPC_URL>
   ```

2. Confirm the returned address matches `INBOX_NEW_IMPL`.

## Security Contacts

- security@taiko.xyz
