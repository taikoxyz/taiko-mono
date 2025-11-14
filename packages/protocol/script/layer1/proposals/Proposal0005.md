# PROPOSAL-0005: Transfer TAIKO Tokens from Controller to Treasury

## Executive Summary

This proposal transfers all TAIKO tokens held by the DAO Controller (controller.taiko.eth) -- approximately 94 million TAIKO tokens -- to the Taiko Foundation Treasury (treasury.taiko.eth). This transfer aligns with the Foundation's governance framework for treasury asset management. The transfer is a non-voting organizational measure that does not affect token voting dynamics or token supply, as both the Controller and Treasury addresses are non-voting accounts.

## Rationale

### Background

The Taiko protocol's token holdings are distributed across multiple addresses, including the DAO Controller contract and the Foundation Treasury. The DAO Controller (controller.taiko.eth) currently holds approximately 94 million TAIKO tokens. To optimize treasury management and ensure efficient allocation of resources, it is beneficial to consolidate these holdings into the Foundation Treasury address.

### Benefits

1. **Centralized Treasury Management**: Consolidating tokens into the treasury.taiko.eth address simplifies fund management and tracking
2. **Operational Efficiency**: The Foundation Treasury is better equipped to handle day-to-day operational needs and strategic allocations
3. **Transparency**: Having tokens in the dedicated treasury address provides clearer visibility into protocol reserves
4. **Flexibility**: Enables the Foundation to more efficiently deploy capital for ecosystem development, grants, and partnerships

## Technical Specification

### Token Transfer

**TAIKO Token Contract**: `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` (token.taiko.eth)

**Action**:

- Transfer the entire TAIKO token balance from the Controller contract to the Treasury address
- Source: `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` (controller.taiko.eth)
- Destination: `0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da` (treasury.taiko.eth)
- Amount: ~94,020,735.74 TAIKO (exact amount determined at execution time)

### Implementation Details

The proposal uses a helper contract (TaikoTokenTransferHelper) to ensure the transfer amount is determined at execution time rather than proposal creation time. This prevents issues if the Controller's balance changes between proposal approval and execution.

The proposal executes two actions:

1. **ERC20 Approval**: Approves TaikoTokenTransferHelper to spend the Controller's TAIKO tokens (unlimited approval using type(uint256).max)
2. **Helper Transfer**: Calls TaikoTokenTransferHelper.transferAllFrom() which:
   - Reads the Controller's current TAIKO balance using balanceOf()
   - Transfers the entire balance to treasury.taiko.eth
   - All within the same transaction as proposal execution

This architecture ensures all tokens are transferred regardless of any balance changes between proposal creation and execution, addressing the risk of partial transfers or failures due to insufficient balance.

**Current Balance (as of proposal creation)**: ~94,020,735.74 TAIKO

**Helper Contract**: TaikoTokenTransferHelper must be deployed to Ethereum mainnet before this proposal can be executed.

## Security Considerations

### Safety Measures

1. **No Code Changes**: This proposal only transfers existing tokens using standard ERC20 functionality
2. **Trusted Addresses**: Both the Controller and Treasury addresses are well-established, verified protocol addresses
3. **Non-Voting Accounts**: Both the Controller and Treasury addresses are configured as non-voting accounts in the TaikoToken contract, maintaining governance integrity
4. **Reversibility**: If needed, tokens can be transferred back through a subsequent governance proposal
5. **Execution Model**: The proposal is executed by the Controller contract itself, which has full authority over its own token holdings

### Address Verification

| Entity           | Address                                      | ENS Name             |
| ---------------- | -------------------------------------------- | -------------------- |
| TAIKO Token      | `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` | token.taiko.eth      |
| DAO Multisig     | `0x9CDf589C941ee81D75F34d3755671d614f7cf261` | dao.taiko.eth        |
| DAO Controller   | `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` | controller.taiko.eth |
| Treasury Address | `0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da` | treasury.taiko.eth   |

All addresses can be verified in:

- [TaikoToken.sol](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/contracts/layer1/mainnet/TaikoToken.sol)
- [LibL1Addrs.sol](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/contracts/layer1/mainnet/LibL1Addrs.sol)

## Impact Analysis

### Governance Impact

- **No Change to Voting Power**: Both the Controller and Treasury addresses are non-voting accounts, so this transfer does not affect token voting dynamics
- **DAO Governance Remains Unchanged**: The DAO multisig (dao.taiko.eth) continues to control the Controller contract and can approve future proposals

### Token Holder Impact

- **No Impact on Token Holders**: This is an internal reorganization that does not affect external token holders
- **No Supply Change**: Total token supply remains unchanged

### Operational Impact

- **Improved Treasury Operations**: The Foundation Treasury will hold approximately 358 million TAIKO tokens after this transfer (current ~264M + transferred ~94M)
- **Enhanced Planning**: Better visibility into available resources for ecosystem development
- **Simplified Token Management**: Consolidating operational funds into the Treasury streamlines financial operations

