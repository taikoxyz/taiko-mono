//! Example demonstrating how to send state-changing transactions with a signer

use alloy_network::EthereumWallet;
use alloy_primitives::{Address, FixedBytes, U256};
use alloy_provider::ProviderBuilder;
use alloy_signer_local::PrivateKeySigner;
use protocol::contracts::InboxOptimized3;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("InboxOptimized3 Transaction Sending Example\n");

    // 1. Setup signer (wallet)
    println!("1. Setting up signer/wallet...");

    // Example private key (DO NOT use in production!)
    // This is a well-known test key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    let private_key_hex = "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
    let private_key_bytes = hex::decode(private_key_hex)?;

    // Create signer from private key
    let signer = PrivateKeySigner::from_bytes(&FixedBytes::<32>::from_slice(&private_key_bytes))?;
    let wallet_address = signer.address();

    println!("   ✓ Wallet address: {:#x}", wallet_address);

    // 2. Create provider with signer
    println!("\n2. Creating provider with signer...");

    let rpc_url = "http://localhost:8545"; // Replace with your actual RPC URL

    // Create wallet from signer
    let wallet = EthereumWallet::from(signer);

    // Build provider with wallet (includes recommended fillers by default)
    let provider = ProviderBuilder::new().wallet(wallet).connect(rpc_url).await?;

    println!("   ✓ Provider connected with wallet");

    // 3. Create contract instance
    println!("\n3. Creating contract instance...");

    // Replace with actual InboxOptimized3 contract address
    let contract_address = Address::from([0x42; 20]); // Example address
    let contract = InboxOptimized3::new(contract_address, provider.clone());

    println!("   ✓ Contract instance created at: {:#x}", contract_address);

    // 4. Check current state before transaction
    println!("\n4. Checking current state...");

    // Check current owner
    match contract.owner().call().await {
        Ok(current_owner) => {
            println!("   Current owner: {:#x}", current_owner);
        }
        Err(e) => {
            println!("   Failed to get current owner: {}", e);
        }
    }

    // Check pending owner
    match contract.pendingOwner().call().await {
        Ok(pending) => {
            println!("   Pending owner: {:#x}", pending);
        }
        Err(e) => {
            println!("   Failed to get pending owner: {}", e);
        }
    }

    // 5. Send state-changing transactions
    println!("\n5. Sending transactions:");

    // Example 1: Simple transaction (no parameters)
    println!("\n   Example 1: Accept ownership (if applicable)");
    println!("   ----------------------------------------");

    match contract.acceptOwnership().send().await {
        Ok(pending_tx) => {
            println!("   ✓ Transaction sent!");
            println!("   Transaction hash: {:#x}", pending_tx.tx_hash());

            // Wait for receipt
            println!("   Waiting for confirmation...");
            match pending_tx.get_receipt().await {
                Ok(receipt) => {
                    println!("   ✓ Transaction confirmed!");
                    println!("   Block number: {:?}", receipt.block_number);
                    println!("   Gas used: {:?}", receipt.gas_used);
                    println!("   Status: {:?}", receipt.status());
                }
                Err(e) => {
                    println!("   ✗ Failed to get receipt: {}", e);
                }
            }
        }
        Err(e) => {
            println!("   ✗ Failed to send transaction: {}", e);
            println!("   (This is expected if you're not the pending owner)");
        }
    }

    // Example 2: Transaction with parameters
    println!("\n   Example 2: Transfer ownership");
    println!("   -----------------------------");

    let new_owner = Address::from([0x11; 20]); // Example new owner address

    match contract.transferOwnership(new_owner).send().await {
        Ok(pending_tx) => {
            println!("   ✓ Transfer ownership transaction sent!");
            println!("   Transaction hash: {:#x}", pending_tx.tx_hash());

            // Get receipt
            match pending_tx.get_receipt().await {
                Ok(receipt) => {
                    println!("   ✓ Transaction confirmed!");
                    println!("   Gas used: {:?}", receipt.gas_used);

                    // Check for events in the receipt
                    if !receipt.inner.logs().is_empty() {
                        println!("   Events emitted: {} events", receipt.inner.logs().len());
                    }
                }
                Err(e) => {
                    println!("   ✗ Failed to get receipt: {}", e);
                }
            }
        }
        Err(e) => {
            println!("   ✗ Failed to send transaction: {}", e);
            println!("   (This is expected if you're not the owner)");
        }
    }

    // Example 3: More complex transaction with custom gas settings
    println!("\n   Example 3: Pause contract with custom gas");
    println!("   -----------------------------------------");

    // Build transaction with custom parameters
    let pause_call = contract.pause();

    // You can customize gas settings before sending
    match pause_call
        .gas(300000) // Set gas limit
        .send()
        .await
    {
        Ok(pending_tx) => {
            println!("   ✓ Pause transaction sent!");
            println!("   Transaction hash: {:#x}", pending_tx.tx_hash());

            match pending_tx.get_receipt().await {
                Ok(receipt) => {
                    println!("   ✓ Transaction confirmed!");
                    println!("   Success: {:?}", receipt.status());
                }
                Err(e) => {
                    println!("   ✗ Failed to get receipt: {}", e);
                }
            }
        }
        Err(e) => {
            println!("   ✗ Failed to send transaction: {}", e);
            println!("   (This is expected if you don't have pause permissions)");
        }
    }

    // 6. Batch transactions
    println!("\n6. Sending multiple transactions:");
    println!("   --------------------------------");

    // You can send multiple transactions sequentially
    let accounts_to_check =
        vec![Address::from([0x01; 20]), Address::from([0x02; 20]), Address::from([0x03; 20])];

    for account in accounts_to_check {
        // Query bond balance first
        match contract.bondBalance(account).call().await {
            Ok(balance) => {
                println!("   Account {:#x} balance: {}", account, balance);

                // If there's a balance, you might want to do something
                if balance > U256::ZERO {
                    println!("   → Account has funds, could trigger withdrawal");
                    // Example: contract.withdrawBond(account).send().await?
                }
            }
            Err(e) => {
                println!("   Failed to check {:#x}: {}", account, e);
            }
        }
    }

    // 7. Error handling best practices
    println!("\n7. Transaction error handling:");
    println!("   ----------------------------");

    // Example of comprehensive error handling
    let result = contract.renounceOwnership().send().await;

    match result {
        Ok(pending_tx) => {
            println!("   Transaction sent: {:#x}", pending_tx.tx_hash());

            // Wait for confirmation with timeout
            match tokio::time::timeout(std::time::Duration::from_secs(60), pending_tx.get_receipt())
                .await
            {
                Ok(Ok(receipt)) => {
                    if receipt.status() {
                        println!("   ✓ Transaction successful!");
                    } else {
                        println!("   ✗ Transaction reverted!");
                    }
                }
                Ok(Err(e)) => {
                    println!("   ✗ Failed to get receipt: {}", e);
                }
                Err(_) => {
                    println!("   ✗ Transaction timeout after 60 seconds");
                }
            }
        }
        Err(e) => {
            // Parse different error types
            println!("   ✗ Transaction failed: {}", e);

            // You can match on specific error types if needed
            // For example, checking if it's a revert error, gas estimation error, etc.
        }
    }

    println!("\n✅ Transaction sending examples completed!");
    println!("\nIMPORTANT NOTES:");
    println!("- Never expose private keys in production code");
    println!("- Always use environment variables or secure key management");
    println!("- Test transactions on testnets first");
    println!("- Monitor gas prices and set appropriate limits");
    println!("- Handle errors and reverts gracefully");

    Ok(())
}
