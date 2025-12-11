# PROPOSAL-0006: Add Gattaca as Security Council Member

## Executive Summary

This proposal adds Gattaca as a new member to the Taiko Security Council. Gattaca is being added to strengthen the security council's operational capacity and decentralization. This change affects the SignerList contract which manages the authorized signers for both the Standard and Emergency multisigs.

### Address Verification

| Entity         | Address                                      | Notes                            |
| -------------- | -------------------------------------------- | -------------------------------- |
| SignerList     | `0x0F95E6968EC1B28c794CF1aD99609431de5179c2` | Manages Security Council signers |
| DAO Controller | `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` | controller.taiko.eth             |
| Gattaca (New)  | `0x6268d189E011Aa53A2f09A1FE159445BeB3d878E` | New security council member      |

## Impact Analysis

### Governance Impact

- **Security Council Expansion**: Gattaca will be added as a new authorized signer
- **Multisig Threshold Unchanged**: The signing threshold remains the same; only the signer list is updated
- **Operational Capacity**: Increases the pool of available signers for security council operations

### Security Impact

- **No Immediate Risk**: Adding a signer does not grant unilateral control; multisig threshold requirements still apply
- **Enhanced Resilience**: Additional signers improve availability and reduce single points of failure

## Technical Specification

### Action: Add Signer to SignerList

**Contract**: SignerList (`0x0F95E6968EC1B28c794CF1aD99609431de5179c2`)

**Function**: `addSigners(address[] calldata _signers)`

**Parameters**:

- `_signers`: `[0x6268d189E011Aa53A2f09A1FE159445BeB3d878E]` (Gattaca)

This function adds the specified address to the list of authorized Security Council signers. The SignerList is referenced by both the Standard and Emergency multisig plugins to determine valid signers.

## Verification Procedures

To verify the proposal before execution:

1. Verify Gattaca's address is correct:

   ```
   # Confirm the address matches Gattaca's expected address
   echo "0x6268d189E011Aa53A2f09A1FE159445BeB3d878E"
   ```

2. Verify the proposal action data:

   ```
   P=0006 pnpm proposal
   ```

3. Dryrun the proposal on L1:

   ```
   P=0006 pnpm proposal:dryrun:l1
   ```

4. After execution, verify Gattaca was added:
   ```
   cast call 0x0F95E6968EC1B28c794CF1aD99609431de5179c2 "isListed(address)" 0x6268d189E011Aa53A2f09A1FE159445BeB3d878E --rpc-url <ETHEREUM_RPC>
   ```

## Security Contacts

- Primary: security@taiko.xyz
- Bug Bounty Program: [Taiko Immunefi Program](https://immunefi.com/bounty/taiko/)

## References

- [Taiko DAO Contracts Repository](https://github.com/taikoxyz/dao-contracts)
- [SignerList Contract](https://github.com/taikoxyz/dao-contracts/blob/main/src/SignerList.sol)