## Deployment and Execution

### Step 1: Deploy TaikoTokenTransferHelper

Before executing this proposal, deploy the helper contract:

```bash
forge create src/shared/governance/TaikoTokenTransferHelper.sol:TaikoTokenTransferHelper --rpc-url <ETHEREUM_RPC> --broadcast --verify
```

Update the `TRANSFER_HELPER` address in `Proposal0005.s.sol` with the deployed contract address.

### Step 2: Verify and Execute Proposal

## Verification Procedures

### Pre-Execution Verification

To verify the proposal before execution:

1. Check the current TAIKO token balance of the Controller address:

   ```bash
   cast call 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 "balanceOf(address)" 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a --rpc-url <ETHEREUM_RPC>
   ```

2. Verify the TaikoTokenTransferHelper is deployed and TRANSFER_HELPER address is updated in Proposal0005.s.sol

3. Verify the proposal action data:

   ```bash
   P=0005 pnpm proposal
   ```

4. Dryrun the proposal on L1:
   ```bash
   P=0005 pnpm proposal:dryrun:l1
   ```

### Post-Execution Verification

After execution, verify the transfer succeeded:

1. Confirm Controller balance is zero (or minimal dust amount):

   ```
   cast call 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 "balanceOf(address)" 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a --rpc-url <ETHEREUM_RPC>
   ```

2. Verify Treasury received the tokens:

   ```
   cast call 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800 "balanceOf(address)" 0x363e846B91AF677Fb82f709b6c35BD1AaFc6B3Da --rpc-url <ETHEREUM_RPC>
   ```

3. Check the transfer event on Etherscan:
   - Navigate to the TAIKO token contract
   - Find the Transfer event from Controller to Treasury
   - Verify the amount matches ~94,020,735.74 TAIKO

## Security Contacts

- Primary: security@taiko.xyz
- Bug Bounty Program: [Taiko Immunefi Program](https://immunefi.com/bounty/taiko/)

## References

- [TaikoToken Contract Source](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/contracts/layer1/mainnet/TaikoToken.sol)
- [LibL1Addrs Source](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/contracts/layer1/mainnet/LibL1Addrs.sol)
- [Taiko Network Reference](https://docs.taiko.xyz/network-reference/contract-addresses)
- [Etherscan - TAIKO Token](https://etherscan.io/token/0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800)

## Appendix

### A. Transaction Flow

```
1. DAO multisig approves proposal via Gnosis Safe
2. DAO Controller executes proposal
3. Controller calls TAIKO token contract's transfer function
4. Token contract transfers ~94M TAIKO from Controller to Treasury
5. Transfer event emitted
6. Treasury balance increases from ~264M to ~358M TAIKO
```

### B. Glossary

- **DAO Multisig**: Gnosis Safe contract at dao.taiko.eth that approves governance proposals
- **DAO Controller**: The smart contract at controller.taiko.eth that executes approved governance proposals
- **Treasury**: The Foundation's operational wallet for ecosystem development and protocol sustainability
- **Non-Voting Account**: An address whose token balance does not count toward governance voting power

## Q&A

### Q1: Why transfer tokens from the Controller to the Treasury?

**A:** This consolidation improves operational efficiency and provides the Foundation with better tools for managing protocol resources. The Controller contract is designed for governance execution, not token management. Moving these tokens to the Treasury (which already holds ~264M TAIKO) centralizes operational funds for better planning and allocation. The DAO multisig still controls the Controller for governance decisions.

### Q2: Can the tokens be transferred back to the Controller if needed?

**A:** Yes, tokens can be transferred back through another governance proposal if the community decides that's necessary. This is a reversible operation. However, the Controller is not designed for long-term token storage.

### Q3: Does this affect voting power or governance?

**A:** No, both the Controller address and Treasury address are configured as non-voting accounts in the TaikoToken contract, so this transfer has no impact on governance voting power or the total circulating supply for voting purposes.

### Q4: What will the Treasury do with these tokens?

**A:** The Treasury manages tokens for ecosystem development, partnerships, grants programs, liquidity provisions, and other strategic initiatives that support the Taiko protocol and community. Specific allocations are determined through ongoing operational planning.

### Q5: Is there any risk in this transfer?

**A:** The risk is minimal. Both addresses are well-established protocol addresses, and the transfer uses standard ERC20 functionality. The operation is straightforward and can be verified on-chain before and after execution. The proposal has been successfully tested via dryrun on mainnet fork.

### Q6: How does the DAO control work?

**A:** The governance flow is: DAO Multisig (dao.taiko.eth) → owns → Controller (controller.taiko.eth) → executes proposals. When this proposal is approved, the Controller executes the token transfer from its own balance to the Treasury.
