//! Example demonstrating how to actually send contract calls

use alloy_primitives::{Address, Bytes};
use alloy_provider::ProviderBuilder;
use protocol::contracts::InboxOptimized3;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("InboxOptimized3 Contract Interaction Example\n");

    // 1. Setup provider (example URLs - replace with actual endpoints)
    println!("1. Setting up provider...");

    // For HTTP provider:
    let rpc_url = "http://localhost:8545"; // Replace with your actual RPC URL

    // Create HTTP Provider
    let provider = ProviderBuilder::new().connect(rpc_url).await?;

    // Option B: WebSocket Provider (uncomment to use)
    // let ws_url = "ws://localhost:8546";
    // let provider = ProviderBuilder::new()
    //     .on_ws(WsConnect::new(ws_url))
    //     .await?
    //     .boxed();

    println!("   ✓ Provider connected to: {}", rpc_url);

    // 2. Create contract instance
    println!("\n2. Creating contract instance...");

    // Replace with actual InboxOptimized3 contract address
    let contract_address = Address::from([0x42; 20]); // Example address

    // Create the contract instance
    let contract = InboxOptimized3::new(contract_address, provider.clone());

    println!("   ✓ Contract instance created at: {:#x}", contract_address);

    // 3. Making read-only calls (these don't require gas)
    println!("\n3. Making read-only contract calls:");

    // Example 1: Query owner
    println!("\n   a) Querying contract owner...");
    match contract.owner().call().await {
        Ok(owner) => {
            println!("      ✓ Contract owner: {:#x}", owner);
        }
        Err(e) => {
            println!("      ✗ Failed to get owner: {}", e);
        }
    }

    // Example 2: Check if paused
    println!("\n   b) Checking pause status...");
    match contract.paused().call().await {
        Ok(is_paused) => {
            println!("      ✓ Contract paused: {}", is_paused);
        }
        Err(e) => {
            println!("      ✗ Failed to check pause status: {}", e);
        }
    }

    // Example 3: Query bond balance for an account
    println!("\n   c) Querying bond balance...");
    let account_to_check = Address::ZERO; // Example account

    // Method 1: Using the contract instance directly
    match contract.bondBalance(account_to_check).call().await {
        Ok(balance) => {
            println!("      ✓ Bond balance for {:#x}: {}", account_to_check, balance);
        }
        Err(e) => {
            println!("      ✗ Failed to get bond balance: {}", e);
        }
    }

    // Method 2: Using the Call struct (more control)
    let bond_balance_call = InboxOptimized3::bondBalanceCall { account: account_to_check };

    // You can also use the call struct directly with the contract
    match contract.call_builder(&bond_balance_call).call().await {
        Ok(result) => {
            // The result type depends on the function's return type
            println!("      ✓ Bond balance (method 2): {:?}", result);
        }
        Err(e) => {
            println!("      ✗ Failed to get bond balance (method 2): {}", e);
        }
    }

    // 4. Complex function calls
    println!("\n4. Complex function calls:");

    // Example: Decode some data
    let sample_data = Bytes::from(vec![0u8; 100]);

    println!("\n   Decoding propose input data...");
    match contract.decodeProposeInput(sample_data.clone()).call().await {
        Ok(decoded) => {
            println!("      ✓ Successfully decoded data");
            println!("      - Deadline: {}", decoded.deadline);
            println!("      - Next Proposal ID: {}", decoded.coreState.nextProposalId);
        }
        Err(e) => {
            println!("      ✗ Failed to decode: {}", e);
            println!("      (This is expected with dummy data)");
        }
    }

    // 5. State-changing transactions (require signer)
    println!("\n5. State-changing transactions:");
    println!("   Note: These require a signer/wallet to be configured");

    // To send transactions, you would need:
    // 1. A signer (wallet) with the provider
    // 2. Gas estimation
    // 3. Transaction sending

    println!("\n   Example code for sending transactions:");
    println!("   ```");
    println!("   // Setup provider with signer");
    println!("   let signer = LocalWallet::from_bytes(&private_key)?;");
    println!("   let provider = ProviderBuilder::new()");
    println!("       .with_recommended_fillers()");
    println!("       .wallet(EthereumWallet::from(signer))");
    println!("       .on_http(rpc_url.parse()?)");
    println!("       .boxed();");
    println!("");
    println!("   // Send transaction (e.g., accept ownership)");
    println!("   let tx = contract.acceptOwnership()");
    println!("       .send()");
    println!("       .await?");
    println!("       .get_receipt()");
    println!("       .await?;");
    println!("   ```");

    // 6. Working with events
    println!("\n6. Listening to events:");
    println!("   You can filter and watch for contract events:");

    println!("   ```");
    println!("   // Filter for Proposed events");
    println!("   let filter = contract.Proposed_filter()");
    println!("       .from_block(0)");
    println!("       .to_block(BlockNumberOrTag::Latest);");
    println!("");
    println!("   // Get historical events");
    println!("   let events = filter.query().await?;");
    println!("");
    println!("   // Or watch for new events");
    println!("   let stream = filter.watch().await?;");
    println!("   ```");

    println!("\n✅ Contract interaction examples completed!");

    Ok(())
}
