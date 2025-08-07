# Bond Design Document

Now that bond management has been largely moved to L2, and we introduced a new `provabilityBond` to combat prover killer blocks it is not as straight forward to understand how bonds are handled in the protocol.

This document summarizes who pays each bond and on which layer(L1 or L2) and where they receive their payment.

## Bond Types

### 1. Provability Bond
- **Amount**: Configured at contract deployment (stored as `uint48` in gwei)
- **Purpose**: Ensures blocks can be proven within the extended window
- **Paid by**: Proposer on L1
- **Layer**: L1 only

### 2. Liveness Bond  
- **Amount**: Configured at contract deployment (stored as `uint48` in gwei)
- **Purpose**: Incentivizes timely proof submission
- **Paid by**: 
  - If proposer = designated prover: Implicitly held by proposer on L1
  - If proposer ≠ designated prover: Paid by designated prover on L2
- **Layer**: L1 (when proposer is designated prover) or L2 (when different prover)

### L1 Bond Operations (via BondManager)

1. **Proposer Bond Requirements**:
   - Proposers must maintain minimum bond balance on L1 (`minBondBalance`)
   - Provability bond is implicitly locked when proposing (not explicitly debited)
   - Bond balance checked in `Inbox.propose()`: requires `bondManager.getBondBalance(msg.sender) >= minBondBalance`
   - Note: Proposers may also need L2 bond balance to pay prover fees (see L2 operations)

2. **Bond Slashing (L1)**:
   - Occurs via `bondManager.debitBond()` in `_processBonds()`
   - Late proofs (beyond proving window): Liveness bond slashed from proposer on L1 if proposer was designated prover
   - Very late proofs (beyond extended window): Provability bond slashed from proposer on L1

3. **Bond Rewards (L1)**:
   - Actual prover receives half of slashed bonds (`REWARD_FRACTION = 2`)
   - Credited via `bondManager.creditBond()` directly on L1

### L2 Bond Operations (via BlockCalls)

1. **Designated Prover Selection** (L2):
   - Calculated in `_calculate_designated_prover()` during block processing
   - Validates prover signature and bond balance
   - If different prover selected: liveness bond deducted from prover's L2 balance
   - If prover has insufficient liveness bond on L2, defaults to proposer
   - **Prover fee requirements**:
     - Proposer must have sufficient L2 bond balance to pay the prover fee
     - If proposer lacks L2 balance for fee, defaults to proposer as designated prover
     - Fee transferred from proposer's L2 balance to designated prover's L2 balance

2. **Bond Credit Operations** (L2):
   - Managed through `bond_credit_ops` in `block_head_call()`
   - Credits accumulated and hashed into `anchor_bond_credits_hash`
   - Operations include refunds and rewards based on proof timing


## Pseudo Code: Bond Management by Proving Window

```pseudo
// Initial Setup (when proposal is created)
function proposeBlock(proposer, prover_signature, prover_fee):
    // L1: Check proposer has minimum balance
    require(L1.bondBalance[proposer] >= minBondBalance)
    
    // L2: Determine designated prover
    if (prover_signature is valid AND prover != proposer):
        // Check if external prover can afford liveness bond on L2
        if (L2.bondBalance[prover] >= livenessBond):
            // Check if proposer can afford prover fee on L2
            if (L2.bondBalance[proposer] >= prover_fee):
                // External prover case
                L2.bondBalance[prover] -= livenessBond
                L2.bondBalance[proposer] -= prover_fee
                L2.bondBalance[prover] += prover_fee
                designated_prover = prover
            else:
                designated_prover = proposer  // Fallback: proposer lacks L2 funds
        else:
            designated_prover = proposer  // Fallback: prover lacks L2 funds
    else:
        designated_prover = proposer  // Default case
    
    // Note: Provability bond implicitly held on L1 (not debited yet)
    // Note: If proposer = designated_prover, liveness bond implicitly held on L1

// When proof is submitted
function proveBlock(actual_prover, proof_timestamp):
    proving_window_end = proposal.timestamp + PROVING_WINDOW
    extended_window_end = proposal.timestamp + EXTENDED_PROVING_WINDOW
    
    if (proof_timestamp <= proving_window_end):
        // ON-TIME PROOF
        if (designated_prover != proposer):
            // Refund liveness bond to designated prover on L2
            L2.bondBalance[designated_prover] += livenessBond
        // else: No-op (proposer keeps their L1 bonds)
        
    else if (proof_timestamp <= extended_window_end):
        // LATE PROOF (within extended window)
        if (designated_prover == proposer):
            // Proposer failed as designated prover
            // Slash liveness bond on L1
            L1.bondBalance[proposer] -= livenessBond
            L1.bondBalance[actual_prover] += livenessBond / 2
        else:
            // External designated prover succeeded late
            // Reward actual prover on L2 (half of liveness bond)
            L2.bondBalance[actual_prover] += livenessBond / 2
            // Note: designated prover's L2 liveness bond already deducted
        
    else:
        // VERY LATE PROOF (beyond extended window)
        // Slash provability bond on L1
        L1.bondBalance[proposer] -= provabilityBond
        L1.bondBalance[actual_prover] += provabilityBond / 2
        
        if (designated_prover != proposer):
            // Also refund liveness bond to designated prover on L2
            L2.bondBalance[designated_prover] += livenessBond
        // else: proposer loses both bonds on L1

// Bond Summary by Scenario:
// 
// Scenario 1: Proposer = Designated Prover, On-time proof
//   - L1: No changes (bonds implicitly held)
//   - L2: No operations
//
// Scenario 2: Proposer ≠ Designated Prover, On-time proof  
//   - L1: No changes
//   - L2: Liveness bond refunded to designated prover
//
// Scenario 3: Proposer = Designated Prover, Late proof
//   - L1: Liveness bond slashed from proposer, half to actual prover
//   - L2: No operations
//
// Scenario 4: Proposer ≠ Designated Prover, Late proof
//   - L1: No changes  
//   - L2: Half of liveness bond to actual prover (other half burned)
//
// Scenario 5: Any setup, Very late proof
//   - L1: Provability bond slashed from proposer, half to actual prover
//   - L2: If different designated prover, liveness bond refunded
```

## Withdraw Delays

The `BondManager` contract is deployed on both L1 and L2, but funds can be withdrawn immediately from L2, but not from L1. Instead proposers(provers don't post a bond to L1) have to signal they want to exit and wait a period of time.

TODO: Add reasoning and how much proposers have to wait to withdraw their bonds on L1.