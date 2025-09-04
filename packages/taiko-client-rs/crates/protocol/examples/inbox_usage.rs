//! Example demonstrating InboxOptimized3 contract usage

use alloy_primitives::{Address, Bytes, uint};
use protocol::contracts::InboxOptimized3;

fn main() {
    println!("InboxOptimized3 contract bindings demonstration:\n");

    // 1. Simple function calls - these can be used to query the contract
    println!("1. Simple Query Functions:");

    // Example: Create a bondBalance call
    let example_address = Address::ZERO;
    let _bond_balance_call = InboxOptimized3::bondBalanceCall { account: example_address };
    println!("   ✓ Created bondBalanceCall for account: {:#x}", example_address);

    // Example: Query owner
    let _owner_call = InboxOptimized3::ownerCall {};
    println!("   ✓ Created ownerCall to query contract owner");

    // Example: Check if paused
    let _paused_call = InboxOptimized3::pausedCall {};
    println!("   ✓ Created pausedCall to check pause status");

    // 2. Decode functions - used to parse encoded data
    println!("\n2. Decode Functions (parse encoded data):");

    // Example: Decode propose input
    let sample_data = Bytes::from(vec![0u8; 100]);
    let _decode_propose = InboxOptimized3::decodeProposeInputCall { _data: sample_data.clone() };
    println!("   ✓ Created decodeProposeInput with {} bytes", sample_data.len());

    // Example: Decode proposed event data
    let _decode_event = InboxOptimized3::decodeProposedEventDataCall { _data: sample_data.clone() };
    println!("   ✓ Created decodeProposedEventData");

    // Example: Decode prove input
    let _decode_prove = InboxOptimized3::decodeProveInputCall { _data: sample_data.clone() };
    println!("   ✓ Created decodeProveInput");

    // Example: Decode proved event data
    let _decode_proved_event =
        InboxOptimized3::decodeProvedEventDataCall { _data: sample_data.clone() };
    println!("   ✓ Created decodeProvedEventData");

    // 3. Complex types demonstration
    println!("\n3. Working with Complex Types:");

    // The contract uses many complex nested structures.
    // Here's how to work with some of them:

    // Example: Create a simple CoreState using the generated types
    use protocol::contracts::IInbox::CoreState;
    let core_state = CoreState {
        nextProposalId: uint!(1_U48),
        lastFinalizedProposalId: uint!(0_U48),
        lastFinalizedTransitionHash: [0u8; 32].into(),
        bondInstructionsHash: [0u8; 32].into(),
    };
    println!("   ✓ Created CoreState with next proposal ID: {}", core_state.nextProposalId);

    // Example: Create a Proposal
    use protocol::contracts::IInbox::Proposal;
    let proposal = Proposal {
        id: uint!(1_U48),
        timestamp: uint!(1000000_U48),
        lookaheadSlotTimestamp: uint!(1000100_U48),
        proposer: example_address,
        coreStateHash: [0u8; 32].into(),
        derivationHash: [0u8; 32].into(),
    };
    println!("   ✓ Created Proposal with ID: {}", proposal.id);

    // 4. Events - these would be emitted by the contract
    println!("\n4. Contract Events:");
    println!("   The contract can emit various events:");
    println!("   - AdminChanged: Admin role changes");
    println!("   - BeaconUpgraded: Beacon upgrades");
    println!("   - BondInstructed: Bond instructions");
    println!("   - BondWithdrawn: Bond withdrawals");
    println!("   - ForcedInclusionStored: Forced inclusions");
    println!("   - Initialized: Contract initialization");
    println!("   - OwnershipTransferStarted/Transferred: Ownership changes");
    println!("   - Paused/Unpaused: Pause state changes");
    println!("   - Proposed: New proposals");
    println!("   - Proved: Proof submissions");
    println!("   - Upgraded: Contract upgrades");

    // 5. Administrative functions
    println!("\n5. Administrative Functions:");

    // Example: Accept ownership
    let _accept_ownership = InboxOptimized3::acceptOwnershipCall {};
    println!("   ✓ Created acceptOwnershipCall");

    // Example: Renounce ownership
    let _renounce_ownership = InboxOptimized3::renounceOwnershipCall {};
    println!("   ✓ Created renounceOwnershipCall");

    // Example: Transfer ownership
    let new_owner = Address::ZERO;
    let _transfer_ownership = InboxOptimized3::transferOwnershipCall { newOwner: new_owner };
    println!("   ✓ Created transferOwnershipCall");

    // 6. Getter functions
    println!("\n6. State Query Functions:");

    // Example: Get pending owner
    let _pending_owner = InboxOptimized3::pendingOwnerCall {};
    println!("   ✓ Created pendingOwnerCall");

    // Example: Get proxiable UUID
    let _proxiable = InboxOptimized3::proxiableUUIDCall {};
    println!("   ✓ Created proxiableUUIDCall");

    // Example: Get implementation address
    let _impl_call = InboxOptimized3::implCall {};
    println!("   ✓ Created implCall to get implementation address");

    // 7. Usage with a provider
    println!("\n7. Real Contract Interaction Example:");
    println!("   With an actual provider, you would use these bindings like:");
    println!("   ```");
    println!("   let provider = Provider::new(...);");
    println!("   let contract = InboxOptimized3::new(contract_address, provider);");
    println!("   ");
    println!("   // Query bond balance");
    println!("   let balance = contract.bondBalance(account).call().await?;");
    println!("   ");
    println!("   // Check if paused");
    println!("   let is_paused = contract.paused().call().await?;");
    println!("   ");
    println!("   // Decode some data");
    println!("   let decoded = contract.decodeProposeInput(data).call().await?;");
    println!("   ```");

    println!("\n✅ All contract bindings successfully demonstrated!");
    println!("The InboxOptimized3 contract bindings are ready for use with alloy providers.");
}
