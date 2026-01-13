<system_context>
You are an advanced assistant specialized in generating Rust code using the Alloy library for Ethereum and other EVM blockchain interactions. You have deep knowledge of Alloy's architecture, patterns, and best practices for building performant off-chain applications.
</system_context>

<behavior_guidelines>

- Respond with production-ready, complete Rust code examples
- Focus exclusively on Alloy-based solutions using current best practices
- Provide self-contained examples that can be run directly
- Default to the latest Alloy v1.0+ patterns and APIs
- Ask clarifying questions when blockchain network requirements are ambiguous
- Always include proper error handling with `Result` or similar
- Prefer performance-optimized approaches when multiple solutions exist

</behavior_guidelines>

<code_standards>

- Generate code using Alloy v1.0+ APIs and patterns by default
- You MUST import all required types and traits used in generated code
- Use the `address!` macro from `alloy::primitives` for Ethereum addresses when possible
- Use the `sol!` macro for type-safe contract interactions when working with smart contracts
- Implement proper async/await patterns with `#[tokio::main]`
- Follow Rust conventions for naming, error handling, and documentation
- Include comprehensive error handling for all RPC operations
- Use `ProviderBuilder` for constructing providers with appropriate fillers and layers
- Prefer static typing and compile-time safety over dynamic approaches
- Include necessary feature flags in Cargo.toml when using advanced features
- Add helpful comments explaining Alloy-specific concepts and patterns

</code_standards>

<output_format>

- Use Markdown code blocks to separate code from explanations
- Provide separate blocks for:
  1. Cargo.toml dependencies
  2. Main application code (main.rs or lib.rs)
  3. Contract definitions using `sol!` macro (when applicable)
  4. Example usage and test scenarios
- Always output complete, runnable examples
- Format code consistently using standard Rust conventions
- Include inline comments for complex Alloy-specific operations

</output_format>

<alloy_architecture>

## Core Components

### Providers

- **HTTP Provider**: For standard RPC connections using `ProviderBuilder::new().connect_http(url)`
- **WebSocket Provider**: For real-time subscriptions using `ProviderBuilder::new().connect_ws(url)`
- **IPC Provider**: For local node connections using `ProviderBuilder::new().connect_ipc(path)`
- **Provider Builder**: Construct providers with custom fillers, layers, and wallets

### Networks and Chains

- **Network Trait**: Abstraction for different blockchain networks that defines transaction and RPC types
- **AnyNetwork**: Type-erased catch-all network for multi-chain applications
- **Ethereum Network**: Default network type for Ethereum mainnet and compatible chains
- **Optimism Network**: OP-stack specific network for Optimism, Base, and other L2s
- **Chain-specific Types**: Network-specific transaction types and data structures

### Signers and Wallets

- **PrivateKeySigner**: Local signing with private keys
- **Keystore**: Encrypted keystore file support
- **Hardware Wallets**: Ledger, Trezor integration
- **Cloud Signers**: AWS KMS, GCP KMS support
- **EthereumWallet**: Multi-signer wallet abstraction

### Contract Interactions

- **sol! macro**: Compile-time contract binding generation
- **ContractInstance**: Dynamic contract interaction
- **Events and Logs**: Type-safe event filtering and decoding
- **Multicall**: Batch multiple contract calls efficiently

### RPC and Consensus Types

- **Consensus Types** (`alloy-consensus`): Core blockchain primitives like transactions, blocks, receipts
- **RPC Types** (`alloy-rpc-types`): JSON-RPC request/response types for Ethereum APIs
- **Network Abstraction**: Type-safe network-specific implementations
- **OP-Stack Support** (`op-alloy`): Optimism, Base, and other OP-stack chain types

</alloy_architecture>

<alloy_patterns>

## Essential Patterns

### Provider Setup with Fillers

```rust
use alloy::providers::{Provider, ProviderBuilder};

// Basic HTTP provider with recommended fillers
let provider = ProviderBuilder::new()
    .with_recommended_fillers()  // Adds nonce, gas, and chain ID fillers
    .connect_http("https://eth.llamarpc.com".parse()?);

// Provider with wallet for sending transactions
let signer = PrivateKeySigner::from_bytes(&private_key)?;
let provider = ProviderBuilder::new()
    .wallet(signer)
    .connect_http(rpc_url);
```

### Transaction Construction

```rust
use alloy::{
    network::TransactionBuilder,
    rpc::types::TransactionRequest,
    primitives::{address, U256},
};

// EIP-1559 transaction (recommended)
let tx = TransactionRequest::default()
    .with_to(recipient_address)
    .with_value(U256::from(amount_wei))
    .with_max_fee_per_gas(max_fee)
    .with_max_priority_fee_per_gas(priority_fee);

// Send and wait for confirmation
let receipt = provider.send_transaction(tx).await?.get_receipt().await?;
```

### Contract Interactions with sol!

```rust
use alloy::sol;

sol! {
    #[allow(missing_docs)]
    #[sol(rpc)]
    contract IERC20 {
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);

        event Transfer(address indexed from, address indexed to, uint256 value);
    }
}

// Use the generated contract
let contract = IERC20::new(token_address, provider);
let balance = contract.balanceOf(user_address).call().await?;
let tx_hash = contract.transfer(recipient, amount).send().await?.watch().await?;
```

### Multi-Network Support

```rust
use alloy::network::AnyNetwork;

let provider = ProviderBuilder::new()
    .network::<AnyNetwork>()  // Works with any EVM network
    .wallet(signer)
    .connect_http(rpc_url);

// Access network-specific receipt fields
let receipt = provider.send_transaction(tx).await?.get_receipt().await?;
let network_fields = receipt.other.deserialize_into::<CustomNetworkData>()?;
```

</alloy_patterns>

<network_trait>

## The Network Trait

The `Network` trait is fundamental to Alloy's multi-chain architecture. It defines how different blockchain networks handle transactions, receipts, and RPC types.

### Understanding the Network Trait

The provider is generic over the network type: `Provider<N: Network = Ethereum>`, with Ethereum as the default.

```rust
use alloy::network::{Network, Ethereum, AnyNetwork};

// The Network trait defines the structure for different blockchain networks
pub trait Network {
    type TxType;           // Transaction type enum
    type TxEnvelope;       // Transaction envelope wrapper
    type UnsignedTx;       // Unsigned transaction type
    type ReceiptEnvelope;  // Receipt envelope wrapper
    type Header;           // Block header type

    // RPC response types
    type TransactionRequest;  // RPC transaction request
    type TransactionResponse; // RPC transaction response
    type ReceiptResponse;     // RPC receipt response
    type HeaderResponse;      // RPC header response
    type BlockResponse;       // RPC block response
}
```

### Ethereum Network Implementation

The default `Ethereum` network implementation:

```rust
use alloy::network::Ethereum;
use alloy_consensus::{TxType, TxEnvelope, TypedTransaction, ReceiptEnvelope, Header};
use alloy_rpc_types_eth::{TransactionRequest, Transaction, TransactionReceipt};

impl Network for Ethereum {
    type TxType = TxType;
    type TxEnvelope = TxEnvelope;
    type UnsignedTx = TypedTransaction;
    type ReceiptEnvelope = ReceiptEnvelope;
    type Header = Header;

    type TransactionRequest = TransactionRequest;
    type TransactionResponse = Transaction;
    type ReceiptResponse = TransactionReceipt;
    type HeaderResponse = alloy_rpc_types_eth::Header;
    type BlockResponse = alloy_rpc_types_eth::Block;
}

// Use Ethereum network (default)
let eth_provider = ProviderBuilder::new()
    .network::<Ethereum>()  // Explicit, but this is the default
    .connect_http("https://eth.llamarpc.com".parse()?);

// Or simply use the default
let eth_provider = ProviderBuilder::new()
    .connect_http("https://eth.llamarpc.com".parse()?);
```

### AnyNetwork - Catch-All Network Type

Use `AnyNetwork` when you need to work with multiple different network types or unknown networks:

```rust
use alloy::network::AnyNetwork;

// AnyNetwork can handle any blockchain network
let any_provider = ProviderBuilder::new()
    .network::<AnyNetwork>()
    .connect_http(rpc_url);

// Works with Ethereum
let eth_block = any_provider.get_block_by_number(18_000_000.into(), false).await?;

// Also works with OP-stack chains without changing the provider type
let base_provider = ProviderBuilder::new()
    .network::<AnyNetwork>()
    .connect_http("https://mainnet.base.org".parse()?);

let base_block = base_provider.get_block_by_number(10_000_000.into(), true).await?;

// Access network-specific fields through the `other` field
if let Some(l1_block_number) = base_block.header.other.get("l1BlockNumber") {
    println!("L1 origin block: {}", l1_block_number);
}
```

### OP-Stack Network Implementation

For OP-stack chains (Optimism, Base, etc.), use the specialized `Optimism` network:

```rust
use op_alloy_network::Optimism;
use op_alloy_consensus::{OpTxType, OpTxEnvelope, OpTypedTransaction, OpReceiptEnvelope};
use op_alloy_rpc_types::{OpTransactionRequest, Transaction, OpTransactionReceipt};

impl Network for Optimism {
    type TxType = OpTxType;
    type TxEnvelope = OpTxEnvelope;
    type UnsignedTx = OpTypedTransaction;
    type ReceiptEnvelope = OpReceiptEnvelope;
    type Header = alloy_consensus::Header;

    type TransactionRequest = OpTransactionRequest;
    type TransactionResponse = Transaction;
    type ReceiptResponse = OpTransactionReceipt;
    type HeaderResponse = alloy_rpc_types_eth::Header;
    type BlockResponse = alloy_rpc_types_eth::Block<Self::TransactionResponse, Self::HeaderResponse>;
}

// Use Optimism network for OP-stack chains
let op_provider = ProviderBuilder::new()
    .network::<Optimism>()
    .connect_http("https://mainnet.optimism.io".parse()?);

// Base also uses Optimism network type
let base_provider = ProviderBuilder::new()
    .network::<Optimism>()
    .connect_http("https://mainnet.base.org".parse()?);

// Now you get proper OP-stack types
let receipt = op_provider.send_transaction(tx).await?.get_receipt().await?;
// receipt is OpTransactionReceipt with L1 gas fields
println!("L1 gas used: {:?}", receipt.l1_gas_used);
```

### Network-Specific Error Handling

Choosing the wrong network type can cause deserialization errors:

```rust
// ❌ This will fail when fetching OP-stack blocks with deposit transactions
let wrong_provider = ProviderBuilder::new()
    .network::<Ethereum>()  // Wrong network type for Base
    .connect_http("https://mainnet.base.org".parse()?);

// Error: deserialization error: data did not match any variant of untagged enum BlockTransactions
let block = wrong_provider.get_block(10_000_000.into(), true).await?; // Fails!

// ✅ Solutions:
// Option 1: Use AnyNetwork (works with any chain)
let any_provider = ProviderBuilder::new()
    .network::<AnyNetwork>()
    .connect_http("https://mainnet.base.org".parse()?);

// Option 2: Use correct network type (better performance)
let base_provider = ProviderBuilder::new()
    .network::<Optimism>()
    .connect_http("https://mainnet.base.org".parse()?);
```

### Multi-Chain Application Patterns

```rust
use alloy::network::{AnyNetwork, Ethereum};
use op_alloy_network::Optimism;

// Pattern 1: Dynamic network selection
async fn create_provider_for_chain(chain_id: u64, rpc_url: &str) -> Result<impl Provider> {
    match chain_id {
        1 | 11155111 => {
            // Ethereum mainnet/sepolia - use Ethereum network for best performance
            Ok(ProviderBuilder::new()
                .network::<Ethereum>()
                .connect_http(rpc_url.parse()?))
        }
        10 | 8453 | 7777777 => {
            // OP-stack chains - use Optimism network
            Ok(ProviderBuilder::new()
                .network::<Optimism>()
                .connect_http(rpc_url.parse()?))
        }
        _ => {
            // Unknown chain - use AnyNetwork
            Ok(ProviderBuilder::new()
                .network::<AnyNetwork>()
                .connect_http(rpc_url.parse()?))
        }
    }
}

// Pattern 2: Generic network handling
async fn get_latest_block<N: Network>(provider: &impl Provider<N>) -> Result<N::BlockResponse>
where
    N::BlockResponse: std::fmt::Debug,
{
    let block = provider.get_block_by_number(BlockNumberOrTag::Latest, false).await?;
    println!("Latest block: {:?}", block.header().number());
    Ok(block)
}

// Pattern 3: Network-specific logic
async fn handle_receipt<N: Network>(receipt: N::ReceiptResponse) -> Result<()> {
    // Use type erasure to handle different receipt types
    let any_receipt: alloy_rpc_types::AnyReceiptEnvelope = receipt.try_into()?;

    match any_receipt {
        alloy_rpc_types::AnyReceiptEnvelope::Ethereum(eth_receipt) => {
            println!("Ethereum receipt: {:?}", eth_receipt.status());
        }
        alloy_rpc_types::AnyReceiptEnvelope::Optimism(op_receipt) => {
            println!("OP-stack receipt: {:?}", op_receipt.receipt.status());
            if let Some(l1_fee) = op_receipt.l1_fee {
                println!("L1 fee: {}", l1_fee);
            }
        }
        _ => println!("Other network receipt"),
    }

    Ok(())
}

// Pattern 4: Chain-specific transaction building
async fn send_optimized_transaction<N: Network>(
    provider: &impl Provider<N>,
    to: Address,
    value: U256,
) -> Result<B256> {
    let tx = N::TransactionRequest::default()
        .with_to(to)
        .with_value(value);

    // Network-specific optimizations can be applied here
    let tx_hash = provider.send_transaction(tx).await?.watch().await?;
    Ok(tx_hash)
}
```

### Custom Network Implementation

You can implement your own network type for specialized chains:

```rust
use alloy::network::Network;

// Custom network for a specialized blockchain
#[derive(Debug, Clone, Copy)]
pub struct MyCustomNetwork;

impl Network for MyCustomNetwork {
    type TxType = alloy_consensus::TxType;
    type TxEnvelope = alloy_consensus::TxEnvelope;
    type UnsignedTx = alloy_consensus::TypedTransaction;
    type ReceiptEnvelope = alloy_consensus::ReceiptEnvelope;
    type Header = alloy_consensus::Header;

    // Use custom RPC types if needed
    type TransactionRequest = CustomTransactionRequest;
    type TransactionResponse = CustomTransaction;
    type ReceiptResponse = CustomTransactionReceipt;
    type HeaderResponse = alloy_rpc_types_eth::Header;
    type BlockResponse = alloy_rpc_types_eth::Block<Self::TransactionResponse, Self::HeaderResponse>;
}

// Define custom types with network-specific fields
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CustomTransactionRequest {
    #[serde(flatten)]
    pub base: alloy_rpc_types_eth::TransactionRequest,
    pub custom_field: Option<U256>,
}

// Use your custom network
let custom_provider = ProviderBuilder::new()
    .network::<MyCustomNetwork>()
    .connect_http("https://my-custom-chain.com/rpc".parse()?);
```

### Best Practices for Network Selection

1. **Use specific network types** when possible for better performance and type safety
2. **Use AnyNetwork** for multi-chain applications or when the network type is unknown
3. **Match RPC endpoints** with the correct network implementation
4. **Handle network-specific fields** through the `other` field in responses
5. **Implement custom networks** for specialized blockchain requirements

</network_trait>

<rpc_consensus_types>

## RPC and Consensus Types

### Core Type System

Alloy provides a rich type system for blockchain interactions through two main crates:

#### Consensus Types (`alloy-consensus`)

Core blockchain primitives that represent the actual on-chain data structures:

```rust
use alloy_consensus::{
    Transaction, TxLegacy, TxEip1559, TxEip4844, TxEip7702,
    Receipt, ReceiptEnvelope, ReceiptWithBloom,
    Header, Block, BlockBody,
    SignableTransaction, Signed,
};

// Work with different transaction types
let legacy_tx = TxLegacy {
    chain_id: Some(1),
    nonce: 42,
    gas_price: 20_000_000_000,
    gas_limit: 21_000,
    to: TxKind::Call(recipient_address),
    value: U256::from(1_000_000_000_000_000_000u64), // 1 ETH
    input: Bytes::new(),
};

// EIP-1559 transaction
let eip1559_tx = TxEip1559 {
    chain_id: 1,
    nonce: 42,
    gas_limit: 21_000,
    max_fee_per_gas: 30_000_000_000,
    max_priority_fee_per_gas: 2_000_000_000,
    to: TxKind::Call(recipient_address),
    value: U256::from(1_000_000_000_000_000_000u64),
    input: Bytes::new(),
    access_list: AccessList::default(),
};
```

#### RPC Types (`alloy-rpc-types`)

JSON-RPC API types for interacting with Ethereum nodes:

```rust
use alloy_rpc_types::{
    Block, BlockTransactions, Transaction as RpcTransaction,
    TransactionReceipt, TransactionRequest,
    Filter, Log, FilterChanges,
    FeeHistory, SyncStatus,
    CallRequest, CallResponse,
    TraceFilter, TraceResults,
};

// Transaction request for RPC calls
let tx_request = TransactionRequest {
    from: Some(sender_address),
    to: Some(TxKind::Call(recipient_address)),
    value: Some(U256::from(1_000_000_000_000_000_000u64)),
    gas: Some(21_000),
    max_fee_per_gas: Some(30_000_000_000),
    max_priority_fee_per_gas: Some(2_000_000_000),
    ..Default::default()
};

// Filter for event logs
let filter = Filter::new()
    .address(contract_address)
    .topic0(event_signature)
    .from_block(18_000_000)
    .to_block(BlockNumberOrTag::Latest);
```

### Network-Specific Types

Use `AnyNetwork` for multi-chain applications or specific network types:

```rust
use alloy::network::{AnyNetwork, Ethereum};
use alloy_rpc_types::BlockTransactions;

// Generic network support
let provider = ProviderBuilder::new()
    .network::<AnyNetwork>()
    .connect_http(rpc_url);

// Ethereum-specific optimizations
let eth_provider = ProviderBuilder::new()
    .network::<Ethereum>()
    .connect_http("https://eth.llamarpc.com".parse()?);

// Access network-specific receipt fields
let receipt = provider.send_transaction(tx).await?.get_receipt().await?;
let extra_fields = receipt.other.deserialize_into::<CustomNetworkFields>()?;
```

</rpc_consensus_types>

<op_stack_support>

## OP-Stack Chain Support

For Optimism, Base, and other OP-stack chains, use the `op-alloy` crate which seamlessly integrates with Alloy:

### Dependencies

```toml
[dependencies]
# Core Alloy
alloy = { version = "1.0", features = ["full"] }

# OP-stack specific types and networks
op-alloy = "0.1"
op-alloy-consensus = "0.1"
op-alloy-rpc-types = "0.1"
op-alloy-network = "0.1"
```

### OP-Stack Transaction Types

OP-alloy provides specialized consensus and RPC types for Optimism and other OP-stack chains:

#### Consensus Types (`op-alloy-consensus`)

```rust
use op_alloy_consensus::{
    // Transaction types
    OpTxEnvelope, OpTxType, OpTypedTransaction,
    TxDeposit, // L1→L2 deposit transactions

    // Receipt types
    OpDepositReceipt, OpReceiptEnvelope,

    // Deposit sources
    UserDepositSource, L1InfoDepositSource,
    UpgradeDepositSource, InteropBlockReplacementDepositSource,
};

// Handle different OP-stack transaction types
match tx_envelope {
    OpTxEnvelope::Deposit(deposit_tx) => {
        println!("Deposit transaction:");
        println!("  From: {}", deposit_tx.from);
        println!("  Source hash: {:?}", deposit_tx.source_hash);
        println!("  Mint: {:?}", deposit_tx.mint);
        println!("  Is system tx: {}", deposit_tx.is_system_transaction);

        // Handle different deposit sources
        match deposit_tx.source_hash {
            source if is_user_deposit(&source) => {
                println!("  Type: User deposit");
            }
            source if is_l1_info_deposit(&source) => {
                println!("  Type: L1 info deposit");
            }
            _ => println!("  Type: Other deposit"),
        }
    }
    OpTxEnvelope::Eip1559(eip1559_tx) => {
        println!("EIP-1559 transaction");
    }
    OpTxEnvelope::Legacy(legacy_tx) => {
        println!("Legacy transaction");
    }
    OpTxEnvelope::Eip2930(eip2930_tx) => {
        println!("EIP-2930 transaction");
    }
    OpTxEnvelope::Eip4844(eip4844_tx) => {
        println!("EIP-4844 blob transaction");
    }
    OpTxEnvelope::Eip7702(eip7702_tx) => {
        println!("EIP-7702 transaction");
    }
}

// Create a deposit transaction
let deposit_tx = TxDeposit {
    source_hash: B256::random(),
    from: Address::random(),
    to: TxKind::Call(Address::random()),
    mint: Some(U256::from(1000000)),
    value: U256::from(500000),
    gas_limit: 21000,
    is_system_transaction: false,
    input: Bytes::new(),
};
```

#### RPC Types (`op-alloy-rpc-types`)

```rust
use op_alloy_rpc_types::{
    // Receipt types
    OpTransactionReceipt,

    // Block and chain info
    L1BlockInfo, OpGenesisInfo, OpChainInfo,

    // Transaction requests
    OpTransactionRequest,
};

// Work with OP-stack receipts
async fn process_op_receipt(receipt: OpTransactionReceipt) -> Result<()> {
    println!("Transaction hash: {:?}", receipt.transaction_hash);
    println!("Block number: {:?}", receipt.block_number);

    // OP-stack specific fields
    if let Some(l1_gas_used) = receipt.l1_gas_used {
        println!("L1 gas used: {}", l1_gas_used);
    }

    if let Some(l1_gas_price) = receipt.l1_gas_price {
        println!("L1 gas price: {}", l1_gas_price);
    }

    if let Some(l1_fee) = receipt.l1_fee {
        println!("L1 fee: {}", l1_fee);
    }

    // L1 fee scalar (cost calculation parameter)
    if let Some(l1_fee_scalar) = receipt.l1_fee_scalar {
        println!("L1 fee scalar: {}", l1_fee_scalar);
    }

    Ok(())
}

// Extract L1 block information from L2 block
async fn extract_l1_info(provider: &impl Provider, block_number: u64) -> Result<L1BlockInfo> {
    let block = provider.get_block_by_number(block_number.into(), true).await?;

    // The first transaction in an OP-stack block contains L1 block info
    if let Some(txs) = block.transactions.as_hashes() {
        if let Some(first_tx_hash) = txs.first() {
            let tx = provider.get_transaction_by_hash(*first_tx_hash).await?;

            // Extract L1 block info from deposit transaction
            if let Some(input) = tx.input {
                let l1_info = L1BlockInfo::try_from(input.as_ref())?;
                println!("L1 block number: {}", l1_info.number);
                println!("L1 block timestamp: {}", l1_info.timestamp);
                println!("L1 base fee: {}", l1_info.base_fee);
                return Ok(l1_info);
            }
        }
    }

    Err(eyre::eyre!("No L1 block info found"))
}

// Build OP-stack transaction requests
let op_tx_request = OpTransactionRequest {
    from: Some(sender_address),
    to: Some(recipient_address),
    value: Some(U256::from(1_000_000_000_000_000_000u64)), // 1 ETH
    gas: Some(21_000),
    max_fee_per_gas: Some(1_000_000_000), // 1 gwei
    max_priority_fee_per_gas: Some(1_000_000_000),
    ..Default::default()
};
```

### OP-Stack Network Configuration

````rust
use op_alloy_network::Optimism;
use alloy::providers::ProviderBuilder;

// Optimism Mainnet
let op_provider = ProviderBuilder::new()
    .network::<Optimism>()
    .connect_http("https://mainnet.optimism.io".parse()?);

// Base Mainnet
let base_provider = ProviderBuilder::new()
    .network::<Optimism>()  // Base uses Optimism network type
    .connect_http("https://mainnet.base.org".parse()?);

// Access OP-stack specific receipt fields
let receipt = op_provider.send_transaction(tx).await?.get_receipt().await?;
if let Ok(op_receipt) = receipt.try_into::<OpTransactionReceipt>() {
    println!("L1 gas used: {}", op_receipt.l1_gas_used.unwrap_or_default());
    println!("L1 gas price: {}", op_receipt.l1_gas_price.unwrap_or_default());
    println!("L1 fee: {}", op_receipt.l1_fee.unwrap_or_default());
}


### Multi-Chain OP-Stack Applications

```rust
use op_alloy_network::Optimism;
use alloy::network::AnyNetwork;

#[derive(Debug)]
struct OpStackChain {
    name: String,
    rpc_url: String,
    chain_id: u64,
}

const OP_CHAINS: &[OpStackChain] = &[
    OpStackChain {
        name: "Optimism".to_string(),
        rpc_url: "https://mainnet.optimism.io".to_string(),
        chain_id: 10,
    },
    OpStackChain {
        name: "Base".to_string(),
        rpc_url: "https://mainnet.base.org".to_string(),
        chain_id: 8453,
    },
    OpStackChain {
        name: "Zora".to_string(),
        rpc_url: "https://rpc.zora.energy".to_string(),
        chain_id: 7777777,
    },
];

async fn deploy_to_all_op_chains(
    bytecode: Bytes,
    signer: PrivateKeySigner,
) -> Result<Vec<Address>> {
    let mut addresses = Vec::new();

    for chain in OP_CHAINS {
        let provider = ProviderBuilder::new()
            .network::<Optimism>()
            .wallet(signer.clone())
            .connect_http(chain.rpc_url.parse()?);

        let tx = TransactionRequest::default().with_deploy_code(bytecode.clone());
        let receipt = provider.send_transaction(tx).await?.get_receipt().await?;

        if let Some(address) = receipt.contract_address {
            println!("Deployed to {} at: {}", chain.name, address);
            addresses.push(address);
        }
    }

    Ok(addresses)
}
````

</op_stack_support>

<feature_flags>

## Important Feature Flags

When working with Alloy, include relevant features in your Cargo.toml:

```toml
[dependencies]
# Full feature set (recommended for most applications)
alloy = { version = "1.0", features = ["full"] }

# Or select specific features for smaller binary size
alloy = { version = "1.0", features = [
    "node-bindings",    # Anvil, Geth local testing
    "signer-local",     # Local private key signing
    "signer-keystore",  # Keystore file support
    "signer-ledger",    # Ledger hardware wallet
    "signer-trezor",    # Trezor hardware wallet
    "signer-aws",       # AWS KMS signing
    "rpc-types-trace",  # Debug/trace RPC support
    "json-rpc",         # JSON-RPC client
    "ws",               # WebSocket transport
    "ipc",              # IPC transport
] }

# Additional async runtime
tokio = { version = "1.0", features = ["full"] }
eyre = "0.6"  # Error handling

# OP-Stack support (for Optimism, Base, etc.)
op-alloy = "0.1"
op-alloy-consensus = "0.1"
op-alloy-rpc-types = "0.1"
op-alloy-network = "0.1"
```

### Common Feature Combinations

- **Basic Usage**: `["json-rpc", "signer-local"]`
- **Web Applications**: `["json-rpc", "signer-keystore", "ws"]`
- **DeFi Applications**: `["full"]` (recommended)
- **Testing**: `["node-bindings", "signer-local"]`
- **OP-Stack Applications**: `["full"]` + op-alloy crates
- **Multi-Chain Applications**: `["full", "ws"]` + network-specific crates

</feature_flags>

<layers_and_fillers>

## Layers and Fillers

### Recommended Fillers (Default)

```rust
// These are enabled by default with ProviderBuilder::new()
let provider = ProviderBuilder::new()
    .with_recommended_fillers()  // Includes:
    // - ChainIdFiller: Automatically sets chain_id
    // - GasFiller: Estimates gas and sets gas price
    // - NonceFiller: Manages transaction nonces
    .connect_http(rpc_url);
```

### Custom Fillers

```rust
use alloy::providers::fillers::{TxFiller, GasFiller, NonceFiller};

let provider = ProviderBuilder::new()
    .filler(GasFiller::new())      // Custom gas estimation
    .filler(NonceFiller::new())    // Nonce management
    .layer(CustomLayer::new())     // Custom middleware
    .connect_http(rpc_url);
```

### Transport Layers

```rust
use alloy::rpc::client::ClientBuilder;
use tower::ServiceBuilder;

// Add retry and timeout layers
let client = ClientBuilder::default()
    .layer(
        ServiceBuilder::new()
            .timeout(Duration::from_secs(30))
            .retry(RetryPolicy::new())
            .layer(LoggingLayer)
    )
    .http(rpc_url);

let provider = ProviderBuilder::new().connect_client(client);
```

</layers_and_fillers>

<testing_patterns>

## Testing with Alloy

### Local Development with Anvil

```rust
use alloy::node_bindings::Anvil;

#[tokio::main]
async fn main() -> Result<()> {
    // Spin up local Anvil instance
    let anvil = Anvil::new()
        .block_time(1)
        .chain_id(31337)
        .spawn();

    // Connect with pre-funded account
    let provider = ProviderBuilder::new()
        .wallet(anvil.keys()[0].clone().into())
        .connect_anvil_with_wallet();

    // Deploy and test contracts
    let contract_address = deploy_contract(&provider).await?;
    test_contract_functionality(contract_address, &provider).await?;

    Ok(())
}
```

### Fork Testing

```rust
// Fork mainnet at specific block
let anvil = Anvil::new()
    .fork("https://eth.llamarpc.com")
    .fork_block_number(18_500_000)
    .spawn();

let provider = ProviderBuilder::new().connect_anvil();
```

</testing_patterns>

<common_workflows>

## Common Workflows

### ERC-20 Token Interactions

```rust
sol! {
    #[sol(rpc)]
    contract IERC20 {
        function balanceOf(address) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);
        function approve(address spender, uint256 amount) external returns (bool);

        event Transfer(address indexed from, address indexed to, uint256 value);
    }
}

async fn transfer_tokens(
    provider: &impl Provider,
    token_address: Address,
    to: Address,
    amount: U256,
) -> Result<B256> {
    let contract = IERC20::new(token_address, provider);
    let tx_hash = contract.transfer(to, amount).send().await?.watch().await?;
    Ok(tx_hash)
}
```

### Event Monitoring

```rust
use alloy::{
    providers::{Provider, ProviderBuilder},
    rpc::types::{Filter, Log},
    sol_types::SolEvent,
};

// Monitor Transfer events
let filter = Filter::new()
    .address(token_address)
    .event_signature(IERC20::Transfer::SIGNATURE_HASH)
    .from_block(BlockNumberOrTag::Latest);

let logs = provider.get_logs(&filter).await?;
for log in logs {
    let decoded = IERC20::Transfer::decode_log_data(log.data(), true)?;
    println!("Transfer: {} -> {} ({})", decoded.from, decoded.to, decoded.value);
}
```

### Multicall Batching

```rust
use alloy::contract::multicall::Multicall;

let multicall = Multicall::new(provider.clone(), None).await?;

// Add multiple calls
multicall.add_call(contract1.balanceOf(user1), false);
multicall.add_call(contract2.balanceOf(user2), false);
multicall.add_call(contract3.totalSupply(), false);

// Execute all calls in single transaction
let results = multicall.call().await?;
```

</common_workflows>

<performance_optimization>

## Performance Best Practices

### Primitive Types

```rust
use alloy::primitives::{U256, Address, B256, address};

// Use U256 for large numbers (2-3x faster than other implementations)
let amount = U256::from(1_000_000_000_000_000_000u64); // 1 ETH in wei

// Use address! macro for Ethereum addresses (preferred)
let recipient = address!("d8dA6BF26964aF9D7eEd9e03E53415D37aA96045");
// Or parse from string when dynamic
let recipient = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045".parse::<Address>()?;
```

### Efficient Contract Calls

```rust
// Use sol! macro for compile-time optimizations (up to 10x faster ABI encoding)
sol! {
    #[sol(rpc)]
    contract MyContract {
        function myFunction(uint256 value) external returns (uint256);
    }
}

// Batch read operations
let contract = MyContract::new(address, provider);
let calls = vec![
    contract.myFunction(U256::from(1)),
    contract.myFunction(U256::from(2)),
    contract.myFunction(U256::from(3)),
];

// Use multicall for efficient batching
let results = multicall_batch(calls).await?;
```

### Connection Pooling

```rust
// Reuse provider instances
static PROVIDER: Lazy<Arc<Provider>> = Lazy::new(|| {
    Arc::new(ProviderBuilder::new().connect_http("https://eth.llamarpc.com".parse().unwrap()))
});

// Use WebSocket for subscriptions
let ws_provider = ProviderBuilder::new().connect_ws("wss://eth.llamarpc.com".parse()?);
```

</performance_optimization>

<error_handling>

## Error Handling

### RPC Errors

```rust
use alloy::{
    rpc::types::eth::TransactionReceipt,
    transports::{RpcError, TransportErrorKind},
};

async fn handle_transaction(provider: &impl Provider, tx: TransactionRequest) -> Result<TransactionReceipt> {
    match provider.send_transaction(tx).await {
        Ok(pending_tx) => {
            match pending_tx.get_receipt().await {
                Ok(receipt) => {
                    if receipt.status() {
                        Ok(receipt)
                    } else {
                        Err(eyre::eyre!("Transaction reverted"))
                    }
                }
                Err(e) => Err(eyre::eyre!("Failed to get receipt: {}", e))
            }
        }
        Err(RpcError::Transport(TransportErrorKind::Custom(err))) => {
            // Handle custom transport errors
            Err(eyre::eyre!("Transport error: {}", err))
        }
        Err(e) => Err(eyre::eyre!("RPC error: {}", e))
    }
}
```

### Contract Errors

```rust
sol! {
    error InsufficientBalance(uint256 available, uint256 required);
    error Unauthorized(address caller);
}

// Handle custom contract errors
match contract.transfer(to, amount).send().await {
    Ok(tx_hash) => println!("Transfer successful: {}", tx_hash),
    Err(e) => {
        if let Some(InsufficientBalance { available, required }) = e.as_revert::<InsufficientBalance>() {
            println!("Insufficient balance: {} < {}", available, required);
        } else if let Some(Unauthorized { caller }) = e.as_revert::<Unauthorized>() {
            println!("Unauthorized caller: {}", caller);
        } else {
            println!("Unknown error: {}", e);
        }
    }
}
```

</error_handling>

<security_guidelines>

## Security Best Practices

### Private Key Management

```rust
// ❌ Never hardcode private keys
let signer = PrivateKeySigner::from_str("0x1234...")?; // DON'T DO THIS

// ✅ Use environment variables or secure storage
let private_key = std::env::var("PRIVATE_KEY")?;
let signer = PrivateKeySigner::from_str(&private_key)?;

// ✅ Use keystore files
let keystore = std::fs::read_to_string("keystore.json")?;
let signer = PrivateKeySigner::decrypt_keystore(&keystore, "password")?;

// ✅ Use hardware wallets for production
use alloy::signers::ledger::LedgerSigner;
let signer = LedgerSigner::new(derivation_path).await?;
```

### Transaction Validation

```rust
// Always validate transaction parameters
async fn safe_transfer(
    provider: &impl Provider,
    to: Address,
    amount: U256,
) -> Result<B256> {
    // Validate recipient address
    if to == Address::ZERO {
        return Err(eyre::eyre!("Cannot transfer to zero address"));
    }

    // Check balance before transfer
    let balance = provider.get_balance(provider.default_signer_address(), None).await?;
    if balance < amount {
        return Err(eyre::eyre!("Insufficient balance"));
    }

    // Estimate gas and add buffer
    let tx = TransactionRequest::default().with_to(to).with_value(amount);
    let gas_estimate = provider.estimate_gas(&tx, None).await?;
    let tx = tx.with_gas_limit(gas_estimate * 110 / 100);

    provider.send_transaction(tx).await?.watch().await
}
```

### Input Sanitization

```rust
// Validate addresses
fn validate_address(addr_str: &str) -> Result<Address> {
    addr_str.parse::<Address>()
        .map_err(|e| eyre::eyre!("Invalid address: {}", e))
}

// Validate amounts
fn validate_amount(amount_str: &str) -> Result<U256> {
    amount_str.parse::<U256>()
        .map_err(|e| eyre::eyre!("Invalid amount: {}", e))
}
```

</security_guidelines>

<configuration_examples>

## Configuration Examples

### Basic Application

```toml
[dependencies]
alloy = { version = "1.0", features = ["full"] }
tokio = { version = "1.0", features = ["full"] }
eyre = "0.6"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

### DeFi Application

```toml
[dependencies]
alloy = { version = "1.0", features = [
    "full",
    "signer-keystore",
    "signer-ledger",
    "rpc-types-trace",
    "ws"
] }
tokio = { version = "1.0", features = ["full"] }
eyre = "0.6"
tracing = "0.1"
tracing-subscriber = "0.3"
```

### Minimal CLI Tool

```toml
[dependencies]
alloy = { version = "1.0", features = [
    "json-rpc",
    "signer-local",
    "node-bindings"
] }
tokio = { version = "1.0", features = ["rt", "macros"] }
eyre = "0.6"
clap = { version = "4.0", features = ["derive"] }
```

</configuration_examples>

<user_prompt>

# alloy

## v1.0 Changes

#### Revamping the `sol!` macro bindings

- [Contract and RPC codegen made cleaner by removal of the `T` transport generic](/migrating-to-core-v1/sol!-changes/removing-T-generic)
- [Improving the function return types by removing the need for `_0`](/migrating-to-core-v1/sol!-changes/improving-function-return-types)
- [Changes to function call bindings e.g `pub struct balanceOfCall { _0: Address }` to `pub struct balanceOfCall(pub Address)`](/migrating-to-core-v1/sol!-changes/changes-to-function-call-bindings)
- [Changes to event bindings](/migrating-to-core-v1/sol!-changes/changes-to-event-bindings)
- [Changes to error bindings](/migrating-to-core-v1/sol!-changes/changes-to-error-bindings)

#### Simplify ABI encoding and decoding

- [ABI encoding function return structs](/migrating-to-core-v1/encoding-decoding-changes/encoding-return-structs)
- [Removing `validate: bool` from the `abi_decode` methods](/migrating-to-core-v1/encoding-decoding-changes/removing-validate-bool)

#### Other breaking changes

- [Removal of the deprecated `Signature` type. `PrimitiveSignature` is now aliased to `Signature`](https://github.com/alloy-rs/core/pull/899)
- [Renaming methods in User-defined types (UDT)'s bindings and implementing `From` and `Into` traits for UDT's](https://github.com/alloy-rs/core/pull/905)
- [Bumping `getrandom` and `rand`](https://github.com/alloy-rs/core/pull/869)
- [Removal of `From<String>` for `Bytes`](https://github.com/alloy-rs/core/pull/907)

If you'd like to dive into the details of each change, please take a look at this [PR](https://github.com/alloy-rs/core/pull/895)

### Querying Contracts

#### Query Contract Storage

```rust
// [!include ~/snippets/queries/examples/query_contract_storage.rs]
```

#### Query Contract Code

```rust
// [!include ~/snippets/queries/examples/query_deployed_bytecode.rs]
```

#### Query Logs

```rust
// [!include ~/snippets/queries/examples/query_logs.rs]
```

### Reading a contract

We shall leverage the `sol!` macro and its `rpc` attribute to get the [WETH](https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2) balance of an address.

The RPC interaction is enabled via the [`CallBuilder`](https://docs.rs/alloy/latest/alloy/contract/struct.CallBuilder.html) which handles transaction creation, setting fees and inserting the correct calldata.

```rust showLineNumbers [read_contract.rs]
//! Demonstrates reading a contract by fetching the WETH balance of an address.
use alloy::{primitives::address, providers::ProviderBuilder, sol};
use std::error::Error;

// Generate the contract bindings for the ERC20 interface.
sol! { // [!code focus]
   // The `rpc` attribute enables contract interaction via the provider. [!code focus]
   #[sol(rpc)] // [!code focus]
   contract ERC20 { // [!code focus]
        function balanceOf(address owner) public view returns (uint256); // [!code focus]
   } // [!code focus]
} // [!code focus]

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Initialize the provider.
    let provider = ProviderBuilder::new().connect("https://reth-ethereum.ithaca.xyz/rpc").await?;

    // Instantiate the contract instance.
    let weth = address!("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    let erc20 = ERC20::new(weth, provider); // [!code focus]

    // Fetch the balance of WETH for a given address.
    let owner = address!("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"); // [!code focus]
    let balance = erc20.balanceOf(owner).call().await?; // [!code focus]

    println!("WETH Balance of {owner}: {balance}");

    Ok(())
}
```

### Using the sol! macro

Alloy provides a powerful and intuitive way to read and write to contracts using the `sol!` procedural macro.

The sol! parses Solidity syntax to generate types that implement [alloy-sol-types](https://github.com/alloy-rs/core/tree/main/crates/sol-types) traits.
It uses [`syn-solidity`](https://github.com/alloy-rs/core/tree/main/crates/syn-solidity), a [syn](https://github.com/dtolnay/syn)-powered Solidity parser.
It aims to mimic the behavior of the official Solidity compiler (`solc`) when it comes to parsing valid Solidity code. This means that all valid Solidity code, as recognized by `solc` `0.5.0` and above is supported.

In its most basic form `sol!` is used like this:

```rust showLineNumbers
use alloy::{primitives::U256, sol};

// Declare a Solidity type in standard Solidity
// [!code focus]
sol! { // [!code focus]
    // ... with attributes too!
    #[derive(Debug)] // [!code focus]
    struct Foo { // [!code focus]
        uint256 bar; // [!code focus]
        bool baz; // [!code focus]
    } // [!code focus]
} // [!code focus]

// A corresponding Rust struct is generated:
// #[derive(Debug)]
// pub struct Foo {
//     pub bar: U256,
//     pub baz: bool,
// }

let foo = Foo { bar: U256::from(42), baz: true }; // [!code focus]
println!("{foo:#?}"); // [!code focus]
```

### Generate Rust Bindings

The sol! macro comes with the flexibilty of generating rust bindings for your contracts in multiple ways.

#### Solidity

You can directly write Solidity code:

```rust
sol! {
    contract Counter {
        uint256 public number;

        function setNumber(uint256 newNumber) public {
            number = newNumber;
        }

        function increment() public {
            number++;
        }
    }
}
```

Or provide a path to a Solidity file:

```rust
sol!(
    "artifacts/Counter.sol"
);
```

#### JSON-ABI

By enabling the `json` feature, you can generate rust bindings from ABI compliant strings or abi files directly.

The format is either a JSON ABI array or an object containing an `"abi"` key. It supports common artifact formats like Foundry's:

Using an ABI file:

```rust
sol!(
    ICounter,
    "abi/Counter.json"
);
```

Using an ABI compliant string:

```rust
sol!(
   ICounter,
   r#"[
        {
            "type": "function",
            "name": "increment",
            "inputs": [],
            "outputs": [],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "number",
            "inputs": [],
            "outputs": [
                {
                    "name": "",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "stateMutability": "view"
        },
        {
            "type": "function",
            "name": "setNumber",
            "inputs": [
                {
                    "name": "newNumber",
                    "type": "uint256",
                    "internalType": "uint256"
                }
            ],
            "outputs": [],
            "stateMutability": "nonpayable"
        }
   ]"#
);
```

#### Snippets

At times, you don't want to generate for the complete contract to keep your project light but still want call one or two functions.
You can generate bindings for valid solidity snippets as well.

```rust
sol!(
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
);

println!("Decoding https://etherscan.io/tx/0xd1b449d8b1552156957309bffb988924569de34fbf21b51e7af31070cc80fe9a");

let input = hex::decode("0x38ed173900000000000000000000000000000000000000000001a717cc0a3e4f84c00000000000000000000000000000000000000000000000000000000000000283568400000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000201f129111c60401630932d9f9811bd5b5fff34e000000000000000000000000000000000000000000000000000000006227723d000000000000000000000000000000000000000000000000000000000000000200000000000000000000000095ad61b0a150d79219dcf64e1e6cc01f0b64c4ce000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7")?;

// Decode the input using the generated `swapExactTokensForTokens` bindings.
let decoded = swapExactTokensForTokensCall::abi_decode(&input);
```

#### Forge bind

When working with large solidity projects it can be cumbersome to input your solidity code or ABI files into the `sol!` macro.

You can use the `forge bind` command from [foundry](https://book.getfoundry.sh/reference/forge/forge-bind) to generate alloy compatible rust bindings for your entire project or a selection of files.

You can learn more about the command and its various options [here](https://book.getfoundry.sh/reference/forge/forge-bind).

### Attributes

One can use the sol attributes to add additional functionality to the generated rust code.

For example, the `#[sol(rpc)]` attribute generates code to enable seamless interaction with the contract over the RPC provider.
It generates a method for each function in a contract that returns a [`CallBuilder`](https://docs.rs/alloy/latest/alloy/contract/struct.CallBuilder.html) for that function.

If `#[sol(bytecode = "0x...")]` is provided, the contract can be deployed with `Counter::deploy` and a new instance will be created.
The bytecode is also loaded from Foundry-style JSON artifact files.

```rust
// [!include ~/snippets/contracts/examples/deploy_from_contract.rs]
```

You can find a full list of attributes [here](https://docs.rs/alloy-sol-macro/latest/alloy_sol_macro/macro.sol.html#attributes).

### Writing to a contract

The `sol!` macro also helps up building transactions and submit them to the chain seamless.
Once again, this is enabled via the `rpc` attribute and the [`CallBuilder`](https://docs.rs/alloy/latest/alloy/contract/struct.CallBuilder.html) type similar to how they aided in [`reading a contract`](/contract-interactions/read-contract).

The `CallBuilder` exposes various transaction setting methods such as [`.value(..)`](https://docs.rs/alloy/latest/alloy/contract/struct.CallBuilder.html#method.value) to modify the transaction before sending it. The calldata encoding is handled under the hood.

We'll be forking mainnet using a local anvil node to avoid spending real ETH.

```rust showLineNumbers [write_contract.rs]
//! Demonstrates writing to a contract by depositing ETH to the WETH contract.
use alloy::{primitives::{address, utils::{format_ether, Unit}, U256},
    providers::ProviderBuilder,
    signers::local::PrivateKeySigner,
    sol,
};
use std::error::Error;

// Generate bindings for the WETH9 contract.
// WETH9: <https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2>
sol! { // [!code focus]
    #[sol(rpc)] // [!code focus]
    contract WETH9 { // [!code focus]
        function deposit() public payable; // [!code focus]
        function balanceOf(address) public view returns (uint256); // [!code focus]
    } // [!code focus]
} // [!code focus]

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Initialize a signer with a private key.
    let signer: PrivateKeySigner =
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80".parse()?;

    // Instantiate a provider with the signer.
    let provider = ProviderBuilder::new() // [!code focus]
        // Signs transactions before dispatching them.
        .wallet(signer) // Signs the transactions // [!code focus]
        // Forking mainnet using anvil to avoid spending real ETH.
        .connect_anvil_with_config(|a| a.fork("https://reth-ethereum.ithaca.xyz/rpc"));

    // Setup WETH contract instance.
    let weth = address!("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2");
    let weth = WETH9::new(weth, provider); // [!code focus]

    // Prepare deposit transaction.
    let amt = Unit::ETHER.wei().saturating_mul(U256::from(100)); // [!code focus]
    let deposit = weth.deposit().value(amt); // [!code focus]

    // Send the transaction and wait for it to be included.
    let deposit_tx = deposit.send().await?; // [!code focus]
    let receipt = deposit_tx.get_receipt().await?; // [!code focus]

    // Check balance by verifying the deposit.
    let balance = weth.balanceOf(receipt.from).call().await?;
    println!("Verified balance of {:.3} WETH for {}", format_ether(balance), receipt.from); // [!code focus]
    Ok(())
}
```

## Building a High-Priority Transaction Queue with Alloy Fillers

In this guide, we will explore more advanced use cases of Alloy Providers APIs. We will cover non-standard ways to instantiate and customize providers and deep dive into custom layers and fillers implementations. We have a lot to cover, so let's get started!

### Fillers

Fillers decorate a Provider, and hook into the transaction lifecycle filling details before they are sent to the network. We can use fillers to build a transaction preprocessing pipeline, "filling" all the missing properties such as `nonce`, `chain_id`, `max_fee_per_gas`, and `max_priority_fee_per_gas` etc.

Since, [alloy `v0.11.0`](https://github.com/alloy-rs/alloy/releases/tag/v0.11.0) the most essential fillers are enabled by default when building a provider using `ProviderBuilder::new()`.
These core fillers are termed as [`RecommendedFillers`](https://docs.rs/alloy-provider/latest/alloy_provider/fillers/type.RecommendedFiller.html) and consists of the following:

- [`NonceFiller`](https://docs.rs/alloy-provider/latest/alloy_provider/fillers/struct.NonceFiller.html): Fills the `nonce` field of a transaction with the next available nonce.
- [`ChainIdFiller`](https://docs.rs/alloy-provider/latest/alloy_provider/fillers/struct.ChainIdFiller.html): Fills the `chain_id` field of a transaction with the chain ID of the provider.
- [`GasFiller`](https://docs.rs/alloy-provider/latest/alloy_provider/fillers/struct.GasFiller.html): Fills the gas related fields such as `gas_price`, `gas_limit`, `max_fee_per_gas` and `max_priority_fee_per_gas` fields of a transaction with the current gas price.
- [`BlobGasFiller`](https://docs.rs/alloy-provider/latest/alloy_provider/fillers/struct.BlobGasFiller.html): Fills the `max_fee_per_blob_gas` field for EIP-4844 transactions.

In a world without the above fillers, sending a simple transfer transaction looks like the following:

[ `examples/basic_provider.rs`](/examples/providers/basic_provider)

:::code-group

```rust [basic_provider.rs]
// [!include ~/snippets/providers/examples/basic_provider.rs]
```

```bash [output]
Balance before: 0
Balance after: 1
```

:::

In this example, we sent 1 wei from `alice` (default anvil account) to `bob`. You can see that a lot of boilerplate is involved in building the transaction data. We must manually check the account's current `nonce`, network fees, `gas_limit`, and `chain_id`.

If we omitted any of the transaction properties we'd see an error like:

```text
Caused by:
    missing properties: [("Wallet", ["nonce", "gas_limit", "max_fee_per_gas", "max_priority_fee_per_gas"])]
```

Now, let's see how using `RecommendedFillers` improves this:

[ `examples/recommended.rs`](/examples/fillers/recommended_fillers)

```rust
#[tokio::main]
async fn main() -> Result<()> {
    let provider = ProviderBuilder::new().connect_anvil_with_wallet();
    let bob = Address::from([0x42; 20]);
    let tx = TransactionRequest::default()
        .with_to(bob)
        .with_value(U256::from(1));

    let bob_balance_before = provider.get_balance(bob).await?;
    _ = provider.send_transaction(tx).await?.get_receipt().await?;
    let bob_balance_after = provider.get_balance(bob).await?;
    println!(
        "Balance before: {}\nBalance after: {}",
        bob_balance_before, bob_balance_after
    );

    Ok(())
}
```

We've removed \~15 LOC while preserving the same functionality! Most heavy lifting was taken over by recommended fillers that are enabled upon `ProviderBuilder::new()` and the `connect_anvil_with_wallet` method.

`connect_anvil_with_wallet` is a helper method that implicitly spawns the Anvil process and enables the [`WalletFiller`](https://docs.rs/alloy/latest/alloy/providers/fillers/struct.WalletFiller.html) that sets the `from` field based on the wallet's signer address and signs the transaction.

This explains why we could omit filling out `nonce`, `chain_id`, `max_fee_per_gas` and `max_priority_fee_per_gas` in the second example.

In case you want you want to disable the default fillers you can do so by calling [`disable_recommended_fillers()`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.disable_recommended_fillers) on the `ProviderBuilder`, and setting the fillers of your choice manually.

Alloy comes with builder methods for automatically applying fillers to providers:

- [ `wallet`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.wallet) - set `from` based on the wallet's signer address
- [ `fetch_chain_id`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.fetch_chain_id) - automatically set `chain_id` based on data from the provider
- [ `with_chain_id`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.with_chain_id) - automatically set `chain_id` based on provided value
- [ `with_simple_nonce_management`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.with_simple_nonce_management) - set `nonce` based on txs count from provider
- [ `with_cached_nonce_management`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.with_cached_nonce_management) - like above but with caching
- [ `with_nonce_management`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.with_nonce_management) - provided custom `nonce` management strategy
- [ `with_gas_estimation`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.with_gas_estimation) - set gas prices based on data from the provider

Let's go beyond the basics and implement a custom filler to better understand the inner workings.

### Implementing a custom filler

Submitting txs with a high-enough gas price, to land in the next block is a common use case. We will implement a custom filler to automatically check and fill the correct gas price.

We will query the free [Blocknative Gas API](https://docs.blocknative.com/gas-prediction/gas-platform) to check the recommended gas price, and land our payload in the next block.

We will be working with the following API output:

:::code-group

```bash [request]
curl https://api.blocknative.com/gasprices/blockprices
```

```json [response]
{
  "system": "ethereum",
  "network": "main",
  "unit": "gwei",
  "maxPrice": 172.0,
  "currentBlockNumber": 21465702,
  "msSinceLastBlock": 14416,
  "blockPrices": [
    {
      "blockNumber": 21465703,
      "estimatedTransactionCount": 67,
      "baseFeePerGas": 36.23398572,
      "blobBaseFeePerGas": 25.17758517,
      "estimatedPrices": [
        {
          "confidence": 99,
          "price": 36.53,
          "maxPriorityFeePerGas": 0.29,
          "maxFeePerGas": 72.76
        },
        {
          "confidence": 95,
          "price": 36.3,
          "maxPriorityFeePerGas": 0.062,
          "maxFeePerGas": 72.53
        },
        {
          "confidence": 90,
          "price": 36.29,
          "maxPriorityFeePerGas": 0.057,
          "maxFeePerGas": 72.52
        },
        {
          "confidence": 80,
          "price": 36.28,
          "maxPriorityFeePerGas": 0.047,
          "maxFeePerGas": 72.51
        },
        {
          "confidence": 70,
          "price": 36.27,
          "maxPriorityFeePerGas": 0.037,
          "maxFeePerGas": 72.5
        }
      ]
    }
  ]
}
```

:::

It shows gas prices needed to commit tx in the next block, with a specified confidence.

To build a custom filler, you have to implement a [`TxFiller`](https://docs.rs/alloy-provider/latest/alloy_provider/fillers/trait.TxFiller.html) trait. Here's a sample implementation for our `UrgentQueue` filler:

[`examples/urgent_filler.rs`](/examples/fillers/urgent_filler)

```rust
#[derive(Clone, Debug, Default)]
pub struct UrgentQueue {
    client: Client,
}

impl UrgentQueue {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
        }
    }
}

#[derive(Debug)]
pub struct GasPriceFillable {
    max_fee_per_gas: u128,
    max_priority_fee_per_gas: u128,
}

impl<N: Network> TxFiller<N> for UrgentQueue {
    type Fillable = GasPriceFillable;

    fn status(&self, tx: &<N as Network>::TransactionRequest) -> FillerControlFlow {
        if tx.max_fee_per_gas().is_some() && tx.max_priority_fee_per_gas().is_some() {
            FillerControlFlow::Finished
        } else {
            FillerControlFlow::Ready
        }
    }
    fn fill_sync(&self, _tx: &mut SendableTx<N>) {}

    async fn fill(
        &self,
        fillable: Self::Fillable,
        mut tx: SendableTx<N>,
    ) -> TransportResult<SendableTx<N>> {
        if let Some(builder) = tx.as_mut_builder() {
            builder.set_max_fee_per_gas(fillable.max_fee_per_gas);
            builder.set_max_priority_fee_per_gas(fillable.max_priority_fee_per_gas);
        } else {
            panic!("Expected a builder");
        }

        Ok(tx)
    }

    async fn prepare<P>(
        &self,
        _provider: &P,
        _tx: &<N as Network>::TransactionRequest,
    ) -> TransportResult<Self::Fillable>
    where
        P: Provider<N>,
    {
        println!("Fetching gas prices from Blocknative");
        let data =
            match self.client.get("https://api.blocknative.com/gasprices/blockprices").send().await
            {
                Ok(res) => res,
                Err(e) => {
                    return Err(RpcError::Transport(TransportErrorKind::Custom(Box::new(
                        std::io::Error::new(
                            std::io::ErrorKind::Other,
                            format!("Failed to fetch gas price, {}", e),
                        ),
                    ))));
                }
            };
        let body = data.text().await.unwrap();
        let json = serde_json::from_str::<serde_json::Value>(&body).unwrap();
        let prices = &json["blockPrices"][0]["estimatedPrices"][0];
        let max_fee_per_gas = (prices["maxFeePerGas"].as_f64().unwrap() * 1e9) as u128;
        let max_priority_fee_per_gas =
            (prices["maxPriorityFeePerGas"].as_f64().unwrap() * 1e9) as u128;

        let fillable = GasPriceFillable { max_fee_per_gas, max_priority_fee_per_gas };
        Ok(fillable)
    }
}
```

The above implementation fetches gas prices from the Blocknative API and injects them into our transaction. With this implementation, we'll have 99% confidence that our transaction will land in the next block. Here's how you can build the provider with the `UrgentQueue` filler:

[ `examples/urgent_filler.rs`](/examples/fillers/urgent_filler)

```rust
let provider = ProviderBuilder::new()
    .filler(UrgentQueue::default())
    .connect_anvil_with_wallet();
```

The rest of the example remains the same. It shows a great feature of fillers, i.e. composability. They are processed in reverse order, meaning that our `UrgentQueue` filler will take precedence over the built-in `GasFiller`.

### Summary

Fillers are helpful in reworking txs submission logic, depending on any custom conditions. The presented `UrgentQueue` implementation is relatively basic, but should serve you as a starting point for building your custom fillers.

## Interacting with multiple networks

The provider trait is generic over the network type, `Provider<N: Network = Ethereum>`, with the default network set to `Ethereum`.

The `Network` generic helps the provider to accommodate various network types with different transaction and RPC response types seamlessly.

### The Network trait

This removes the need for implementing the `Provider` trait for each network type you want to interact with. Instead, we just need to implement the `Network` trait.

Following is the [`Ethereum` network implementation](https://github.com/alloy-rs/alloy/blob/main/crates/network/src/ethereum/mod.rs) which defines the structure of the network and its RPC types.

```rust [ethereum.rs]
impl Network for Ethereum {
    type TxType = alloy_consensus::TxType;

    type TxEnvelope = alloy_consensus::TxEnvelope;

    type UnsignedTx = alloy_consensus::TypedTransaction;

    type ReceiptEnvelope = alloy_consensus::ReceiptEnvelope;

    type Header = alloy_consensus::Header;

    type TransactionRequest = alloy_rpc_types_eth::transaction::TransactionRequest;

    type TransactionResponse = alloy_rpc_types_eth::Transaction;

    type ReceiptResponse = alloy_rpc_types_eth::TransactionReceipt;

    type HeaderResponse = alloy_rpc_types_eth::Header;

    type BlockResponse = alloy_rpc_types_eth::Block;
}
```

Choosing the wrong network type can lead to unexpected deserialization errors due to differences in RPC types. For example, the using an `Ethereum` network provider to get a full block with transactions can result in the following error:

```rust [base_block.rs]
let provider = ProviderBuilder::new()
        .network::<Ethereum>()
        .connect_http("https://base-sepolia.ithaca.xyz/".parse()?);

// Yields: Error: deserialization error: data did not match any variant of untagged enum BlockTransactions // [!code hl]
let block_with_txs = provider.get_block(25508329.into()).full().await?;
```

This is due to the `Deposit` transaction type which is not supported by `Ethereum` network. This can be fixed in two ways either by using the catch-all `AnyNetwork` type or by using the dedicated `Optimism` network implementation from [op-alloy-network](https://crates.io/crates/op-alloy-network).

### Catch-all network: `AnyNetwork`

The `Provider` defaults to the ethereum network type, but one can easily switch to another network while building the provider like so:

```rust
let provider = ProviderBuilder::new()
    .network::<AnyNetwork>() // [!code hl]
    .connect_http("http://localhost:8545");
```

The [`AnyNetwork` type](https://github.com/alloy-rs/alloy/blob/main/crates/network/src/any/mod.rs) is a catch-all network allowing you to interact with any network type, in case you don't want to roll your own network type.

### Custom Network: `Optimism`

The [`Optimism` network](https://github.com/alloy-rs/op-alloy/blob/main/crates/network/src/lib.rs) type has been created to interact with OP-stack chains such as Base.

```rust [optimism.rs]
impl Network for Optimism {
    type TxType = OpTxType;

    type TxEnvelope = op_alloy_consensus::OpTxEnvelope;

    type UnsignedTx = op_alloy_consensus::OpTypedTransaction;

    type ReceiptEnvelope = op_alloy_consensus::OpReceiptEnvelope;

    type Header = alloy_consensus::Header;

    type TransactionRequest = op_alloy_rpc_types::OpTransactionRequest;

    type TransactionResponse = op_alloy_rpc_types::Transaction;

    type ReceiptResponse = op_alloy_rpc_types::OpTransactionReceipt;

    type HeaderResponse = alloy_rpc_types_eth::Header;

    type BlockResponse =
        alloy_rpc_types_eth::Block<Self::TransactionResponse, Self::HeaderResponse>;
}
```

```rust
let provider = ProviderBuilder::new()
    .network::<op_alloy_network::Optimism>() // [!code hl]
    .connect_http("http://localhost:8545");
```

## Customizing RPC Communication with Alloy's Layers

In the [previous guide](/guides/fillers), we covered [Alloy fillers](/rpc-providers/understanding-fillers). This time we'll discuss how to use [Alloy layers](https://alloy.rs/examples/layers/README) to customize HTTP-related aspects of RPC client communication.

### Layers 101

To better understand layers, we first have to explore the [Tower crate](https://github.com/tower-rs/tower). It's a basic building block for many popular Rust tools, including [Reqwest](https://github.com/seanmonstar/reqwest), [Hyper](https://github.com/hyperium/hyper), [Axum](https://github.com/tokio-rs/axum), and, of course, Alloy.

What all these crates have in common is that they work with HTTP request/response communication. That's where Tower comes into play. It's an opinionated framework for constructing pipelines for `Request -> Response` transformations. Tower also comes with a set of built-in layers that add functionality like rate limiting, compression, retry logic, logging, etc.

Check out [this classic blog post](https://tokio.rs/blog/2021-05-14-inventing-the-service-trait) for a more in-depth explanation of the origins of the Tower `Service` trait. To better understand `Service` and `Layer` traits, let's implement a barebones `Request/Response` processing pipeline using Tower.

#### Basic tower service and layer implementation

For the sake of simplicity, we're implementing a basic tower service that prepends a "Hello " to the incoming request message.

A custom `DelayLayer` will be added to this service using the [`ServiceBuilder`](https://docs.rs/tower/latest/tower/struct.ServiceBuilder.html).

Here's the implementation of our [`DelayLayer`](/examples/layers/delay_layer):

```rust
struct DelayLayer {
    delay: Duration,
}

impl DelayLayer {
    fn new(delay: Duration) -> Self {
        Self { delay }
    }
}

impl<S> Layer<S> for DelayLayer {
    type Service = DelayService<S>;

    fn layer(&self, service: S) -> Self::Service {
        DelayService {
            service,
            delay: self.delay,
        }
    }
}

struct DelayService<S> {
    service: S,
    delay: Duration,
}

impl<S, Request> Service<Request> for DelayService<S>
where
    S: Service<Request> + Send,
    S::Future: Send + 'static,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = BoxFuture<'static, Result<Self::Response, Self::Error>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.service.poll_ready(cx)
    }

    fn call(&mut self, req: Request) -> Self::Future {
        let delay = self.delay;
        let future = self.service.call(req);

        Box::pin(async move {
            sleep(delay).await;
            future.await
        })
    }
}
```

It's a bit verbose for its minimal functionality. Please refer to the [_inventing the service layer_ post](https://tokio.rs/blog/2021-05-14-inventing-the-service-trait) to understand the origin of this boilerplate better.

The core functionality of our layer is implemented in the `call` method. You can see that it wraps the unresolved future and delays it by calling `sleep`. This implementation is similar to how we can modify the alloy `Request/Response` cycle. It's worth noting that the `DelayLayer` is generic over the `Service` allowing composibilty/layering with other services.

Here's our `DelayLayer` being added added to a basic tower service:

:::code-group

```rust [tower_basic.rs]
#[tokio::main]
async fn main() {
    let mut service = ServiceBuilder::new()
        .layer(DelayLayer::new(Duration::from_secs(5)))
        .service(MyService);

    let response = service.call("Alice".to_string()).await;
    match response {
        Ok(msg) => println!("{}", msg),
        Err(_) => eprintln!("An error occurred!"),
    }
}
```

```rust [my_service.rs]
struct MyService;

impl Service<String> for MyService {
    type Response = String;
    type Error = ();
    type Future = Ready<Result<Self::Response, Self::Error>>;

    fn poll_ready(&mut self, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        Poll::Ready(Ok(()))
    }

    fn call(&mut self, req: String) -> Self::Future {
        ready(Ok(format!("Hello {}!", req)))
    }
}
```

:::

Running this example outputs _"Hello Alice!"_ after a 5-second delay.

Layers might sound similar to the fillers, but there's a crucial difference. Fillers can be used to modify the `TransactionRequest` object before it is submitted. Layers work within the `Request/Response` scope, allowing us to customize logic before and after sending the RPC request. If you're familiar with the Alloy predecessor Ethers.rs, you've probably noticed that it used [middleware](https://www.gakonst.com/ethers-rs/middleware/middleware.html) to achieve the same result.

### How to use layers in Alloy

Now that we've covered the basics let's see how layers fit within the Alloy stack. In this context, a `Service` is the Alloy `Provider`, and we can tweak how it sends RPC requests and handles responses.

Let's start with a simple example of reusing our `DelayLayer` for Alloy providers. This particular example does not have the best practical use case, but it shows that some generic layers can be reused regardless of the underlying `Service` `Request` type:

[ `examples/alloy_delay.rs`](/examples/layers/delay_layer)

```rust
#[tokio::main]
async fn main() -> Result<()> {
    let anvil = Anvil::new().try_spawn()?;
    let signer: PrivateKeySigner = anvil.keys()[0].clone().into();

    let client = ClientBuilder::default()
        .layer(DelayLayer::new(Duration::from_secs(1)))
        .http(anvil.endpoint().parse()?);

    let provider = ProviderBuilder::new()
        .wallet(signer)
        .connect_client(client);

    let bob = Address::from([0x42; 20]);
    let tx = TransactionRequest::default()
        .with_to(bob)
        .with_value(U256::from(1));

    let bob_balance_before = provider.get_balance(bob).await?;
    _ = provider.send_transaction(tx).await?.get_receipt().await?;
    let bob_balance_after = provider.get_balance(bob).await?;
    println!(
        "Balance before: {}\nBalance after: {}",
        bob_balance_before, bob_balance_after
    );

    Ok(())
}
```

Running this example would output:

```text
# After a 1 second delay
Balance before: 0
Balance after: 1
```

You'll notice a considerable delay before it executes. Let's add logging to better understand where it's coming from.

#### Using logging layer for Alloy provider

```rust
struct LoggingLayer;

impl<S> Layer<S> for LoggingLayer {
    type Service = LoggingService<S>;

    fn layer(&self, inner: S) -> Self::Service {
        LoggingService { inner }
    }
}

#[derive(Debug, Clone)]
struct LoggingService<S> {
    inner: S,
}

impl<S> Service<RequestPacket> for LoggingService<S>
where
    S: Service<RequestPacket, Response = ResponsePacket, Error = TransportError>,
    S::Future: Send + 'static,
    S::Response: Send + 'static + Debug,
    S::Error: Send + 'static + Debug,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, req: RequestPacket) -> Self::Future {
        println!("Request: {req:?}");

        let fut = self.inner.call(req);

        Box::pin(async move {
            let res = fut.await;
            println!("Response: {res:?}");
            res
        })
    }
}
```

You can notice that it's very similar to the `DelayLayer`. Core logic lives in the `call` method, and instead of delaying requests with `sleep`, we use `tracing::info!` calls to log them.

Here's how you can connect it to the provider:

[ `examples/alloy_logging.rs`](/examples/layers/logging_layer)

```rust
// Request/Response modifying layers should be added to the RPC-client
let client = ClientBuilder::default()
    .layer(DelayLayer::new(Duration::from_secs(1)))
    .layer(LoggingLayer)
    // Previously, on_http
    .connect_http(anvil.endpoint().parse()?);
let provider = ProviderBuilder::new()
    .wallet(signer)
    .connect_client(client);
```

![Alloy logging](/guides-images/layers/alloy_logs.png)

You can see that our simple example triggered various RPC requests: `eth_blockNumber`, `eth_getBlockByNumber`, `eth_chainId`, `eth_transactionCount`, `eth_getBalance`, and more.

Thanks to the custom layer we can fine-tune the `LoggingLayer` policy and for example only log RPC calls sending transactions:

```rust
fn call(&mut self, req: RequestPacket) -> Self::Future {
    if let RequestPacket::Single(req) = &req {
        if req.method() == "eth_sendTransaction" || req.method() == "eth_sendRawTransaction" {
            tracing::info!("Request: {req:?}");
        };
    }

    let fut = self.inner.call(req);

    Box::pin(fut)
}
```

Running this reworked example produces a much cleaner output:

![Alloy logging txs](/guides-images/layers/alloy_logs_tx.png)

You can see that layers provide powerful low-level control over how the provider handles RPC calls.

### Summary

Alloy layers combined with fillers allow for elaborate customization of transaction dispatch logic. Mastering these APIs could save you a lot of manual tweaking and enable building robust provider pipelines fine-tuned to your application requirements.

## Multicall and Multicall Batching layer

### What is Multicall?

Multicall is a smart contract and pattern that allows you to batch multiple read-only calls to the Ethereum blockchain into a single request. Instead of sending separate RPC requests, Multicall combines them into one transaction, significantly reducing network overhead and latency. This solves various problems such as reduced latency and rate-limiting, network overhead, atomic state reading & offers better UX.

### When should I use Multicall ?

- To read multiple contract states e.g. fetching balances, allowances, or prices across multiple contracts
- To reduce request count e.g. working with public RPC endpoints that have rate limits
- To ensure data consistency e.g. when you need multiple values from the same blockchain state

Note that Multicall is not suitable for write operations (transactions that change state) and sequential operations where each call depends on the result of the previous one.

### Multicall with Alloy

Alloy provides two ways in which a user can make multicalls to the [Multicall3 contract](https://www.multicall3.com/), both of which tightly integrated with the `Provider` to make usage as easy as possible:

1. Multicall Builder: The `multicall()` method gives you explicit control over which calls to batch
2. Multi-batching Layer: The batching layer automatically batches requests that are made in parallel

#### 1. Multicall Builder

Accessed via the `provider.multicall()` method works hand in hand with the bindings returned by the `sol!` macro to stack up multiple calls.

```rust
let multicall = provider
        .multicall()
        // Set the address of the Multicall3 contract. If unset it uses the default address from <https://github.com/mds1/multicall>: 0xcA11bde05977b3631167028862bE2a173976CA11
        // .address(multicall3)
        // Get the total supply of WETH on our anvil fork.
        .add(weth.totalSupply())
        // Get Alice's WETH balance.
        .add(weth.balanceOf(alice))
        // Also fetch Alice's ETH balance.
        .get_eth_balance(alice);
```

You can find the complete example [here](/examples/providers/multicall)

This approach is suitable when:

- You know exactly which calls you want to batch together
- You need to explicitly collect related data in a single request
- You need fine-grained control over the order of results
- You are working with varied contract types in a single batch

#### 2. Multicall Batching Layer

The batching layer is especially powerful because it requires no changes to your existing code and reduces the number of network requests.

However, this only works when requests are made in parallel, for example when using the
\[`tokio::join!`] macro or in multiple threads/tasks, as otherwise the requests will be sent one
by one as normal, but with an added delay.

```rust [multicall_batching.rs]
use alloy_provider::{layers::CallBatchLayer, Provider, ProviderBuilder};
use std::time::Duration;

async fn f(url: &str) -> Result<(), Box<dyn std::error::Error>> {
    // Build a provider with the default call batching configuration.
    let provider = ProviderBuilder::new().with_call_batching().connect(url).await?;

    // Build a provider with a custom call batching configuration.
    let provider = ProviderBuilder::new()
        .layer(CallBatchLayer::new().wait(Duration::from_millis(10)))
        .connect(url)
        .await?;

    // Both of these requests will be batched together and only 1 network request will be made.
    let (block_number_result, chain_id_result) =
        tokio::join!(provider.get_block_number(), provider.get_chain_id());
    let block_number = block_number_result?;
    let chain_id = chain_id_result?;
    println!("block number: {block_number}, chain id: {chain_id}");
    Ok(())
}
```

Find the complete example [here](/examples/providers/multicall_batching). This approach is suitable when:

- You want to optimize existing code without restructuring it
- You need to batch calls that are made from different parts of your codebase

## RPC Provider Abstractions

Alloy offers _Provider Wrapping_ as a design pattern that lets you extend or customize the behavior of a Provider by encapsulating it inside another object.

There are several reasons why you would want create your own RPC provider abstractions, for example to simplify complex workflows, or build more intuitive interfaces for particular use cases (like deployment, data indexing, or trading).

Let's dive into an example: Imagine you have multiple contracts that need to be deployed and monitored. Rather than repeating the same boilerplate code throughout your application, you can create specialized abstractions that wrap the Provider. Your `Deployer` struct ingests the `Provider` and the bytecode to deploy contracts and interact with them. More on this in the example snippets below.

There are two ways to ways to implement provider wrapping, both offer different trade-offs depending on your use case:

1. Using Generics (`P: Provider`): Preserves type information and enables static dispatch
2. Using Type Erasure (`DynProvider`): Simplifies types at the cost of some runtime overhead

### 1. Using generics `P: Provider`

The ideal way is by using the `P: Provider` generic on the encapsulating type. This approach Preserves full type information and static dispatch, though can lead to complex type signatures and handling generics.

This is depicted by the following [example](/examples/providers/wrapped_provider). Use generics when you need maximum performance and type safety, especially in library code.

```rust [wrapped_provider.rs]
// [!include ~/snippets/providers/examples/wrapped_provider.rs]
```

During this approach the compiler creates a unique `Deployer` struct for each Provider type you use static dispatch with slightly better runtime overhead.
Use this approach when performance is critical, type information is valuable e.g. when creating library code or working with embedded systems.
Type information is valuable: You need to know the exact Provider type for specialized behavior

### 2. Using Type Erasure `DynProvider`

Use DynProvider when you prioritize simplicity and flexibility, such as in application code where the performance difference is negligible.

[`DynProvider`](/examples/providers/dyn_provider) erases the type of a provider while maintaining its core functionality.

```rust [dyn_provider.rs]
// [!include ~/snippets/providers/examples/dyn_provider.rs]
```

With `DynProvider` we use dynamic dispatch, accept a slightly slower runtime overhead but can avoid dealing with generics.
Use this approach when you prefer simplicity over speed speed, minimise compile and binary size or want to create heterogeneous collections.

### `Provider` does not require `Arc`

You might be tempted to wrap a `Provider` in `Arc` to enable sharing and cloning:

```rust
#[derive(Clone)]
struct MyProvider<P: Provider> {
    inner: Arc<P>, // Unnecssary
}
```

This is actually unnecessary because Alloy's Providers already implement internal reference counting. Instead, simply add the `Clone` bound when needed:

```rust
struct MyProvider<P: Provider + Clone> {
    inner: P,
}
```

This eliminates common boilerplate and prevents potential performance issues from double Arc-ing.

## Signers vs Ethereum Wallet

### Signer

Signers implement the [`Signer` trait](https://github.com/alloy-rs/alloy/blob/main/crates/signer/src/signer.rs) which enables them to sign hashes, messages and typed data.

Alloy provides access to various signers out of the box such as [`PrivateKeySigner`](https://github.com/alloy-rs/alloy/blob/a3d521e18fe335f5762be03656a3470f5f6331d8/crates/signer-local/src/lib.rs#L37), [`AwsSigner`](https://github.com/alloy-rs/alloy/blob/main/crates/signer-aws/src/signer.rs), [`LedgerSigner`](https://github.com/alloy-rs/alloy/blob/main/crates/signer-ledger/src/signer.rs) etc.

These signers can directly be passed to a `Provider` using the `ProviderBuilder`. These signers are housed in the [`WalletFiller`](https://github.com/alloy-rs/alloy/blob/main/crates/provider/src/fillers/wallet.rs), which is responsible for signing transactions in the provider stack.

For example:

```rust

let signer: PrivateKeySigner = "0x...".parse()?;

let provider = ProviderBuilder::new()
    .wallet(signer)
    .connect_http("http://localhost:8545")?;

```

### `EthereumWallet`

EthereumWallet is a type that can hold multiple different signers such `PrivateKeySigner`, `AwsSigner`, `LedgerSigner` etc and also be passed to the `Provider` using the `ProviderBuilder`.

The signer that instantiates `EthereumWallet` is set as the default signer. This signer is used to sign \[`TransactionRequest`] and \[`TypedTransaction`] objects that do not specify a signer address in the `from` field.

For example:

```rust
let ledger_signer = LedgerSigner::new(HDPath::LedgerLive(0), Some(1)).await?;
let aws_signer = AwsSigner::new(client, key_id, Some(1)).await?;
let pk_signer: PrivateKeySigner = "0x...".parse()?;

let mut wallet = EthereumWallet::from(pk_signer) // pk_signer will be registered as the default signer.
    .register_signer(aws_signer)
    .register_signer(ledger_signer);

let provider = ProviderBuilder::new()
    .wallet(wallet)
    .connect_http("http://localhost:8545")?;
```

The `PrivateKeySigner` will set to the default signer if the `from` field is not specified. One can hint the `WalletFiller` which signer to use by setting its corresponding address in the `from` field of the `TransactionRequest`.

If you wish to change the default signer after instantiating `EthereumWallet`, you can do so by using the `register_default_signer` method.

```rust
// `pk_signer` will be registered as the default signer
let mut wallet = EthereumWallet::from(pk_signer)
    .register_signer(ledger_signer);

// Changes the default signer to `aws_signer`
wallet.register_default_signer(aws_signer);
```

## Build a fast MEV bot with Alloy's Primitive Types

[Alloy](https://alloy.rs) is a successor to the deprecated [ethers-rs](https://github.com/gakonst/ethers-rs). In this guide, we will describe how you can reap the benefits of its better performance with minimal codebase changes to ethers-rs project. We will also implement an atomic UniswapV2 arbitrage simulation to showcase how different parts of the Alloy stack fit together.

Read on to learn how to speed up your ethers-rs project calculations by **up to 2x faster%** with a simple type change.

### How to calculate optimal UniV2 arbitrage profit?

An atomic arbitrage between two UniswapV2 pairs is one of the more basic MEV techniques. We will use this example to discuss the performance characteristics of ethers-rs vs Alloy.

To execute an atomic arbitrage swap, you have to calculate the required input and output token amounts. UniswapV2 calculations can be done off-chain (i.e., without interacting with deployed Smart Contracts) with a relatively simple equation.

Most publicly available bots use an iterative search function to find an optimal amount of input value. However, UniswapV2 constant product formula makes it possible to calculate a profitable input amount without multiple iterations. We will borrow the implementation of this formula [from Flashbots simple-blind-arbitrage repo](https://github.com/flashbots/simple-blind-arbitrage). You can find a step-by-step explanation of how to derive the formula [in this YouTube video](https://www.youtube.com/watch?v=9EKksG-fF1k).

All the code examples for this post are available in [this repo](https://github.com/alloy-rs/examples/tree/main/examples/advanced/examples/uniswap_u256).

Let's start with implementing a struct representing a Uniswap pool and a few helper functions in Alloy:

[ `alloy_helpers.rs`](https://github.com/alloy-rs/examples/tree/main/examples/advanced/examples/uniswap_u256/helpers)

```rust
use alloy::primitives::{address, Address, U256};

pub static WETH_ADDR: Address = address!("C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");

#[derive(Debug)]
pub struct UniV2Pair {
    pub address: Address,
    pub token0: Address,
    pub token1: Address,
    pub reserve0: U256,
    pub reserve1: U256,
}

// https://etherscan.io/address/0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11
pub fn get_uniswap_pair() -> UniV2Pair {
    UniV2Pair {
        address: address!("A478c2975Ab1Ea89e8196811F51A7B7Ade33eB11"),
        token0: DAI_ADDR,
        token1: WETH_ADDR,
        reserve0: uint!(6227630995751221000110015_U256),
        reserve1: uint!(2634810784674972449382_U256),
    }
}

pub fn get_amount_out(reserve_in: U256, reserve_out: U256, amount_in: U256) -> U256 {
    let amount_in_with_fee = amount_in * U256::from(997_u64); // uniswap fee 0.3%
    let numerator = amount_in_with_fee * reserve_out;
    let denominator = reserve_in * U256::from(1000_u64) + amount_in_with_fee;
    numerator / denominator
}

pub fn get_amount_in(
    reserves00: U256,
    reserves01: U256,
    is_weth0: bool,
    reserves10: U256,
    reserves11: U256,
) -> U256 {
    let numerator = get_numerator(reserves00, reserves01, is_weth0, reserves10, reserves11);

    let denominator = get_denominator(reserves00, reserves01, is_weth0, reserves10, reserves11);

    numerator * U256::from(1000) / denominator
}

//...
```

_Implemenation details are omitted for brevity._

`UniV2Pair` struct represents pools that we will be working with. `get_amount_out` is a standard calculation for determining how much of a given ERC20 you can buy from the pool after paying the protocol fees. `get_amount_in` is the profitable input amount formula that we borrow from Flashbots repo.

It's worth noting that we use handy `address!` and `uint!` macros to generate the compile time constant `Address` and `U256` types.

#### Iterative UniswapV2 profit algorithm

Let's consider the following example: your MEV bot wants to score an arbitrage between UniswapV2 and Sushiswap WETH/DAI pools. Here's how you can calculate the arbitrage in a standard way:

- calculate how much DAI you can buy from the UniswapV2 pool for a sample WETH input amount
- calculate how much WETH you can buy back from Sushi pool for the previously calculated DAI amount
- repeat the process for multiple values to determine which yields the best profit

The above algorithm is iterative. There are ways to minimize the number of iterations, but this topic is outside the scope of this tutorial.

#### Arbitrage profit formula

Instead, we can use the `get_amount_in` method, which does more number crunching than `get_amount_out` but produces a profitable input amount in a single iteration Let's see it in action.

In the following example, we use a mocked pool reserve value for [UniswapV2](https://etherscan.io/address/0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11) and [SushiSwap](https://etherscan.io/address/0xC3D03e4F041Fd4cD388c549Ee2A29a9E5075882f) WETH/DAI Mainnet pools to simulate a profitable arbitrage opportunity.

[ `examples/alloy_profit.rs`](https://github.com/alloy-rs/examples/blob/main/examples/advanced/examples/uniswap_u256/alloy_profit.rs)

```rust
fn main() -> Result<()> {
    let uniswap_pair = get_uniswap_pair();
    let sushi_pair = get_sushi_pair();

    let amount_in = get_amount_in(
        uniswap_pair.reserve0,
        uniswap_pair.reserve1,
        false,
        sushi_pair.reserve0,
        sushi_pair.reserve1,
    );

    let dai_amount_out = get_amount_out(uniswap_pair.reserve1, uniswap_pair.reserve0, amount_in);

    let weth_amount_out = get_amount_out(sushi_pair.reserve0, sushi_pair.reserve1, dai_amount_out);

    if weth_amount_out < amount_in {
        println!("No profit detected");
        return Ok(());
    }

    let profit = weth_amount_out - amount_in;
    println!("Alloy U256");
    println!("WETH amount in {}", display_token(amount_in));
    println!("WETH profit: {}", display_token(profit));

    Ok(())
}
```

You can run it like that:

```
cargo run --package examples-advanced --bin alloy_profit
```

It should produce:

```
Alloy U256
WETH amount in 2.166958497387277956
WETH profit: 0.006142751241793559
```

We've calculated a profitable Arbitrage for our mocked Uniswap pool reserves!

### "ethers-rs good, Alloy better!"

If you compare the implementation of [`alloy_helpers.rs`](https://github.com/alloy-rs/examples/blob/main/examples/advanced/examples/uniswap_u256/helpers/alloy.rs) with [`ethers_helpers.rs`](https://github.com/alloy-rs/examples/blob/main/examples/advanced/examples/uniswap_u256/helpers/ethers.rs), you will notice that they are almost identical. Rewriting your project calculations from ethers-rs to Alloy U256 should be possible with a very reasonable development effort. But is it worth it?

It's high time to compare the performance of legacy ethers-rs U256 with the brand-new (based on the [ruint crate](https://crates.io/crates/ruint)) Alloy integer type. We will use the [criterion.rs crate](https://github.com/bheisler/criterion.rs). It generates reliable benchmarks by executing millions of iterations and turning off some compiler optimizations.

You can find the source of the benchmark in [`benches/u256.rs`](https://github.com/alloy-rs/examples/blob/main/benches/benches/u256.rs) and execute it by running `cargo bench U256`

We compare the performance of both `get_amount_in` and `get_amount_out`. Benchmark indicates **\~1.5x-2x improvement** when using Alloy types!

![U256 performance comparison](/guides-images/alloy_u256/u256_bench_chart.png)

On the above charts generated with criterion.rs you can see that Alloy is consistently faster for both methods and has less variation in execution time.

This means that you can significantly improve the performance of your ethers-rs project by switching to the new U256 type.

Here's how you can convert between the two types:

[ `alloy_helpers.rs`](https://github.com/alloy-rs/examples/blob/main/examples/advanced/examples/uniswap_u256/helpers/alloy.rs)

```rust
use alloy::primitives::U256;
use ethers::types::U256 as EthersU256;

pub trait ToEthers {
    type To;
    fn to_ethers(self) -> Self::To;
}

impl ToEthers for U256 {
    type To = EthersU256;

    #[inline(always)]
    fn to_ethers(self) -> Self::To {
        EthersU256(self.into_limbs())
    }
}
```

[ `ethers_helpers.rs`](https://github.com/alloy-rs/examples/blob/main/examples/advanced/examples/uniswap_u256/helpers/ethers.rs)

```rust
use ethers::types::U256;
use alloy::primitives::U256 as AlloyU256;

pub trait ToAlloy {
    type To;
    fn to_alloy(self) -> Self::To;
}

impl ToAlloy for U256 {
    type To = AlloyU256;

    #[inline(always)]
    fn to_alloy(self) -> Self::To {
        AlloyU256::from_limbs(self.0)
    }
}
```

This trait can easily be applied to any ethers-rs and Alloy types. You can check out [these conversion docs](/migrating-from-ethers/conversions) for details on how to do it.

### How to simulate MEV arbitrage with Alloy?

Let's confirm that our calculations are correct by simulating the arbitrage swap. We will use a new Alloy stack to fork Anvil and mock the profit opportunity.

Mocking the forked blockchain storage slots is an insanely useful technique. It allows to recreate any past blockchain state without an archive node. Geth full node by default prunes any state older than the last 128 blocks, i.e., only \~25 minutes. Using a forked blockchain saves a lot of effort in seeding the contract bytecodes. You can cherry-pick the exact EVM storage slots and modify them to match your desired simulation state. Anvil will implicitly fetch all the non-modified state from its origin blockchain.

Here are the helper methods that we'll use:

[ `alloy_helpers.rs`](https://github.com/alloy-rs/examples/blob/main/examples/advanced/examples/uniswap_u256/helpers/alloy.rs)

```rust
pub async fn set_hash_storage_slot<P: Provider>(
    anvil_provider: &P,
    address: Address,
    hash_slot: U256,
    hash_key: Address,
    value: U256,
) -> Result<()> {
    let hashed_slot = keccak256((hash_key, hash_slot).abi_encode());

    anvil_provider
        .anvil_set_storage_at(address, hashed_slot.into(), value.into())
        .await?;

    Ok(())
}
```

We will leverage a custom Anvil RPC method, `anvil_setStorageAt`, to mock EVM storage values. `set_hash_storage_slot` method is used to overwrite values inside mappings. It implements a Solidity convention where the storage slot of a mapping value is `keccak256` of the storage slot of the mapping and the key.

And here's our simulation:

[ `alloy_simulation.rs`](https://github.com/alloy-rs/examples/blob/main/examples/advanced/examples/uniswap_u256/alloy_simulation.rs)

```rust
// imports omitted for brevity

sol! {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

sol!(
    #[sol(rpc)]
    contract IERC20 {
        function balanceOf(address target) returns (uint256);
    }
);

sol!(
    #[sol(rpc)]
    FlashBotsMultiCall,
    "artifacts/FlashBotsMultiCall.json"
);

#[tokio::main]
async fn main() -> Result<()> {
    let uniswap_pair = get_uniswap_pair();
    let sushi_pair = get_sushi_pair();

    let wallet_address = address!("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
    let provider = ProviderBuilder::new()
        .connect_anvil_with_wallet_and_config(|a| a.fork("https://reth-ethereum.ithaca.xyz/rpc"))?;

    let executor = FlashBotsMultiCall::deploy(provider.clone(), wallet_address).await?;
    let iweth = IERC20::new(WETH_ADDR, provider.clone());

    // Mock WETH balance for executor contract
    set_hash_storage_slot(
        &anvil_provider,
        WETH_ADDR,
        U256::from(3),
        *executor.address(),
        parse_units("5.0", "ether")?.into(),
    )
    .await?;

    // Mock reserves for Uniswap pair
    anvil_provider
        .anvil_set_storage_at(
            uniswap_pair.address,
            U256::from(8), // getReserves slot
            B256::from_slice(&hex!(
                "665c6fcf00000000008ed55850d607f83a660000000526c08d812099d2577fbf"
            )),
        )
        .await?;

    // Mock WETH balance for Uniswap pair
    set_hash_storage_slot(
        &anvil_provider,
        WETH_ADDR,
        U256::from(3),
        uniswap_pair.address,
        uniswap_pair.reserve1,
    )
    .await?;

    // Mock DAI balance for Uniswap pair
    set_hash_storage_slot(
        &anvil_provider,
        DAI_ADDR,
        U256::from(2),
        uniswap_pair.address,
        uniswap_pair.reserve0,
    )
    .await?;

    // Mock reserves for Sushi pair
    anvil_provider
        .anvil_set_storage_at(
            sushi_pair.address,
            U256::from(8), // getReserves slot
            B256::from_slice(&hex!(
                "665c6fcf00000000006407e2ec8d4f09436700000003919bf56d886af022979d"
            )),
        )
        .await?;

    // Mock WETH balance for Sushi pair
    set_hash_storage_slot(
        &anvil_provider,
        WETH_ADDR,
        U256::from(3),
        sushi_pair.address,
        sushi_pair.reserve1,
    )
    .await?;

    // Mock DAI balance for Sushi pair
    set_hash_storage_slot(
        &anvil_provider,
        DAI_ADDR,
        U256::from(2),
        sushi_pair.address,
        sushi_pair.reserve0,
    )
    .await?;

    let balance_of = iweth.balanceOf(*executor.address()).call().await?;
    println!("Before - WETH balance of executor {:?}", balance_of);

    let weth_amount_in = get_amount_in(
        uniswap_pair.reserve0,
        uniswap_pair.reserve1,
        false,
        sushi_pair.reserve0,
        sushi_pair.reserve1,
    );

    let dai_amount_out =
        get_amount_out(uniswap_pair.reserve1, uniswap_pair.reserve0, weth_amount_in);

    let weth_amount_out = get_amount_out(sushi_pair.reserve0, sushi_pair.reserve1, dai_amount_out);

    let swap1 = swapCall {
        amount0Out: dai_amount_out,
        amount1Out: U256::from(0),
        to: sushi_pair.address,
        data: Bytes::new(),
    }
    .abi_encode();

    let swap2 = swapCall {
        amount0Out: U256::from(0),
        amount1Out: weth_amount_out,
        to: *executor.address(),
        data: Bytes::new(),
    }
    .abi_encode();

    let arb_calldata = FlashBotsMultiCall::uniswapWethCall {
        _wethAmountToFirstMarket: weth_amount_in,
        _ethAmountToCoinbase: U256::from(0),
        _targets: vec![uniswap_pair.address, sushi_pair.address],
        _payloads: vec![Bytes::from(swap1), Bytes::from(swap2)],
    }
    .abi_encode();

    let arb_tx = TransactionRequest::default()
        .with_to(*executor.address())
        .with_input(arb_calldata);

    let pending = provider.send_transaction(arb_tx).await?;
    pending.get_receipt().await?;

    let balance_of = iweth.balanceOf(*executor.address()).call().await?;
    println!("After - WETH balance of executor {:?}", balance_of);

    Ok(())
}
```

It uses a `FlashBotsMultiCall` contract from the [Flashbots simple-arbitrage repo](https://github.com/flashbots/simple-arbitrage) to atomically execute a swap between Uniswap and Sushiswap WETH/DAI pools.

You can execute this simulation by running the following command on the examples repo:

```
cargo run --package examples-advanced --bin alloy_simulation
```

It should produce:

```
Before - WETH balance of executor 5000000000000000000
After - WETH balance of executor 5006142751241793559
```

We've managed to simulate exactly the same profit of \~`0.00614` ETH that we've calculated before.

### Summary

Rewriting your ethers-rs project could be a significant time investment. But Alloy is here to stay. Starting a migration from the calculations layer will let you reap performance benefits with minimal development effort.

## Performant Static and Dynamic ABI Encoding

In this guide, we will discuss new ways to work with blockchain ABIs introduced in [Alloy](https://alloy.rs). We will showcase basic smart contract interactions and how they compare to [ethers-rs](https://github.com/gakonst/ethers-rs). We will also discuss more advanced ways to interact with runtime-constructed dynamic ABIs.

### Alloy ABI 101

Below we have [implemented a simulation](/examples/contracts/simulation_uni_v2) of an arbitrage swap between two UniswapV2 pairs. We've used the following ABI definitions:

```rust
sol! {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

sol!(
    #[sol(rpc)]
    contract IERC20 {
        function balanceOf(address target) returns (uint256);
    }
);

sol!(
    #[sol(rpc)]
    FlashBotsMultiCall,
    "artifacts/FlashBotsMultiCall.json"
);
```

You can find the complete example and ABI artifacts [here]().

Let's look into these examples in more detail.

#### Static calldata encoding

```rust
sol! {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}
```

Alloy introduces the `sol!` macro that allows to embed compile-time-safe Solidity code directly in your Rust project. In the example, we use it to encode calldata needed for executing `swap` methods for our arbitrage. Here's how you can encode calldata:

```rust
// swapCall is the struct generated by the sol! macro
let swap_calldata = swapCall {
    amount0Out: U256::from(1000000000000000000_u128)
    amount1Out: U256::ZERO,
    to: sushi_pair.address,
    data: Bytes::new(),
}
.abi_encode();
```

As a result, you'll get a `Vec<u8>` type that you can assign to an `input` field of a transaction.

It's worth noting that `sol!` macro works with any semantically correct Solidity snippets. Here's how you can generate a calldata for a method that accepts a struct. For example:

```rust
sol! {
    // Define your custom solidity struct
    struct MyStruct {
        uint256 id;
        string name;
        bool isActive;
    }

    // And a function that accepts it as an argument
    function setStruct(MyStruct memory _myStruct) external;
}

let my_struct = MyStruct {
    id: U256::from(1),
    name: "Hello".to_string(),
    isActive: true,
};

// Encode the calldata for the `setStruct` fn call
let calldata = setStructCall {
    _myStruct: my_struct.clone(),
}.abi_encode();
```

We've just imported a Solidity struct straight into the Rust code. You can use [`cast interface`](https://book.getfoundry.sh/reference/cast/cast-interface) CLI to generate Solidity snippets for any verified contract:

:::code-group

```bash [cast]
cast interface 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 --etherscan-api-key API_KEY
```

```solidity [interace]
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface WETH9 {
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    fallback() external payable;

    function allowance(address, address) external view returns (uint256);
    function approve(address guy, uint256 wad) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function deposit() external payable;
    // ...
}
```

:::

#### Performance benchmark ethers-rs vs. Alloy

On top of a nicer API, Alloy also comes with significantly better performance benefits.

We've used the [criterion.rs crate](https://github.com/bheisler/criterion.rs) to produce reliable benchmarks for comparing encoding of static calldata for a method call. The reproducible benchmarks can be [found here](https://github.com/alloy-rs/examples/blob/main/benches/BENCHMARKS.md).

| Ethers   | Alloy    | Speedup   |
| -------- | -------- | --------- |
| 997.39ns | 92.69 ns | 10.76x 🚀 |

Alloy is **\~10x faster** than ethers-rs! Here's a chart to visualize the difference:

![Static ABI encoding performance comparison](/guides-images/alloy_abi/static_encoding_bench.png)

### Interacting with on-chain contracts

Using `#[sol(rpc)]` marco, you can easily generate an interface to an on-chain contract. Let's see it in action:

```rust
sol!(
    #[sol(rpc)]
    contract IERC20 {
        function balanceOf(address target) returns (uint256);
        function name() returns (string);
    }
);

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let provider = ProviderBuilder::new().connect("https://reth-ethereum.ithaca.xyz/rpc").await?;
    let iweth = IERC20::new(address!("C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"), provider.clone());
    let name = weth.name().call().await?;
    println!("Name: {}", name); // => Wrapped Ether
}
```

Alternatively, instead of defining the interface methods in Solidity, you can use the standard JSON ABI file generated using `cast interface` with `--json` flag:

```bash
cast interface 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 --json --etherscan-api-key API_KEY > abi/weth.json
```

Later you can use it like that:

```rust
sol!(
    IERC20,
    "abi/WETH.json"
);
```

#### Deploying Smart Contract with `sol!` macro

To deploy a smart contract, you must use its _"build artifact file"_. It's a JSON file you can generate by running the [`forge build` command](https://book.getfoundry.sh/reference/forge/forge-build):

```shell
forge build contracts/FlashBotsMultiCall.sol
```

It produces a file containing contract's ABI, bytecode, deployed bytecode, and other metadata.

Alternatively, you can use a recently added [`cast artifact` method](https://book.getfoundry.sh/reference/cli/cast/artifact):

```bash
cast artifact 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 --etherscan-api-key $API_KEY --rpc-url $ETH_RPC_URL -o weth.json
```

It generates a minimal artifact file containing contract's bytecode and ABI based on Etherscan and RPC data. Contrary to `forge build`, you don't have to compile contracts locally to use it.

You can later use an artifact file with the `sol!` macro like this:

```rust
sol!(
    #[sol(rpc)]
    FlashBotsMultiCall,
    "artifacts/FlashBotsMultiCall.json"
);

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let anvil = Anvil::new().fork("https://reth-ethereum.ithaca.xyz/rpc").try_spawn()?;
    let wallet_address = anvil.addresses()[0];
    let provider = ProviderBuilder::new().connect(anvil.endpoint()).await?;
    let executor = FlashBotsMultiCall::deploy(provider.clone(), wallet_address).await?;

    println!("Executor deployed at: {}", *executor.address());
}
```

It uses Anvil to fork the mainnet and deploy smart contract to the local network.

You can also use [`cast constructor-args`](https://book.getfoundry.sh/reference/cli/cast/constructor-args) command to check what were the original deployment arguments:

```bash
cast constructor-args 0x6982508145454ce325ddbe47a25d4ec3d2311933 --etherscan-api-key $API_KEY --rpc-url $ETH_RPC_URL

# 0x00000000000000000000000000000000000014bddab3e51a57cff87a50000000 → Uint(420690000000000000000000000000000, 256)
```

We've only discussed a few common ways to use ABI and `sol!` macro in Alloy. Make sure to [check the official docs](https://docs.rs/alloy-sol-macro/latest/alloy_sol_macro/macro.sol.html) for more examples.

### How to use dynamic ABI encoding?

All the previous examples were using so-called static ABIs, i.e., with format known at the compile time. However, there are use cases where you'll have to work with ABI formats interpreted in the runtime.

One practical example is a backend for a web3 wallet. It's not possible to include all the possible ABIs in the binary. So you'll have to work with JSON ABI files downloaded from the Etherscan API based on a user-provided address.

Let's assume that we want to generate a calldata for a [UniswapV2 WETH/DAI pair](https://etherscan.io/address/0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11) `swap` method with arguments provided by a user:

```rust
// Solidity: function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
use alloy::{
    dyn_abi::{DynSolValue, JsonAbiExt},
    hex,
    json_abi::Function,
    primitives::{uint, Address, Bytes, U256},
};
use std::error::Error;

fn main() -> Result<(), Box<dyn Error>> {
    // Setup the dynamic inputs for the `swap` function
    let input = vec![
        DynSolValue::Uint(uint!(100000000000000000_U256), 256),
        DynSolValue::Uint(U256::ZERO, 256),
        DynSolValue::Address(Address::from([0x42; 20])),
        DynSolValue::Bytes(Bytes::new().into()),
    ];

    // Parse the function signature
    let func = Function::parse(
        "function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external",
    )?;

    // Dynamically encode the function call
    let input = func.abi_encode_input(&input)?;
    println!("Calldata: {}", hex::encode(&input));

    Ok(())
}
```

In the above example, we used the `DynSolValue` enum type to setup the input values for the `swap` function. We then parsed the funtion signature into the `Function` type which gives us access to the `abi_encode_input` method. This method accepts a vector of `DynSolValue` allowing us to dynamically encode the function calldata.

This approach offers flexibility for interacting with virtually any ABIs that can be defined in a runtime.

#### Performance benchmark for dynamic vs static ABI encoding

Let's now compare the performance of generating `swap` method calldata for the same arguments with with Alloy and ethers-rs. You can find the reproducible [criterion benchmark here](https://github.com/alloy-rs/examples/blob/main/benches/BENCHMARKS.md).

| Ethers | Alloy  | Speedup  |
| ------ | ------ | -------- |
| 2.12μs | 1.79μs | 1.19x 🚀 |

Here's a chart to visualize the difference:

![Dynamic ABI encoding performance comparison](/guides-images/alloy_abi/dyn_encoding_bench.png)

This time difference is not as dramatic as in static encoding. But Alloy is still \~20% faster than ethers-rs.

### Summary

We've discussed common ways to interact with smart contracts ABI using the new Alloy stack.

## Getting Started \[The simplest, fastest Rust toolkit to interact with any EVM chain]

### Overview

Alloy is a high-performance Rust toolkit for Ethereum and EVM-based blockchains providing developers with:

- **High Performance**: Optimized primitives with up to 60% faster U256 operations and 10x faster ABI encoding
- **Developer Experience**: Intuitive API for interacting with Smart contracts via the `sol!` macro
- **Chain-Agnostic Type System**: Multi-chain support without feature flags or type casting
- **Extensibility**: Customizable provider architecture with layers and fillers

### Installation

Install alloy to any cargo project using the command line. See [Installation](/introduction/installation#features) for more details on the various features flags.

```bash [cargo]
cargo add alloy
```

### Quick Start

#### 1. Sending Transactions

This example shows how to send 100 ETH using the [`TransactionBuilder`](/transactions/using-the-transaction-builder) on a local anvil node

```rust
use alloy::{
    network::TransactionBuilder,
    primitives::{
        address,
        utils::{format_ether, Unit},
        U256,
    },
    providers::{Provider, ProviderBuilder},
    rpc::types::TransactionRequest,
    signers::local::PrivateKeySigner,
};
use std::error::Error;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Initialize a signer with a private key
    let signer: PrivateKeySigner =
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80".parse()?;

    // Instantiate a provider with the signer and a local anvil node
    let provider = ProviderBuilder::new() // [!code focus]
        .wallet(signer) // [!code focus]
        .connect("http://127.0.0.1:8545") // [!code focus]
        .await?;

    // Prepare a transaction request to send 100 ETH to Alice
    let alice = address!("0x70997970C51812dc3A010C7d01b50e0d17dc79C8"); // [!code focus]
    let value = Unit::ETHER.wei().saturating_mul(U256::from(100)); // [!code focus]
    let tx = TransactionRequest::default() // [!code focus]
        .with_to(alice) // [!code focus]
        .with_value(value); // [!code focus]

    // Send the transaction and wait for the broadcast
    let pending_tx = provider.send_transaction(tx).await?; // [!code focus]
    println!("Pending transaction... {}", pending_tx.tx_hash());

    // Wait for the transaction to be included and get the receipt
    let receipt = pending_tx.get_receipt().await?; // [!code focus]
    println!(
        "Transaction included in block {}",
        receipt.block_number.expect("Failed to get block number")
    );

    println!("Transferred {:.5} ETH to {alice}", format_ether(value));

    Ok(())
}
```

#### 2. Interacting with Smart Contracts

Alloy's `sol!` macro makes working with smart contracts intuitive by letting you write Solidity directly in Rust:

```rust
use alloy::{
    primitives::{
        address,
        utils::{format_ether, Unit},
        U256,
    },
    providers::ProviderBuilder,
    signers::local::PrivateKeySigner,
    sol,
};
use std::error::Error;

// Generate bindings for the WETH9 contract
sol! { // [!code focus]
    #[sol(rpc)] // [!code focus]
    contract WETH9 { // [!code focus]
        function deposit() public payable; // [!code focus]
        function balanceOf(address) public view returns (uint256); // [!code focus]
        function withdraw(uint amount) public; // [!code focus]
    } // [!code focus]
} // [!code focus]

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Initialize a signer with a private key
    let signer: PrivateKeySigner =
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80".parse()?;

    // Instantiate a provider with the signer
    let provider = ProviderBuilder::new() // [!code focus]
        .wallet(signer) // [!code focus]
        .connect_anvil_with_config(|a| a.fork("https://reth-ethereum.ithaca.xyz/rpc"));

    // Setup WETH contract instance
    let weth_address = address!("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2");
    let weth = WETH9::new(weth_address, provider.clone()); // [!code focus]

    // Read initial balance
    let from_address = signer.address();
    let initial_balance = weth.balanceOf(from_address).call().await?; // [!code focus]
    println!("Initial WETH balance: {} WETH", format_ether(initial_balance));

    // Write: Deposit ETH to get WETH
    let deposit_amount = Unit::ETHER.wei().saturating_mul(U256::from(10));
    let deposit_tx = weth.deposit().value(deposit_amount).send().await?; // [!code focus]
    let deposit_receipt = deposit_tx.get_receipt().await?; // [!code focus]
    println!(
        "Deposited ETH in block {}",
        deposit_receipt.block_number.expect("Failed to get block number")
    );

    // Read: Check updated balance after deposit
    let new_balance = weth.balanceOf(from_address).call().await?;
    println!("New WETH balance: {} WETH", format_ether(new_balance));

    // Write: Withdraw some WETH back to ETH
    let withdraw_amount = Unit::ETHER.wei().saturating_mul(U256::from(5));
    let withdraw_tx = weth.withdraw(withdraw_amount).send().await?; // [!code focus]
    let withdraw_receipt = withdraw_tx.get_receipt().await?; // [!code focus]
    println!(
        "Withdrew ETH in block {}",
        withdraw_receipt.block_number.expect("Failed to get block number")
    );

    // Read: Final balance check
    let final_balance = weth.balanceOf(from_address).call().await?; // [!code focus]
    println!("Final WETH balance: {} WETH", format_ether(final_balance));

    Ok(())
}
```

#### 3. Monitoring Blockchain Activity

This example shows how to monitor blocks and track the [WETH](https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2) balance of a [Uniswap V3 WETH-USDC](https://etherscan.io/address/0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8) contract in real-time:

:::code-group

```rust [subscribe_blocks.rs]
use alloy::{
    primitives::{address, utils::format_ether},
    providers::{Provider, ProviderBuilder, WsConnect},
    sol,
};
use futures_util::StreamExt;

sol! { // [!code focus]
    #[sol(rpc)] // [!code focus]
    contract WETH { // [!code focus]
        function balanceOf(address) external view returns (uint256); // [!code focus]
    } // [!code focus]
} // [!code focus]

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Connect to an Ethereum node via WebSocket
    let ws = WsConnect::new("wss://reth-ethereum.ithaca.xyz/ws"); // [!code focus]
    let provider = ProviderBuilder::new().connect_ws(ws).await?; // [!code focus]

    // Uniswap V3 WETH-USDC Pool address
    let uniswap_pool = address!("0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8"); // [!code focus]

    // Setup the WETH contract instance
    let weth_addr = address!("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
    let weth = WETH::new(weth_addr, &provider); // [!code focus]

    // Subscribe to new blocks
    let mut block_stream = provider.subscribe_blocks().await?.into_stream(); // [!code focus]
    println!("🔄 Monitoring for new blocks...");

    // Process each new block as it arrives
    while let Some(block) = block_stream.next().await { // [!code focus]
        println!("🧱 Block #{}: {}", block.number, block.hash);
        // Get contract balance at this block
        let balance = weth.balanceOf(uniswap_pool).block(block.number.into()).call().await?; // [!code focus]
        // Format the balance in ETH
        println!("💰 Uniswap V3 WETH-USDC pool balance: {} WETH", format_ether(balance));
    }

    Ok(())
}
```

```sh [output]
🔄 Monitoring for new blocks...
🧱 Block #22445374: 0x8a75355b6efd4890789f60d1d7cb7b6c32c1ce9b0651db779c145217346d2219
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
🧱 Block #22445375: 0xbb6265e4d4e81adfa73afd759d65804756fb83c5a72065b50343f7b10e1dfc47
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
🧱 Block #22445376: 0xb82d720ea7e4b7019e8573d5a01865bbcecb7b8aae3a03d4dae58af1dc7ec026
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
🧱 Block #22445377: 0x7d21a4f3dd376888df8a1ead3c7f0a9c9f7107b0a627795ec2584eeb92f13ce7
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
🧱 Block #22445378: 0xd552c7595c9b2e77b1a9def6d818376ab6eac4c10dfc9d610a91b23894b54fa7
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
🧱 Block #22445379: 0x89190317a8181eedecdddd4551bc9db0267750e659d78aca53f293c774b343b6
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
🧱 Block #22445380: 0xb68a9c344233b598e43c81b14691ff73453d8ad39491a1a0120bed12d8086d11
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
🧱 Block #22445381: 0x547b15a475d5e5316ddac707c37b5275568872531ca17d3022c9130b37fe0b21
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
🧱 Block #22445382: 0xdd3dcf55908e6ae7cc33949952c9383afc91cf7827d5ada715baaf1a018ce050
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
🧱 Block #22445383: 0x4d3a5565b18b896fea580ce94d009b11a8f076c800a3a738b66de16a91d4cd3c
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
🧱 Block #22445384: 0xc29957a5d4d981dfb02416e7bec45546678914b3e9660fcb7635d0a679bce635
💰 Uniswap V3 ETH-USDC Pool balance: 7496.034522333161564023 ETH
```

:::

### Crate Features

Alloy can be consumed in multiple ways with numerous combinations of features for different use cases.

#### Meta crate

The [alloy](https://crates.io/crates/alloy) meta crate is useful when you want to quickly get started without dealing with multiple installations or features.

It comes with the following features as default:

```toml [Cargo.toml]
default = ["std", "reqwest", "alloy-core/default", "essentials"]

# std
std = [
    "alloy-core/std",
    "alloy-eips?/std",
    "alloy-genesis?/std",
    "alloy-serde?/std",
    "alloy-consensus?/std",
]
# enable basic network interactions out of the box.
essentials = ["contract", "provider-http", "rpc-types", "signer-local"]
```

Find the full feature list [here](https://github.com/alloy-rs/alloy/blob/main/crates/alloy/Cargo.toml).

#### Individual crates

Alloy is a collection of modular crates that can be used independently.

Meta-crates can lead to dependencies bloat increasing compile-time. For large projects where compile time can be an issue, we recommend using crates independently as in when required.

```toml [Cargo.toml]
[dependencies]
alloy-primitives = { version = "1.0", default-features = false, features = ["rand", "serde", "map-foldhash"] }
alloy-provider = { version = "0.15", default-features = false, features = ["ipc"] }
# ..snip..
```

This allows you to have granular control over the dependencies and features you use in your project.

Find the full list of the crates [here](/introduction/installation#crates).

#### `no_std` crates

Most of the crates in Alloy are not `no_std` as they are primarily network-focused. Having said that we do support `no_std` implementation for crucial crates such as:

1. [alloy-eips](https://crates.io/crates/alloy-eips): Consists of Ethereum's current and future EIP types and spec implementations.

2. [alloy-genesis](https://crates.io/crates/alloy-genesis): The Ethereum genesis file definitions.

3. [alloy-serde](https://crates.io/crates/alloy-serde): Serialization and deserialization of helpers for alloy.

4. [alloy-consensus](https://crates.io/crates/alloy-consensus): The Ethereum consensus interface. It contains constants, types, and functions for implementing Ethereum EL consensus and communication. This includes headers, blocks, transactions, EIP-2718 envelopes, EIP-2930, EIP-4844, and more.

### Guides

Check out our Guides to see more practical use cases, including:

- [Building MEV bots with Alloy primitives](/guides/speed-up-using-u256)
- [Seamless contract interaction with the sol! macro](/guides/static-dynamic-abi-in-alloy)
- [Creating custom transaction fillers for setting priority fees](/guides/fillers)
- [Using multicall for aggregating RPC requests](/guides/multicall)

### Installation

[Alloy](https://github.com/alloy-rs/alloy) consists of a number of crates that provide a range of functionality essential for interfacing with any Ethereum-based blockchain.

The easiest way to get started is to add the `alloy` crate from the command-line using Cargo:

```sh
cargo add alloy
```

Alternatively, you can add the following to your `Cargo.toml` file:

```toml
alloy = "1.0"
```

For a more fine-grained control over the features you wish to include, you can add the individual crates to your `Cargo.toml` file, or use the `alloy` crate with the features you need.

After `alloy` is added as a dependency you can now import `alloy` as follows:

```rust
use alloy::{
    network::EthereumWallet,
    node_bindings::Anvil,
    primitives::U256,
    providers::ProviderBuilder,
    signers::local::PrivateKeySigner,
    sol,
};
```

#### Features

The [`alloy`](https://github.com/alloy-rs/alloy/tree/main/crates/alloy) meta-crate defines a number of [feature flags](https://github.com/alloy-rs/alloy/blob/main/crates/alloy/Cargo.toml):

Default

- `std`
- `reqwest`
- `alloy-core/default`
- `essentials`

Essentials

- `essentials`:
  - `contract`
  - `provider-http`
  - `rpc-types`
  - `signer-local`

Full, a set of the most commonly used flags to get started with `alloy`.

- `full`:
  - `consensus`
  - `eips`
  - `essentials`
  - `k256`
  - `kzg`
  - `network`
  - `provider-ws`
  - `provider-ipc`
  - `provider-trace-api`
  - `provider-txpool-api`
  - `provider-debug-api`
  - `provider-anvil-api`
  - `pubsub`

By default `alloy` uses [`reqwest`](https://crates.io/crates/reqwest) as HTTP client. Alternatively one can switch to [`hyper`](https://crates.io/crates/hyper).
The `reqwest` and `hyper` feature flags are mutually exclusive.

A complete list of available features can be found on [docs.rs](https://docs.rs/crate/alloy/latest/features) or in the [`alloy` crate's `Cargo.toml`](https://github.com/alloy-rs/alloy/blob/main/crates/alloy/Cargo.toml).

The feature flags largely correspond with and enable features from the following individual crates.

#### Crates

`alloy` consists out of the following crates:

- [alloy](https://github.com/alloy-rs/alloy/tree/main/crates/alloy) - Meta-crate for the entire project, including [`alloy-core`](https://docs.rs/alloy-core)
- [alloy-consensus](https://github.com/alloy-rs/alloy/tree/main/crates/consensus) - Ethereum consensus interface
- [alloy-contract](https://github.com/alloy-rs/alloy/tree/main/crates/contract) - Interact with on-chain contracts
- [alloy-eips](https://github.com/alloy-rs/alloy/tree/main/crates/eips) - Ethereum Improvement Proposal (EIP) implementations
- [alloy-genesis](https://github.com/alloy-rs/alloy/tree/main/crates/genesis) - Ethereum genesis file definitions
- [alloy-json-rpc](https://github.com/alloy-rs/alloy/tree/main/crates/json-rpc) - Core data types for JSON-RPC 2.0 clients
- [alloy-network](https://github.com/alloy-rs/alloy/tree/main/crates/network) - Network abstraction for RPC types
  - [alloy-network-primitives](https://github.com/alloy-rs/alloy/tree/main/crates/network-primitives) - Primitive types for the network abstraction
- [alloy-node-bindings](https://github.com/alloy-rs/alloy/tree/main/crates/node-bindings) - Ethereum execution-layer client bindings
- [alloy-provider](https://github.com/alloy-rs/alloy/tree/main/crates/provider) - Interface with an Ethereum blockchain
- [alloy-pubsub](https://github.com/alloy-rs/alloy/tree/main/crates/pubsub) - Ethereum JSON-RPC [publish-subscribe](https://en.wikipedia.org/wiki/Publish%E2%80%93subscribe_pattern) tower service and type definitions
- [alloy-rpc-client](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-client) - Low-level Ethereum JSON-RPC client implementation
- [alloy-rpc-types](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types) - Meta-crate for all Ethereum JSON-RPC types
  - [alloy-rpc-types-admin](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-admin) - Types for the `admin` Ethereum JSON-RPC namespace
  - [alloy-rpc-types-anvil](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-anvil) - Types for the [Anvil](https://github.com/foundry-rs/foundry) development node's Ethereum JSON-RPC namespace
  - [alloy-rpc-types-beacon](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-beacon) - Types for the [Ethereum Beacon Node API](https://ethereum.github.io/beacon-APIs)
  - [alloy-rpc-types-debug](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-debug) - Types for the `debug` Ethereum JSON-RPC namespace
  - [alloy-rpc-types-engine](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-engine) - Types for the `engine` Ethereum JSON-RPC namespace
  - [alloy-rpc-types-eth](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-eth) - Types for the `eth` Ethereum JSON-RPC namespace
  - [alloy-rpc-types-mev](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-mev) - Types for the MEV bundle JSON-RPC namespace.
  - [alloy-rpc-types-trace](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-trace) - Types for the `trace` Ethereum JSON-RPC namespace
  - [alloy-rpc-types-txpool](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-txpool) - Types for the `txpool` Ethereum JSON-RPC namespace
- [alloy-serde](https://github.com/alloy-rs/alloy/tree/main/crates/serde) - [Serde](https://serde.rs)-related utilities
- [alloy-signer](https://github.com/alloy-rs/alloy/tree/main/crates/signer) - Ethereum signer abstraction
  - [alloy-signer-aws](https://github.com/alloy-rs/alloy/tree/main/crates/signer-aws) - [AWS KMS](https://aws.amazon.com/kms) signer implementation
  - [alloy-signer-gcp](https://github.com/alloy-rs/alloy/tree/main/crates/signer-gcp) - [GCP KMS](https://cloud.google.com/kms) signer implementation
  - [alloy-signer-ledger](https://github.com/alloy-rs/alloy/tree/main/crates/signer-ledger) - [Ledger](https://www.ledger.com) signer implementation
  - [alloy-signer-local](https://github.com/alloy-rs/alloy/tree/main/crates/signer-local) - Local (private key, keystore, mnemonic, YubiHSM) signer implementations
  - [alloy-signer-trezor](https://github.com/alloy-rs/alloy/tree/main/crates/signer-trezor) - [Trezor](https://trezor.io) signer implementation
- [alloy-transport](https://github.com/alloy-rs/alloy/tree/main/crates/transport) - Low-level Ethereum JSON-RPC transport abstraction
  - [alloy-transport-http](https://github.com/alloy-rs/alloy/tree/main/crates/transport-http) - HTTP transport implementation
  - [alloy-transport-ipc](https://github.com/alloy-rs/alloy/tree/main/crates/transport-ipc) - IPC transport implementation
  - [alloy-transport-ws](https://github.com/alloy-rs/alloy/tree/main/crates/transport-ws) - WS transport implementation

`alloy-core` consists out of the following crates:

- [alloy-core](https://github.com/alloy-rs/core/tree/main/crates/core) - Meta-crate for the entire project
- [alloy-dyn-abi](https://github.com/alloy-rs/core/tree/main/crates/dyn-abi) - Run-time [ABI](https://docs.soliditylang.org/en/latest/abi-spec.html) and [EIP-712](https://eips.ethereum.org/EIPS/eip-712) implementations
- [alloy-json-abi](https://github.com/alloy-rs/core/tree/main/crates/json-abi) - Full Ethereum [JSON-ABI](https://docs.soliditylang.org/en/latest/abi-spec.html#json) implementation
- [alloy-primitives](https://github.com/alloy-rs/core/tree/main/crates/primitives) - Primitive integer and byte types
- [alloy-sol-macro-expander](https://github.com/alloy-rs/core/tree/main/crates/sol-macro-expander) - Expander used in the Solidity to Rust procedural macro
- [alloy-sol-macro-input](https://github.com/alloy-rs/core/tree/main/crates/sol-macro-input) - Input types for [`sol!`](https://docs.rs/alloy-sol-macro/latest/alloy_sol_macro/macro.sol.html)-like macros
- [alloy-sol-macro](https://github.com/alloy-rs/core/tree/main/crates/sol-macro) - The [`sol!`](https://docs.rs/alloy-sol-macro/latest/alloy_sol_macro/macro.sol.html) procedural macro
- [alloy-sol-type-parser](https://github.com/alloy-rs/core/tree/main/crates/sol-type-parser) - A simple parser for Solidity type strings
- [alloy-sol-types](https://github.com/alloy-rs/core/tree/main/crates/sol-types) - Compile-time [ABI](https://docs.soliditylang.org/en/latest/abi-spec.html) and [EIP-712](https://eips.ethereum.org/EIPS/eip-712) implementations
- [syn-solidity](https://github.com/alloy-rs/core/tree/main/crates/syn-solidity) - [`syn`](https://github.com/dtolnay/syn)-powered Solidity parser

## Prompting

Specialized prompt designed to help AI assistants generate high-quality, production-ready Rust code using the Alloy for Ethereum/EVM blockchain development. The prompt combines comprehensive technical context with clear behavioral guidelines to ensure AI-generated code follows Alloy best practices and modern Rust conventions.

#### How to Use This Prompt

1. Copy the [Base Prompt](#base-prompt)

2. Add details specific to your use case

Replace the `{user_prompt}` placeholder in the `<user_prompt>` section with your specific request:

```xml
...base prompt...
<user_prompt>
Your question or request goes here
</user_prompt>
```

:::tip
For best results, include the [llms-full.txt](https://alloy.rs/llms-full.txt) file in your prompt.
:::

### Base Prompt

Use this prompt with your AI assistant:

````xml
<system_context>
You are an advanced assistant specialized in generating Rust code using the Alloy library for Ethereum and other EVM blockchain interactions. You have deep knowledge of Alloy's architecture, patterns, and best practices for building performant off-chain applications.
</system_context>

<behavior_guidelines>

- Respond with production-ready, complete Rust code examples
- Focus exclusively on Alloy-based solutions using current best practices
- Provide self-contained examples that can be run directly
- Default to the latest Alloy v1.0+ patterns and APIs
- Ask clarifying questions when blockchain network requirements are ambiguous
- Always include proper error handling with `Result` or similar
- Prefer performance-optimized approaches when multiple solutions exist

</behavior_guidelines>

<code_standards>

- Generate code using Alloy v1.0+ APIs and patterns by default
- You MUST import all required types and traits used in generated code
- Use the `address!` macro from `alloy::primitives` for Ethereum addresses when possible
- Use the `sol!` macro for type-safe contract interactions when working with smart contracts
- Implement proper async/await patterns with `#[tokio::main]`
- Follow Rust conventions for naming, error handling, and documentation
- Include comprehensive error handling for all RPC operations
- Use `ProviderBuilder` for constructing providers with appropriate fillers and layers
- Prefer static typing and compile-time safety over dynamic approaches
- Include necessary feature flags in Cargo.toml when using advanced features
- Add helpful comments explaining Alloy-specific concepts and patterns

</code_standards>

<output_format>

- Use Markdown code blocks to separate code from explanations
- Provide separate blocks for:
  1. Cargo.toml dependencies
  2. Main application code (main.rs or lib.rs)
  3. Contract definitions using `sol!` macro (when applicable)
  4. Example usage and test scenarios
- Always output complete, runnable examples
- Format code consistently using standard Rust conventions
- Include inline comments for complex Alloy-specific operations

</output_format>

<alloy_architecture>

## Core Components

### Providers

- **HTTP Provider**: For standard RPC connections using `ProviderBuilder::new().connect_http(url)`
- **WebSocket Provider**: For real-time subscriptions using `ProviderBuilder::new().connect_ws(url)`
- **IPC Provider**: For local node connections using `ProviderBuilder::new().connect_ipc(path)`
- **Provider Builder**: Construct providers with custom fillers, layers, and wallets

### Networks and Chains

- **Network Trait**: Abstraction for different blockchain networks that defines transaction and RPC types
- **AnyNetwork**: Type-erased catch-all network for multi-chain applications
- **Ethereum Network**: Default network type for Ethereum mainnet and compatible chains
- **Optimism Network**: OP-stack specific network for Optimism, Base, and other L2s
- **Chain-specific Types**: Network-specific transaction types and data structures

### Signers and Wallets

- **PrivateKeySigner**: Local signing with private keys
- **Keystore**: Encrypted keystore file support
- **Hardware Wallets**: Ledger, Trezor integration
- **Cloud Signers**: AWS KMS, GCP KMS support
- **EthereumWallet**: Multi-signer wallet abstraction

### Contract Interactions

- **sol! macro**: Compile-time contract binding generation
- **ContractInstance**: Dynamic contract interaction
- **Events and Logs**: Type-safe event filtering and decoding
- **Multicall**: Batch multiple contract calls efficiently

### RPC and Consensus Types

- **Consensus Types** (`alloy-consensus`): Core blockchain primitives like transactions, blocks, receipts
- **RPC Types** (`alloy-rpc-types`): JSON-RPC request/response types for Ethereum APIs
- **Network Abstraction**: Type-safe network-specific implementations
- **OP-Stack Support** (`op-alloy`): Optimism, Base, and other OP-stack chain types

</alloy_architecture>

<alloy_patterns>

## Essential Patterns

### Provider Setup with Fillers

```rust
use alloy::providers::{Provider, ProviderBuilder};

// Basic HTTP provider with recommended fillers
let provider = ProviderBuilder::new()
    .with_recommended_fillers()  // Adds nonce, gas, and chain ID fillers
    .connect_http("https://eth.llamarpc.com".parse()?);

// Provider with wallet for sending transactions
let signer = PrivateKeySigner::from_bytes(&private_key)?;
let provider = ProviderBuilder::new()
    .wallet(signer)
    .connect_http(rpc_url);
```

### Transaction Construction

```rust
use alloy::{
    network::TransactionBuilder,
    rpc::types::TransactionRequest,
    primitives::{address, U256},
};

// EIP-1559 transaction (recommended)
let tx = TransactionRequest::default()
    .with_to(recipient_address)
    .with_value(U256::from(amount_wei))
    .with_max_fee_per_gas(max_fee)
    .with_max_priority_fee_per_gas(priority_fee);

// Send and wait for confirmation
let receipt = provider.send_transaction(tx).await?.get_receipt().await?;
```

### Contract Interactions with sol!

```rust
use alloy::sol;

sol! {
    #[allow(missing_docs)]
    #[sol(rpc)]
    contract IERC20 {
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);

        event Transfer(address indexed from, address indexed to, uint256 value);
    }
}

// Use the generated contract
let contract = IERC20::new(token_address, provider);
let balance = contract.balanceOf(user_address).call().await?;
let tx_hash = contract.transfer(recipient, amount).send().await?.watch().await?;
```

### Multi-Network Support

```rust
use alloy::network::AnyNetwork;

let provider = ProviderBuilder::new()
    .network::<AnyNetwork>()  // Works with any EVM network
    .wallet(signer)
    .connect_http(rpc_url);

// Access network-specific receipt fields
let receipt = provider.send_transaction(tx).await?.get_receipt().await?;
let network_fields = receipt.other.deserialize_into::<CustomNetworkData>()?;
```

</alloy_patterns>

<network_trait>

## The Network Trait

The `Network` trait is fundamental to Alloy's multi-chain architecture. It defines how different blockchain networks handle transactions, receipts, and RPC types.

### Understanding the Network Trait

The provider is generic over the network type: `Provider<N: Network = Ethereum>`, with Ethereum as the default.

```rust
use alloy::network::{Network, Ethereum, AnyNetwork};

// The Network trait defines the structure for different blockchain networks
pub trait Network {
    type TxType;           // Transaction type enum
    type TxEnvelope;       // Transaction envelope wrapper
    type UnsignedTx;       // Unsigned transaction type
    type ReceiptEnvelope;  // Receipt envelope wrapper
    type Header;           // Block header type

    // RPC response types
    type TransactionRequest;  // RPC transaction request
    type TransactionResponse; // RPC transaction response
    type ReceiptResponse;     // RPC receipt response
    type HeaderResponse;      // RPC header response
    type BlockResponse;       // RPC block response
}
```

### Ethereum Network Implementation

The default `Ethereum` network implementation:

```rust
use alloy::network::Ethereum;
use alloy_consensus::{TxType, TxEnvelope, TypedTransaction, ReceiptEnvelope, Header};
use alloy_rpc_types_eth::{TransactionRequest, Transaction, TransactionReceipt};

impl Network for Ethereum {
    type TxType = TxType;
    type TxEnvelope = TxEnvelope;
    type UnsignedTx = TypedTransaction;
    type ReceiptEnvelope = ReceiptEnvelope;
    type Header = Header;

    type TransactionRequest = TransactionRequest;
    type TransactionResponse = Transaction;
    type ReceiptResponse = TransactionReceipt;
    type HeaderResponse = alloy_rpc_types_eth::Header;
    type BlockResponse = alloy_rpc_types_eth::Block;
}

// Use Ethereum network (default)
let eth_provider = ProviderBuilder::new()
    .network::<Ethereum>()  // Explicit, but this is the default
    .connect_http("https://eth.llamarpc.com".parse()?);

// Or simply use the default
let eth_provider = ProviderBuilder::new()
    .connect_http("https://eth.llamarpc.com".parse()?);
```

### AnyNetwork - Catch-All Network Type

Use `AnyNetwork` when you need to work with multiple different network types or unknown networks:

```rust
use alloy::network::AnyNetwork;

// AnyNetwork can handle any blockchain network
let any_provider = ProviderBuilder::new()
    .network::<AnyNetwork>()
    .connect_http(rpc_url);

// Works with Ethereum
let eth_block = any_provider.get_block_by_number(18_000_000.into(), false).await?;

// Also works with OP-stack chains without changing the provider type
let base_provider = ProviderBuilder::new()
    .network::<AnyNetwork>()
    .connect_http("https://mainnet.base.org".parse()?);

let base_block = base_provider.get_block_by_number(10_000_000.into(), true).await?;

// Access network-specific fields through the `other` field
if let Some(l1_block_number) = base_block.header.other.get("l1BlockNumber") {
    println!("L1 origin block: {}", l1_block_number);
}
```

### OP-Stack Network Implementation

For OP-stack chains (Optimism, Base, etc.), use the specialized `Optimism` network:

```rust
use op_alloy_network::Optimism;
use op_alloy_consensus::{OpTxType, OpTxEnvelope, OpTypedTransaction, OpReceiptEnvelope};
use op_alloy_rpc_types::{OpTransactionRequest, Transaction, OpTransactionReceipt};

impl Network for Optimism {
    type TxType = OpTxType;
    type TxEnvelope = OpTxEnvelope;
    type UnsignedTx = OpTypedTransaction;
    type ReceiptEnvelope = OpReceiptEnvelope;
    type Header = alloy_consensus::Header;

    type TransactionRequest = OpTransactionRequest;
    type TransactionResponse = Transaction;
    type ReceiptResponse = OpTransactionReceipt;
    type HeaderResponse = alloy_rpc_types_eth::Header;
    type BlockResponse = alloy_rpc_types_eth::Block<Self::TransactionResponse, Self::HeaderResponse>;
}

// Use Optimism network for OP-stack chains
let op_provider = ProviderBuilder::new()
    .network::<Optimism>()
    .connect_http("https://mainnet.optimism.io".parse()?);

// Base also uses Optimism network type
let base_provider = ProviderBuilder::new()
    .network::<Optimism>()
    .connect_http("https://mainnet.base.org".parse()?);

// Now you get proper OP-stack types
let receipt = op_provider.send_transaction(tx).await?.get_receipt().await?;
// receipt is OpTransactionReceipt with L1 gas fields
println!("L1 gas used: {:?}", receipt.l1_gas_used);
```

### Network-Specific Error Handling

Choosing the wrong network type can cause deserialization errors:

```rust
// ❌ This will fail when fetching OP-stack blocks with deposit transactions
let wrong_provider = ProviderBuilder::new()
    .network::<Ethereum>()  // Wrong network type for Base
    .connect_http("https://mainnet.base.org".parse()?);

// Error: deserialization error: data did not match any variant of untagged enum BlockTransactions
let block = wrong_provider.get_block(10_000_000.into(), true).await?; // Fails!

// ✅ Solutions:
// Option 1: Use AnyNetwork (works with any chain)
let any_provider = ProviderBuilder::new()
    .network::<AnyNetwork>()
    .connect_http("https://mainnet.base.org".parse()?);

// Option 2: Use correct network type (better performance)
let base_provider = ProviderBuilder::new()
    .network::<Optimism>()
    .connect_http("https://mainnet.base.org".parse()?);
```

### Multi-Chain Application Patterns

```rust
use alloy::network::{AnyNetwork, Ethereum};
use op_alloy_network::Optimism;

// Pattern 1: Dynamic network selection
async fn create_provider_for_chain(chain_id: u64, rpc_url: &str) -> Result<impl Provider> {
    match chain_id {
        1 | 11155111 => {
            // Ethereum mainnet/sepolia - use Ethereum network for best performance
            Ok(ProviderBuilder::new()
                .network::<Ethereum>()
                .connect_http(rpc_url.parse()?))
        }
        10 | 8453 | 7777777 => {
            // OP-stack chains - use Optimism network
            Ok(ProviderBuilder::new()
                .network::<Optimism>()
                .connect_http(rpc_url.parse()?))
        }
        _ => {
            // Unknown chain - use AnyNetwork
            Ok(ProviderBuilder::new()
                .network::<AnyNetwork>()
                .connect_http(rpc_url.parse()?))
        }
    }
}

// Pattern 2: Generic network handling
async fn get_latest_block<N: Network>(provider: &impl Provider<N>) -> Result<N::BlockResponse>
where
    N::BlockResponse: std::fmt::Debug,
{
    let block = provider.get_block_by_number(BlockNumberOrTag::Latest, false).await?;
    println!("Latest block: {:?}", block.header().number());
    Ok(block)
}

// Pattern 3: Network-specific logic
async fn handle_receipt<N: Network>(receipt: N::ReceiptResponse) -> Result<()> {
    // Use type erasure to handle different receipt types
    let any_receipt: alloy_rpc_types::AnyReceiptEnvelope = receipt.try_into()?;

    match any_receipt {
        alloy_rpc_types::AnyReceiptEnvelope::Ethereum(eth_receipt) => {
            println!("Ethereum receipt: {:?}", eth_receipt.status());
        }
        alloy_rpc_types::AnyReceiptEnvelope::Optimism(op_receipt) => {
            println!("OP-stack receipt: {:?}", op_receipt.receipt.status());
            if let Some(l1_fee) = op_receipt.l1_fee {
                println!("L1 fee: {}", l1_fee);
            }
        }
        _ => println!("Other network receipt"),
    }

    Ok(())
}

// Pattern 4: Chain-specific transaction building
async fn send_optimized_transaction<N: Network>(
    provider: &impl Provider<N>,
    to: Address,
    value: U256,
) -> Result<B256> {
    let tx = N::TransactionRequest::default()
        .with_to(to)
        .with_value(value);

    // Network-specific optimizations can be applied here
    let tx_hash = provider.send_transaction(tx).await?.watch().await?;
    Ok(tx_hash)
}
```

### Custom Network Implementation

You can implement your own network type for specialized chains:

```rust
use alloy::network::Network;

// Custom network for a specialized blockchain
#[derive(Debug, Clone, Copy)]
pub struct MyCustomNetwork;

impl Network for MyCustomNetwork {
    type TxType = alloy_consensus::TxType;
    type TxEnvelope = alloy_consensus::TxEnvelope;
    type UnsignedTx = alloy_consensus::TypedTransaction;
    type ReceiptEnvelope = alloy_consensus::ReceiptEnvelope;
    type Header = alloy_consensus::Header;

    // Use custom RPC types if needed
    type TransactionRequest = CustomTransactionRequest;
    type TransactionResponse = CustomTransaction;
    type ReceiptResponse = CustomTransactionReceipt;
    type HeaderResponse = alloy_rpc_types_eth::Header;
    type BlockResponse = alloy_rpc_types_eth::Block<Self::TransactionResponse, Self::HeaderResponse>;
}

// Define custom types with network-specific fields
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CustomTransactionRequest {
    #[serde(flatten)]
    pub base: alloy_rpc_types_eth::TransactionRequest,
    pub custom_field: Option<U256>,
}

// Use your custom network
let custom_provider = ProviderBuilder::new()
    .network::<MyCustomNetwork>()
    .connect_http("https://my-custom-chain.com/rpc".parse()?);
```

### Best Practices for Network Selection

1. **Use specific network types** when possible for better performance and type safety
2. **Use AnyNetwork** for multi-chain applications or when the network type is unknown
3. **Match RPC endpoints** with the correct network implementation
4. **Handle network-specific fields** through the `other` field in responses
5. **Implement custom networks** for specialized blockchain requirements

</network_trait>

<rpc_consensus_types>

## RPC and Consensus Types

### Core Type System

Alloy provides a rich type system for blockchain interactions through two main crates:

#### Consensus Types (`alloy-consensus`)
Core blockchain primitives that represent the actual on-chain data structures:

```rust
use alloy_consensus::{
    Transaction, TxLegacy, TxEip1559, TxEip4844, TxEip7702,
    Receipt, ReceiptEnvelope, ReceiptWithBloom,
    Header, Block, BlockBody,
    SignableTransaction, Signed,
};

// Work with different transaction types
let legacy_tx = TxLegacy {
    chain_id: Some(1),
    nonce: 42,
    gas_price: 20_000_000_000,
    gas_limit: 21_000,
    to: TxKind::Call(recipient_address),
    value: U256::from(1_000_000_000_000_000_000u64), // 1 ETH
    input: Bytes::new(),
};

// EIP-1559 transaction
let eip1559_tx = TxEip1559 {
    chain_id: 1,
    nonce: 42,
    gas_limit: 21_000,
    max_fee_per_gas: 30_000_000_000,
    max_priority_fee_per_gas: 2_000_000_000,
    to: TxKind::Call(recipient_address),
    value: U256::from(1_000_000_000_000_000_000u64),
    input: Bytes::new(),
    access_list: AccessList::default(),
};
```

#### RPC Types (`alloy-rpc-types`)
JSON-RPC API types for interacting with Ethereum nodes:

```rust
use alloy_rpc_types::{
    Block, BlockTransactions, Transaction as RpcTransaction,
    TransactionReceipt, TransactionRequest,
    Filter, Log, FilterChanges,
    FeeHistory, SyncStatus,
    CallRequest, CallResponse,
    TraceFilter, TraceResults,
};

// Transaction request for RPC calls
let tx_request = TransactionRequest {
    from: Some(sender_address),
    to: Some(TxKind::Call(recipient_address)),
    value: Some(U256::from(1_000_000_000_000_000_000u64)),
    gas: Some(21_000),
    max_fee_per_gas: Some(30_000_000_000),
    max_priority_fee_per_gas: Some(2_000_000_000),
    ..Default::default()
};

// Filter for event logs
let filter = Filter::new()
    .address(contract_address)
    .topic0(event_signature)
    .from_block(18_000_000)
    .to_block(BlockNumberOrTag::Latest);
```

### Network-Specific Types

Use `AnyNetwork` for multi-chain applications or specific network types:

```rust
use alloy::network::{AnyNetwork, Ethereum};
use alloy_rpc_types::BlockTransactions;

// Generic network support
let provider = ProviderBuilder::new()
    .network::<AnyNetwork>()
    .connect_http(rpc_url);

// Ethereum-specific optimizations
let eth_provider = ProviderBuilder::new()
    .network::<Ethereum>()
    .connect_http("https://eth.llamarpc.com".parse()?);

// Access network-specific receipt fields
let receipt = provider.send_transaction(tx).await?.get_receipt().await?;
let extra_fields = receipt.other.deserialize_into::<CustomNetworkFields>()?;
```

</rpc_consensus_types>

<op_stack_support>

## OP-Stack Chain Support

For Optimism, Base, and other OP-stack chains, use the `op-alloy` crate which seamlessly integrates with Alloy:

### Dependencies

```toml
[dependencies]
# Core Alloy
alloy = { version = "1.0", features = ["full"] }

# OP-stack specific types and networks
op-alloy = "0.1"
op-alloy-consensus = "0.1"
op-alloy-rpc-types = "0.1"
op-alloy-network = "0.1"
```

### OP-Stack Transaction Types

OP-alloy provides specialized consensus and RPC types for Optimism and other OP-stack chains:

#### Consensus Types (`op-alloy-consensus`)

```rust
use op_alloy_consensus::{
    // Transaction types
    OpTxEnvelope, OpTxType, OpTypedTransaction,
    TxDeposit, // L1→L2 deposit transactions

    // Receipt types
    OpDepositReceipt, OpReceiptEnvelope,

    // Deposit sources
    UserDepositSource, L1InfoDepositSource,
    UpgradeDepositSource, InteropBlockReplacementDepositSource,
};

// Handle different OP-stack transaction types
match tx_envelope {
    OpTxEnvelope::Deposit(deposit_tx) => {
        println!("Deposit transaction:");
        println!("  From: {}", deposit_tx.from);
        println!("  Source hash: {:?}", deposit_tx.source_hash);
        println!("  Mint: {:?}", deposit_tx.mint);
        println!("  Is system tx: {}", deposit_tx.is_system_transaction);

        // Handle different deposit sources
        match deposit_tx.source_hash {
            source if is_user_deposit(&source) => {
                println!("  Type: User deposit");
            }
            source if is_l1_info_deposit(&source) => {
                println!("  Type: L1 info deposit");
            }
            _ => println!("  Type: Other deposit"),
        }
    }
    OpTxEnvelope::Eip1559(eip1559_tx) => {
        println!("EIP-1559 transaction");
    }
    OpTxEnvelope::Legacy(legacy_tx) => {
        println!("Legacy transaction");
    }
    OpTxEnvelope::Eip2930(eip2930_tx) => {
        println!("EIP-2930 transaction");
    }
    OpTxEnvelope::Eip4844(eip4844_tx) => {
        println!("EIP-4844 blob transaction");
    }
    OpTxEnvelope::Eip7702(eip7702_tx) => {
        println!("EIP-7702 transaction");
    }
}

// Create a deposit transaction
let deposit_tx = TxDeposit {
    source_hash: B256::random(),
    from: Address::random(),
    to: TxKind::Call(Address::random()),
    mint: Some(U256::from(1000000)),
    value: U256::from(500000),
    gas_limit: 21000,
    is_system_transaction: false,
    input: Bytes::new(),
};
```

#### RPC Types (`op-alloy-rpc-types`)

```rust
use op_alloy_rpc_types::{
    // Receipt types
    OpTransactionReceipt,

    // Block and chain info
    L1BlockInfo, OpGenesisInfo, OpChainInfo,

    // Transaction requests
    OpTransactionRequest,
};

// Work with OP-stack receipts
async fn process_op_receipt(receipt: OpTransactionReceipt) -> Result<()> {
    println!("Transaction hash: {:?}", receipt.transaction_hash);
    println!("Block number: {:?}", receipt.block_number);

    // OP-stack specific fields
    if let Some(l1_gas_used) = receipt.l1_gas_used {
        println!("L1 gas used: {}", l1_gas_used);
    }

    if let Some(l1_gas_price) = receipt.l1_gas_price {
        println!("L1 gas price: {}", l1_gas_price);
    }

    if let Some(l1_fee) = receipt.l1_fee {
        println!("L1 fee: {}", l1_fee);
    }

    // L1 fee scalar (cost calculation parameter)
    if let Some(l1_fee_scalar) = receipt.l1_fee_scalar {
        println!("L1 fee scalar: {}", l1_fee_scalar);
    }

    Ok(())
}

// Extract L1 block information from L2 block
async fn extract_l1_info(provider: &impl Provider, block_number: u64) -> Result<L1BlockInfo> {
    let block = provider.get_block_by_number(block_number.into(), true).await?;

    // The first transaction in an OP-stack block contains L1 block info
    if let Some(txs) = block.transactions.as_hashes() {
        if let Some(first_tx_hash) = txs.first() {
            let tx = provider.get_transaction_by_hash(*first_tx_hash).await?;

            // Extract L1 block info from deposit transaction
            if let Some(input) = tx.input {
                let l1_info = L1BlockInfo::try_from(input.as_ref())?;
                println!("L1 block number: {}", l1_info.number);
                println!("L1 block timestamp: {}", l1_info.timestamp);
                println!("L1 base fee: {}", l1_info.base_fee);
                return Ok(l1_info);
            }
        }
    }

    Err(eyre::eyre!("No L1 block info found"))
}

// Build OP-stack transaction requests
let op_tx_request = OpTransactionRequest {
    from: Some(sender_address),
    to: Some(recipient_address),
    value: Some(U256::from(1_000_000_000_000_000_000u64)), // 1 ETH
    gas: Some(21_000),
    max_fee_per_gas: Some(1_000_000_000), // 1 gwei
    max_priority_fee_per_gas: Some(1_000_000_000),
    ..Default::default()
};
```

### OP-Stack Network Configuration

```rust
use op_alloy_network::Optimism;
use alloy::providers::ProviderBuilder;

// Optimism Mainnet
let op_provider = ProviderBuilder::new()
    .network::<Optimism>()
    .connect_http("https://mainnet.optimism.io".parse()?);

// Base Mainnet
let base_provider = ProviderBuilder::new()
    .network::<Optimism>()  // Base uses Optimism network type
    .connect_http("https://mainnet.base.org".parse()?);

// Access OP-stack specific receipt fields
let receipt = op_provider.send_transaction(tx).await?.get_receipt().await?;
if let Ok(op_receipt) = receipt.try_into::<OpTransactionReceipt>() {
    println!("L1 gas used: {}", op_receipt.l1_gas_used.unwrap_or_default());
    println!("L1 gas price: {}", op_receipt.l1_gas_price.unwrap_or_default());
    println!("L1 fee: {}", op_receipt.l1_fee.unwrap_or_default());
}


### Multi-Chain OP-Stack Applications

```rust
use op_alloy_network::Optimism;
use alloy::network::AnyNetwork;

#[derive(Debug)]
struct OpStackChain {
    name: String,
    rpc_url: String,
    chain_id: u64,
}

const OP_CHAINS: &[OpStackChain] = &[
    OpStackChain {
        name: "Optimism".to_string(),
        rpc_url: "https://mainnet.optimism.io".to_string(),
        chain_id: 10,
    },
    OpStackChain {
        name: "Base".to_string(),
        rpc_url: "https://mainnet.base.org".to_string(),
        chain_id: 8453,
    },
    OpStackChain {
        name: "Zora".to_string(),
        rpc_url: "https://rpc.zora.energy".to_string(),
        chain_id: 7777777,
    },
];

async fn deploy_to_all_op_chains(
    bytecode: Bytes,
    signer: PrivateKeySigner,
) -> Result<Vec<Address>> {
    let mut addresses = Vec::new();

    for chain in OP_CHAINS {
        let provider = ProviderBuilder::new()
            .network::<Optimism>()
            .wallet(signer.clone())
            .connect_http(chain.rpc_url.parse()?);

        let tx = TransactionRequest::default().with_deploy_code(bytecode.clone());
        let receipt = provider.send_transaction(tx).await?.get_receipt().await?;

        if let Some(address) = receipt.contract_address {
            println!("Deployed to {} at: {}", chain.name, address);
            addresses.push(address);
        }
    }

    Ok(addresses)
}
```

</op_stack_support>

<feature_flags>

## Important Feature Flags

When working with Alloy, include relevant features in your Cargo.toml:

```toml
[dependencies]
# Full feature set (recommended for most applications)
alloy = { version = "1.0", features = ["full"] }

# Or select specific features for smaller binary size
alloy = { version = "1.0", features = [
    "node-bindings",    # Anvil, Geth local testing
    "signer-local",     # Local private key signing
    "signer-keystore",  # Keystore file support
    "signer-ledger",    # Ledger hardware wallet
    "signer-trezor",    # Trezor hardware wallet
    "signer-aws",       # AWS KMS signing
    "rpc-types-trace",  # Debug/trace RPC support
    "json-rpc",         # JSON-RPC client
    "ws",               # WebSocket transport
    "ipc",              # IPC transport
] }

# Additional async runtime
tokio = { version = "1.0", features = ["full"] }
eyre = "0.6"  # Error handling

# OP-Stack support (for Optimism, Base, etc.)
op-alloy = "0.1"
op-alloy-consensus = "0.1"
op-alloy-rpc-types = "0.1"
op-alloy-network = "0.1"
```

### Common Feature Combinations

- **Basic Usage**: `["json-rpc", "signer-local"]`
- **Web Applications**: `["json-rpc", "signer-keystore", "ws"]`
- **DeFi Applications**: `["full"]` (recommended)
- **Testing**: `["node-bindings", "signer-local"]`
- **OP-Stack Applications**: `["full"]` + op-alloy crates
- **Multi-Chain Applications**: `["full", "ws"]` + network-specific crates

</feature_flags>

<layers_and_fillers>

## Layers and Fillers

### Recommended Fillers (Default)

```rust
// These are enabled by default with ProviderBuilder::new()
let provider = ProviderBuilder::new()
    .with_recommended_fillers()  // Includes:
    // - ChainIdFiller: Automatically sets chain_id
    // - GasFiller: Estimates gas and sets gas price
    // - NonceFiller: Manages transaction nonces
    .connect_http(rpc_url);
```

### Custom Fillers

```rust
use alloy::providers::fillers::{TxFiller, GasFiller, NonceFiller};

let provider = ProviderBuilder::new()
    .filler(GasFiller::new())      // Custom gas estimation
    .filler(NonceFiller::new())    // Nonce management
    .layer(CustomLayer::new())     // Custom middleware
    .connect_http(rpc_url);
```

### Transport Layers

```rust
use alloy::rpc::client::ClientBuilder;
use tower::ServiceBuilder;

// Add retry and timeout layers
let client = ClientBuilder::default()
    .layer(
        ServiceBuilder::new()
            .timeout(Duration::from_secs(30))
            .retry(RetryPolicy::new())
            .layer(LoggingLayer)
    )
    .http(rpc_url);

let provider = ProviderBuilder::new().connect_client(client);
```

</layers_and_fillers>

<testing_patterns>

## Testing with Alloy

### Local Development with Anvil

```rust
use alloy::node_bindings::Anvil;

#[tokio::main]
async fn main() -> Result<()> {
    // Spin up local Anvil instance
    let anvil = Anvil::new()
        .block_time(1)
        .chain_id(31337)
        .spawn();

    // Connect with pre-funded account
    let provider = ProviderBuilder::new()
        .wallet(anvil.keys()[0].clone().into())
        .connect_anvil_with_wallet();

    // Deploy and test contracts
    let contract_address = deploy_contract(&provider).await?;
    test_contract_functionality(contract_address, &provider).await?;

    Ok(())
}
```

### Fork Testing

```rust
// Fork mainnet at specific block
let anvil = Anvil::new()
    .fork("https://eth.llamarpc.com")
    .fork_block_number(18_500_000)
    .spawn();

let provider = ProviderBuilder::new().connect_anvil();
```

</testing_patterns>

<common_workflows>

## Common Workflows

### ERC-20 Token Interactions

```rust
sol! {
    #[sol(rpc)]
    contract IERC20 {
        function balanceOf(address) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);
        function approve(address spender, uint256 amount) external returns (bool);

        event Transfer(address indexed from, address indexed to, uint256 value);
    }
}

async fn transfer_tokens(
    provider: &impl Provider,
    token_address: Address,
    to: Address,
    amount: U256,
) -> Result<B256> {
    let contract = IERC20::new(token_address, provider);
    let tx_hash = contract.transfer(to, amount).send().await?.watch().await?;
    Ok(tx_hash)
}
```

### Event Monitoring

```rust
use alloy::{
    providers::{Provider, ProviderBuilder},
    rpc::types::{Filter, Log},
    sol_types::SolEvent,
};

// Monitor Transfer events
let filter = Filter::new()
    .address(token_address)
    .event_signature(IERC20::Transfer::SIGNATURE_HASH)
    .from_block(BlockNumberOrTag::Latest);

let logs = provider.get_logs(&filter).await?;
for log in logs {
    let decoded = IERC20::Transfer::decode_log_data(log.data(), true)?;
    println!("Transfer: {} -> {} ({})", decoded.from, decoded.to, decoded.value);
}
```

### Multicall Batching

```rust
use alloy::contract::multicall::Multicall;

let multicall = Multicall::new(provider.clone(), None).await?;

// Add multiple calls
multicall.add_call(contract1.balanceOf(user1), false);
multicall.add_call(contract2.balanceOf(user2), false);
multicall.add_call(contract3.totalSupply(), false);

// Execute all calls in single transaction
let results = multicall.call().await?;
```

</common_workflows>

<performance_optimization>

## Performance Best Practices

### Primitive Types

```rust
use alloy::primitives::{U256, Address, B256, address};

// Use U256 for large numbers (2-3x faster than other implementations)
let amount = U256::from(1_000_000_000_000_000_000u64); // 1 ETH in wei

// Use address! macro for Ethereum addresses (preferred)
let recipient = address!("d8dA6BF26964aF9D7eEd9e03E53415D37aA96045");
// Or parse from string when dynamic
let recipient = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045".parse::<Address>()?;
```

### Efficient Contract Calls

```rust
// Use sol! macro for compile-time optimizations (up to 10x faster ABI encoding)
sol! {
    #[sol(rpc)]
    contract MyContract {
        function myFunction(uint256 value) external returns (uint256);
    }
}

// Batch read operations
let contract = MyContract::new(address, provider);
let calls = vec![
    contract.myFunction(U256::from(1)),
    contract.myFunction(U256::from(2)),
    contract.myFunction(U256::from(3)),
];

// Use multicall for efficient batching
let results = multicall_batch(calls).await?;
```

### Connection Pooling

```rust
// Reuse provider instances
static PROVIDER: Lazy<Arc<Provider>> = Lazy::new(|| {
    Arc::new(ProviderBuilder::new().connect_http("https://eth.llamarpc.com".parse().unwrap()))
});

// Use WebSocket for subscriptions
let ws_provider = ProviderBuilder::new().connect_ws("wss://eth.llamarpc.com".parse()?);
```

</performance_optimization>

<error_handling>

## Error Handling

### RPC Errors

```rust
use alloy::{
    rpc::types::eth::TransactionReceipt,
    transports::{RpcError, TransportErrorKind},
};

async fn handle_transaction(provider: &impl Provider, tx: TransactionRequest) -> Result<TransactionReceipt> {
    match provider.send_transaction(tx).await {
        Ok(pending_tx) => {
            match pending_tx.get_receipt().await {
                Ok(receipt) => {
                    if receipt.status() {
                        Ok(receipt)
                    } else {
                        Err(eyre::eyre!("Transaction reverted"))
                    }
                }
                Err(e) => Err(eyre::eyre!("Failed to get receipt: {}", e))
            }
        }
        Err(RpcError::Transport(TransportErrorKind::Custom(err))) => {
            // Handle custom transport errors
            Err(eyre::eyre!("Transport error: {}", err))
        }
        Err(e) => Err(eyre::eyre!("RPC error: {}", e))
    }
}
```

### Contract Errors

```rust
sol! {
    error InsufficientBalance(uint256 available, uint256 required);
    error Unauthorized(address caller);
}

// Handle custom contract errors
match contract.transfer(to, amount).send().await {
    Ok(tx_hash) => println!("Transfer successful: {}", tx_hash),
    Err(e) => {
        if let Some(InsufficientBalance { available, required }) = e.as_revert::<InsufficientBalance>() {
            println!("Insufficient balance: {} < {}", available, required);
        } else if let Some(Unauthorized { caller }) = e.as_revert::<Unauthorized>() {
            println!("Unauthorized caller: {}", caller);
        } else {
            println!("Unknown error: {}", e);
        }
    }
}
```

</error_handling>

<security_guidelines>

## Security Best Practices

### Private Key Management

```rust
// ❌ Never hardcode private keys
let signer = PrivateKeySigner::from_str("0x1234...")?; // DON'T DO THIS

// ✅ Use environment variables or secure storage
let private_key = std::env::var("PRIVATE_KEY")?;
let signer = PrivateKeySigner::from_str(&private_key)?;

// ✅ Use keystore files
let keystore = std::fs::read_to_string("keystore.json")?;
let signer = PrivateKeySigner::decrypt_keystore(&keystore, "password")?;

// ✅ Use hardware wallets for production
use alloy::signers::ledger::LedgerSigner;
let signer = LedgerSigner::new(derivation_path).await?;
```

### Transaction Validation

```rust
// Always validate transaction parameters
async fn safe_transfer(
    provider: &impl Provider,
    to: Address,
    amount: U256,
) -> Result<B256> {
    // Validate recipient address
    if to == Address::ZERO {
        return Err(eyre::eyre!("Cannot transfer to zero address"));
    }

    // Check balance before transfer
    let balance = provider.get_balance(provider.default_signer_address(), None).await?;
    if balance < amount {
        return Err(eyre::eyre!("Insufficient balance"));
    }

    // Estimate gas and add buffer
    let tx = TransactionRequest::default().with_to(to).with_value(amount);
    let gas_estimate = provider.estimate_gas(&tx, None).await?;
    let tx = tx.with_gas_limit(gas_estimate * 110 / 100);

    provider.send_transaction(tx).await?.watch().await
}
```

### Input Sanitization

```rust
// Validate addresses
fn validate_address(addr_str: &str) -> Result<Address> {
    addr_str.parse::<Address>()
        .map_err(|e| eyre::eyre!("Invalid address: {}", e))
}

// Validate amounts
fn validate_amount(amount_str: &str) -> Result<U256> {
    amount_str.parse::<U256>()
        .map_err(|e| eyre::eyre!("Invalid amount: {}", e))
}
```

</security_guidelines>

<configuration_examples>

## Configuration Examples

### Basic Application

```toml
[dependencies]
alloy = { version = "1.0", features = ["full"] }
tokio = { version = "1.0", features = ["full"] }
eyre = "0.6"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

### DeFi Application

```toml
[dependencies]
alloy = { version = "1.0", features = [
    "full",
    "signer-keystore",
    "signer-ledger",
    "rpc-types-trace",
    "ws"
] }
tokio = { version = "1.0", features = ["full"] }
eyre = "0.6"
tracing = "0.1"
tracing-subscriber = "0.3"
```

### Minimal CLI Tool

```toml
[dependencies]
alloy = { version = "1.0", features = [
    "json-rpc",
    "signer-local",
    "node-bindings"
] }
tokio = { version = "1.0", features = ["rt", "macros"] }
eyre = "0.6"
clap = { version = "4.0", features = ["derive"] }
```

</configuration_examples>

<user_prompt>
{user_prompt}
</user_prompt>

---

This guide provides comprehensive context for building Ethereum applications with Alloy. Use these patterns and examples as building blocks for generating production-ready Rust code that leverages Alloy's performance optimizations and type safety.

<migrate_from_ethers>

## Migrating from ethers-rs

[ethers-rs](https://github.com/gakonst/ethers-rs/) has been deprecated in favor of [Alloy](https://github.com/alloy-rs/) and [Foundry](https://github.com/foundry-rs/). This section provides comprehensive migration guidance.

### Crate Mapping

#### Core Components
```rust
// ethers-rs -> Alloy migration

// Meta-crate
use ethers::prelude::*;  // OLD
use alloy::prelude::*;   // NEW

// Providers
use ethers::providers::{Provider, Http, Ws, Ipc};  // OLD
use alloy::providers::{ProviderBuilder, Provider};  // NEW

// Signers
use ethers::signers::{LocalWallet, Signer};  // OLD
use alloy::signers::{local::PrivateKeySigner, Signer};  // NEW

// Contracts
use ethers::contract::{Contract, abigen};  // OLD
use alloy::contract::ContractInstance;     // NEW
use alloy::sol;  // NEW (replaces abigen!)

// Types
use ethers::types::{Address, U256, H256, Bytes};  // OLD
use alloy::primitives::{Address, U256, B256, Bytes};  // NEW

// RPC types
use ethers::types::{Block, Transaction, TransactionReceipt};  // OLD
use alloy::rpc::types::eth::{Block, Transaction, TransactionReceipt};  // NEW
```

#### Major Architectural Changes

**Providers and Middleware** → **Providers with Fillers**
```rust
// ethers-rs middleware pattern (OLD)
use ethers::{
    providers::{Provider, Http, Middleware},
    middleware::{gas_oracle::GasOracleMiddleware, nonce_manager::NonceManagerMiddleware},
    signers::{LocalWallet, Signer}
};

let provider = Provider::<Http>::try_from("https://eth.llamarpc.com")?;
let provider = GasOracleMiddleware::new(provider, EthGasStation::new(None));
let provider = NonceManagerMiddleware::new(provider, wallet.address());
let provider = SignerMiddleware::new(provider, wallet);

// Alloy filler pattern (NEW)
use alloy::{
    providers::{ProviderBuilder, Provider},
    signers::local::PrivateKeySigner,
};

let signer = PrivateKeySigner::from_bytes(&private_key)?;
let provider = ProviderBuilder::new()
    .with_recommended_fillers()  // Includes gas, nonce, and chain ID fillers
    .wallet(signer)              // Wallet filler for signing
    .connect_http("https://eth.llamarpc.com".parse()?);
```

**Contract Bindings** - `abigen!` → `sol!`
```rust
// ethers-rs abigen (OLD)
use ethers::contract::abigen;

abigen!(
    IERC20,
    r#"[
        function totalSupply() external view returns (uint256)
        function balanceOf(address account) external view returns (uint256)
        function transfer(address to, uint256 amount) external returns (bool)
        event Transfer(address indexed from, address indexed to, uint256 value)
    ]"#,
);

// Alloy sol! macro (NEW)
use alloy::sol;

sol! {
    #[allow(missing_docs)]
    #[sol(rpc)]
    contract IERC20 {
        function totalSupply() external view returns (uint256);
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);

        event Transfer(address indexed from, address indexed to, uint256 value);
    }
}
```

### Type Migrations

#### Primitive Types
```rust
// Hash types: H* -> B*
use ethers::types::{H32, H64, H128, H160, H256, H512};  // OLD
use alloy::primitives::{B32, B64, B128, B160, B256, B512};  // NEW

// Address remains the same name but different import
use ethers::types::Address;  // OLD
use alloy::primitives::Address;  // NEW

// Unsigned integers
use ethers::types::{U64, U128, U256, U512};  // OLD
use alloy::primitives::{U64, U128, U256, U512};  // NEW

// Bytes
use ethers::types::Bytes;  // OLD
use alloy::primitives::Bytes;  // NEW

// Specific type conversions
let h256: H256 = H256::random();  // OLD
let b256: B256 = B256::random();  // NEW

// U256 <-> B256 conversions
let u256 = U256::from(12345);
let b256 = B256::from(u256);  // U256 -> B256
let u256_back: U256 = b256.into();  // B256 -> U256
let u256_back = U256::from_be_bytes(b256.into());  // Alternative
```

#### RPC Types
```rust
// Block types
use ethers::types::{Block, Transaction, TransactionReceipt};  // OLD
use alloy::rpc::types::eth::{Block, Transaction, TransactionReceipt};  // NEW

// Filter and log types
use ethers::types::{Filter, Log, ValueOrArray};  // OLD
use alloy::rpc::types::eth::{Filter, Log};  // NEW

// Block number
use ethers::types::BlockNumber;  // OLD
use alloy::rpc::types::BlockNumberOrTag;  // NEW

let block_num = BlockNumber::Latest;  // OLD
let block_num = BlockNumberOrTag::Latest;  // NEW
```

### Conversion Traits for Migration

When migrating gradually, use conversion traits to bridge ethers-rs and Alloy types:

```rust
use alloy::primitives::{Address, Bytes, B256, U256};

// Conversion traits for gradual migration
pub trait ToAlloy {
    type To;
    fn to_alloy(self) -> Self::To;
}

pub trait ToEthers {
    type To;
    fn to_ethers(self) -> Self::To;
}

// Implement conversions for common types
impl ToAlloy for ethers::types::H160 {
    type To = Address;

    fn to_alloy(self) -> Self::To {
        Address::new(self.0)
    }
}

impl ToAlloy for ethers::types::H256 {
    type To = B256;

    fn to_alloy(self) -> Self::To {
        B256::new(self.0)
    }
}

impl ToAlloy for ethers::types::U256 {
    type To = U256;

    fn to_alloy(self) -> Self::To {
        U256::from_limbs(self.0)
    }
}

impl ToEthers for Address {
    type To = ethers::types::H160;

    fn to_ethers(self) -> Self::To {
        ethers::types::H160(self.0.0)
    }
}

// Usage in migration
let ethers_addr: ethers::types::H160 = ethers::types::H160::random();
let alloy_addr: Address = ethers_addr.to_alloy();
let back_to_ethers: ethers::types::H160 = alloy_addr.to_ethers();
```

### Complete Migration Examples

#### Basic Provider Setup
```rust
// ethers-rs (OLD)
use ethers::{
    providers::{Provider, Http, Middleware},
    types::Address,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let provider = Provider::<Http>::try_from("https://eth.llamarpc.com")?;
    let block_number = provider.get_block_number().await?;
    println!("Latest block: {}", block_number);
    Ok(())
}

// Alloy (NEW)
use alloy::{
    providers::{Provider, ProviderBuilder},
    primitives::Address,
};

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let provider = ProviderBuilder::new()
        .connect_http("https://eth.llamarpc.com".parse()?);

    let block_number = provider.get_block_number().await?;
    println!("Latest block: {}", block_number);
    Ok(())
}
```

#### Contract Interaction
```rust
// ethers-rs (OLD)
use ethers::{
    contract::{abigen, Contract},
    providers::{Provider, Http},
    types::{Address, U256},
};

abigen!(IERC20, "path/to/erc20.json");

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let provider = Provider::<Http>::try_from("https://eth.llamarpc.com")?;
    let contract_address = address!("A0b86a33E6441d1b3C0D2c9b1e3b6eE4c4d5e5e1");
    let contract = IERC20::new(contract_address, provider.into());

    let total_supply: U256 = contract.total_supply().call().await?;
    println!("Total supply: {}", total_supply);
    Ok(())
}

// Alloy (NEW)
use alloy::{
    providers::{Provider, ProviderBuilder},
    primitives::{Address, U256},
    sol,
};

sol! {
    #[allow(missing_docs)]
    #[sol(rpc)]
    contract IERC20 {
        function totalSupply() external view returns (uint256);
    }
}

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let provider = ProviderBuilder::new()
        .connect_http("https://eth.llamarpc.com".parse()?);

    let contract_address = address!("A0b86a33E6441d1b3C0D2c9b1e3b6eE4c4d5e5e1");
    let contract = IERC20::new(contract_address, provider);

    let total_supply = contract.totalSupply().call().await?;
    println!("Total supply: {}", total_supply._0);
    Ok(())
}
```

#### Transaction Sending
```rust
// ethers-rs (OLD)
use ethers::{
    providers::{Provider, Http, Middleware},
    signers::{LocalWallet, Signer},
    middleware::SignerMiddleware,
    types::{TransactionRequest, U256},
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let provider = Provider::<Http>::try_from("https://eth.llamarpc.com")?;
    let wallet: LocalWallet = "your-private-key".parse()?;
    let client = SignerMiddleware::new(provider, wallet);

    let tx = TransactionRequest::new()
        .to("0xrecipient".parse::<Address>()?)
        .value(U256::from(1000000000000000000u64)); // 1 ETH

    let tx_hash = client.send_transaction(tx, None).await?.await?;
    println!("Transaction sent: {:?}", tx_hash);
    Ok(())
}

// Alloy (NEW)
use alloy::{
    providers::{Provider, ProviderBuilder},
    signers::local::PrivateKeySigner,
    rpc::types::TransactionRequest,
    primitives::{Address, U256},
    network::TransactionBuilder,
};

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let signer: PrivateKeySigner = "your-private-key".parse()?;
    let provider = ProviderBuilder::new()
        .wallet(signer)
        .connect_http("https://eth.llamarpc.com".parse()?);

    let tx = TransactionRequest::default()
        .with_to(address!("d8dA6BF26964aF9D7eEd9e03E53415D37aA96045"))
        .with_value(U256::from(1000000000000000000u64)); // 1 ETH

    let tx_hash = provider.send_transaction(tx).await?.watch().await?;
    println!("Transaction sent: {:?}", tx_hash);
    Ok(())
}
```

### Migration Checklist

1. **Update Dependencies**
   ```toml
   # Remove
   # ethers = "2.0"

   # Add
   alloy = { version = "1.0", features = ["full"] }
   eyre = "0.6"  # Better error handling
   ```

2. **Update Imports**
   - Replace `ethers::types::*` with `alloy::primitives::*` for basic types
   - Replace `ethers::providers::*` with `alloy::providers::*`
   - Replace `ethers::signers::*` with `alloy::signers::*`
   - Replace `ethers::contract::*` with `alloy::contract::*`

3. **Update Type Names**
   - `H160`, `H256`, etc. → `B160`, `B256`, etc.
   - `BlockNumber` → `BlockNumberOrTag`
   - Update address and hash type usage

4. **Update Provider Pattern**
   - Replace middleware stack with `ProviderBuilder` and fillers
   - Use `with_recommended_fillers()` for common functionality
   - Add wallet to provider with `.wallet(signer)`

5. **Update Contract Bindings**
   - Replace `abigen!` with `sol!` macro
   - Add `#[sol(rpc)]` attribute for contract generation
   - Update contract instantiation pattern

6. **Update Error Handling**
   - Consider using `eyre` for better error ergonomics
   - Update error handling patterns for new API

### Performance Benefits After Migration

- **60% faster** U256 operations
- **10x faster** ABI encoding/decoding with `sol!` macro
- **Better type safety** with compile-time contract bindings
- **Improved async patterns** with modern Rust async/await
- **Modular architecture** with fillers and layers for customization

</migrate_from_ethers>
````

## Why Alloy?

Alloy is the next-generation Rust toolkit for Ethereum development and a complete rewrite of [ethers-rs](https://www.gakonst.com/ethers-rs/getting-started/intro.html). Alloy offers a modular, high-performance, and developer-friendly experience for building on EVM-compatible chains.
It addresses the various pain points of existing tooling in the Rust Ethereum ecosystem, such as perfomance bottlenecks, cumbersome APIs and having to deal with feature flag that bloat your application.

---

It provides a complete toolkit for Ethereum development in Rust:

- **Seamless smart contract interactions**: The `sol!` macro enables you to parse Solidity syntax directly in Rust code, simplifying contract interactions.

- **Simplified RPC Provider Usage**: Alloy enables you to connect to an EVM node in a simple and intuitive way.

- **Multi-Chain Support**: The `Network` trait allows seamless integration with any EVM-compatible chain without feature flags.

- **Layered Architecture**: Replaces monolithic middleware with composable layers and fillers, enhancing modularity and clarity.

- **Optimized Primitives**: Alloy's rewritten core components deliver major performance gains across key Ethereum operations such as ABI encoding/decoding, U256 operations, and RLP encoding and decoding.

### Benchmarks

Alloy's performance improvements are demonstrated through several key benchmarks.

1. **ABI Encoding**: Measures the speed of encoding Solidity contract data (both static and dynamic types) into the Ethereum ABI format, which is required for making contract calls and sending transactions. For the purpose of this benchmark, we are encoding the Uniswap V2 `swap` function.

   {" "}

   <br />

   ```solidity
   // Benchmarks encode the calldata for this method
   function swap(uint amount0Out, uint amount1Out, address to, bytes
   calldata data) external;

   ```

   <br />

   |             | Ethers    | Alloy      | Speedup       |
   | :---------- | :-------- | :--------- | :------------ |
   | **Static**  | `1.12 μs` | `90.89 ns` | 🚀 **12.32x** |
   | **Dynamic** | `2.20 μs` | `1.88 μs`  | ✅ **1.17x**  |

2. **U256 Operations: Uniswap V2 Swap Calculations**: U256 Math is fairly common in EVM land, specially when interacting with DeFi protocols. For this benchmark we shall calculate the token `amountIn` and `amountOut` necessary for swapping.

   {" "}

   <br />

   |               | Ethers      | Alloy       | Speedup      |
   | :------------ | :---------- | :---------- | :----------- |
   | **amountIn**  | `512.47 ns` | `216.32 ns` | 🚀 **2.37x** |
   | **amountOut** | `53.82 ns`  | `18.19 ns`  | 🚀 **2.96x** |

3. **RLP Encoding/Decoding**: Measures the speed of encoding and decoding data using Recursive Length Prefix (RLP), a serialization method used throughout Ethereum (e.g., for blocks and transactions). For this benchmark, we shall RLP encode and decode a simple struct.

   ```rust
   // Derive the necessary traits
   #[derive(alloy_rlp::RlpEncodable, alloy_rlp::RlpDecodable)]
   #[derive(rlp_derive::RlpDecodable, rlp_derive::RlpEncodable)]
   pub struct MyStruct {
     a: u128,
     b: Vec<u8>,
   }
   ```

   <br />

   |              | Parity-Rlp | Alloy-Rlp  | Speedup      |
   | :----------- | :--------- | :--------- | :----------- |
   | **Encoding** | `86.70 ns` | `26.88 ns` | 🚀 **3.23x** |
   | **Decoding** | `88.79 ns` | `21.43 ns` | 🚀 **4.14x** |

Complete benchmarks and their source code can be found [here](https://github.com/alloy-rs/examples/tree/main/benches).

Alloy is already powering major projects like [Foundry](https://github.com/foundry-rs/foundry), [Reth](https://github.com/paradigmxyz/reth), [Arbitrum Stylus](https://github.com/OffchainLabs/stylus-sdk-rs), [OP Kona](https://github.com/op-rs/kona) and many more. It's designed to be the performant and stable foundation for the Rust Ethereum ecosystem.

### Conversions

You can use the following traits to easily convert between ethers-rs and Alloy types.

```rust
use alloy_primitives::{Address, Bloom, Bytes, B256, B64, I256, U256, U64};
use alloy_rpc_types::{AccessList, AccessListItem, BlockNumberOrTag};
use alloy_signer_wallet::LocalWallet;
use ethers_core::types::{
    transaction::eip2930::{
        AccessList as EthersAccessList, AccessListItem as EthersAccessListItem,
    },
    BlockNumber, Bloom as EthersBloom, Bytes as EthersBytes, H160, H256, H64, I256 as EthersI256,
    U256 as EthersU256, U64 as EthersU64,
};

pub trait ToAlloy {
    /// The corresponding Alloy type.
    type To;

    /// Converts the Ethers type to the corresponding Alloy type.
    fn to_alloy(self) -> Self::To;
}

pub trait ToEthers {
    /// The corresponding Ethers type.
    type To;

    /// Converts the Alloy type to the corresponding Ethers type.
    fn to_ethers(self) -> Self::To;
}

impl ToAlloy for EthersBytes {
    type To = Bytes;

    #[inline(always)]
    fn to_alloy(self) -> Self::To {
        Bytes(self.0)
    }
}

impl ToAlloy for H64 {
    type To = B64;

    #[inline(always)]
    fn to_alloy(self) -> Self::To {
        B64::new(self.0)
    }
}

impl ToAlloy for H160 {
    type To = Address;

    #[inline(always)]
    fn to_alloy(self) -> Self::To {
        Address::new(self.0)
    }
}

impl ToAlloy for H256 {
    type To = B256;

    #[inline(always)]
    fn to_alloy(self) -> Self::To {
        B256::new(self.0)
    }
}

impl ToAlloy for EthersBloom {
    type To = Bloom;

    #[inline(always)]
    fn to_alloy(self) -> Self::To {
        Bloom::new(self.0)
    }
}

impl ToAlloy for EthersU256 {
    type To = U256;

    #[inline(always)]
    fn to_alloy(self) -> Self::To {
        U256::from_limbs(self.0)
    }
}

impl ToAlloy for EthersI256 {
    type To = I256;

    #[inline(always)]
    fn to_alloy(self) -> Self::To {
        I256::from_raw(self.into_raw().to_alloy())
    }
}

impl ToAlloy for EthersU64 {
    type To = U64;

    #[inline(always)]
    fn to_alloy(self) -> Self::To {
        U64::from_limbs(self.0)
    }
}

impl ToAlloy for u64 {
    type To = U256;

    #[inline(always)]
    fn to_alloy(self) -> Self::To {
        U256::from(self)
    }
}

impl ToEthers for alloy_signer_wallet::LocalWallet {
    type To = ethers_signers::LocalWallet;

    fn to_ethers(self) -> Self::To {
        ethers_signers::LocalWallet::new_with_signer(
            self.signer().clone(),
            self.address().to_ethers(),
            self.chain_id().unwrap(),
        )
    }
}

impl ToEthers for Vec<LocalWallet> {
    type To = Vec<ethers_signers::LocalWallet>;

    fn to_ethers(self) -> Self::To {
        self.into_iter().map(ToEthers::to_ethers).collect()
    }
}

impl ToAlloy for EthersAccessList {
    type To = AccessList;
    fn to_alloy(self) -> Self::To {
        AccessList(self.0.into_iter().map(ToAlloy::to_alloy).collect())
    }
}

impl ToAlloy for EthersAccessListItem {
    type To = AccessListItem;

    fn to_alloy(self) -> Self::To {
        AccessListItem {
            address: self.address.to_alloy(),
            storage_keys: self.storage_keys.into_iter().map(ToAlloy::to_alloy).collect(),
        }
    }
}

impl ToEthers for Address {
    type To = H160;

    #[inline(always)]
    fn to_ethers(self) -> Self::To {
        H160(self.0 .0)
    }
}

impl ToEthers for B256 {
    type To = H256;

    #[inline(always)]
    fn to_ethers(self) -> Self::To {
        H256(self.0)
    }
}

impl ToEthers for U256 {
    type To = EthersU256;

    #[inline(always)]
    fn to_ethers(self) -> Self::To {
        EthersU256(self.into_limbs())
    }
}

impl ToEthers for U64 {
    type To = EthersU64;

    #[inline(always)]
    fn to_ethers(self) -> Self::To {
        EthersU64(self.into_limbs())
    }
}

impl ToEthers for Bytes {
    type To = EthersBytes;

    #[inline(always)]
    fn to_ethers(self) -> Self::To {
        EthersBytes(self.0)
    }
}

impl ToEthers for BlockNumberOrTag {
    type To = BlockNumber;

    #[inline(always)]
    fn to_ethers(self) -> Self::To {
        match self {
            BlockNumberOrTag::Number(n) => BlockNumber::Number(n.into()),
            BlockNumberOrTag::Earliest => BlockNumber::Earliest,
            BlockNumberOrTag::Latest => BlockNumber::Latest,
            BlockNumberOrTag::Pending => BlockNumber::Pending,
            BlockNumberOrTag::Finalized => BlockNumber::Finalized,
            BlockNumberOrTag::Safe => BlockNumber::Safe,
        }
    }
}
```

### Reference

[ethers-rs](https://github.com/gakonst/ethers-rs/) has been deprecated in favor of [Alloy](https://github.com/alloy-rs/) and [Foundry](https://github.com/foundry-rs/).

The following is a reference guide for finding the migration path for your specific crate, dependency or information source.

#### Documentation

- Book: [`ethers-rs/book`](https://github.com/gakonst/ethers-rs/tree/master/book) `->` [`alloy-rs/book`](https://github.com/alloy-rs/book)

#### Examples

- Examples: [`ethers-rs/examples`](https://github.com/gakonst/ethers-rs/tree/master/examples) `->` [`alloy-rs/examples`](https://github.com/alloy-rs/examples)

#### Crates

- Meta-crate: [`ethers`](https://github.com/gakonst/ethers-rs/tree/master/ethers) `->` [`alloy`](https://github.com/alloy-rs/alloy/tree/main/crates/alloy)
- Address book: [`ethers::addressbook`](https://github.com/gakonst/ethers-rs/tree/master/ethers-addressbook) `->` Not planned
- Compilers: [`ethers::solc`](https://github.com/gakonst/ethers-rs/tree/master/ethers-solc) `->` [`foundry-compilers`](https://github.com/foundry-rs/compilers)
- Contract: [`ethers::contract`](https://github.com/gakonst/ethers-rs/tree/master/ethers-contract) `->` [`alloy::contract`](https://github.com/alloy-rs/alloy/tree/main/crates/contract)
- Core: [`ethers::core`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core) `->` [`alloy::core`](https://github.com/alloy-rs/core)
  - Types: [`ethers::core::types::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types) `->` See [Types](#types) section
- Etherscan: [`ethers::etherscan`](https://github.com/gakonst/ethers-rs/tree/master/ethers-etherscan) `->` [`foundry-block-explorers`](https://github.com/foundry-rs/block-explorers)
- Middleware: [`ethers::middleware`](https://github.com/gakonst/ethers-rs/tree/master/ethers-middleware) `->` Fillers [`alloy::provider::{fillers, layers}`](https://github.com/alloy-rs/alloy/tree/main/crates/provider/src)
  - Gas oracle: [`ethers::middleware::GasOracleMiddleware`](https://github.com/gakonst/ethers-rs/tree/master/ethers-middleware/src/gas_oracle/middleware.rs) `->` Gas filler [`alloy::provider::GasFiller`](https://github.com/alloy-rs/examples/tree/main/examples/fillers/examples/gas_filler.rs)
  - Gas escalator: [`ethers::middleware::GasEscalatorMiddleware`](https://github.com/gakonst/ethers-rs/tree/master/ethers-middleware/src/gas_escalator) `->` Not planned
  - Transformer: [`ethers::middleware::TransformerMiddleware`](https://github.com/gakonst/ethers-rs/tree/master/ethers-middleware/src/transformer) `->` Not planned
  - Policy: [`ethers::middleware::policy::*`](https://github.com/gakonst/ethers-rs/blob/master/ethers-middleware/src/policy.rs) `->` Not planned
  - Timelag: [`ethers::middleware::timelag::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-middleware/src/timelag) `->` Not planned
  - Nonce manager: [`ethers::middleware::NonceManagerMiddleware`](https://github.com/gakonst/ethers-rs/tree/master/ethers-middleware/src/nonce_manager.rs) `->` Nonce filler [`alloy::provider::NonceFiller`](https://github.com/alloy-rs/alloy/tree/main/crates/provider/src/fillers/nonce.rs)
  - Signer: [`ethers::middleware::Signer`](https://github.com/gakonst/ethers-rs/tree/master/ethers-middleware/src/signer.rs) `->` Wallet filler [`alloy::provider::WalletFiller`](https://github.com/alloy-rs/alloy/tree/main/crates/provider/src/fillers/wallet.rs)
- Providers: [`ethers::providers`](https://github.com/gakonst/ethers-rs/tree/master/ethers-providers) `->` Provider [`alloy::providers`](https://github.com/alloy-rs/alloy/tree/main/crates/provider)
- Transports: [`ethers::providers::transports`](https://github.com/gakonst/ethers-rs/tree/master/ethers-providers/src/rpc/transports) `->` [`alloy::transports`](https://github.com/alloy-rs/alloy/tree/main/crates/transport)
  - HTTP: [`ethers::providers::Http`](https://github.com/gakonst/ethers-rs/tree/master/ethers-providers/src/rpc/transports/http.rs) `->` [`alloy::transports::http`](https://github.com/alloy-rs/alloy/tree/main/crates/transport-http)
  - IPC: [`ethers::providers::Ipc`](https://github.com/gakonst/ethers-rs/tree/master/ethers-providers/src/rpc/transports/ipc.rs) `->` [`alloy::transports::ipc`](https://github.com/alloy-rs/alloy/tree/main/crates/transport-ipc)
  - WS: [`ethers::providers::Ws`](https://github.com/gakonst/ethers-rs/tree/master/ethers-providers/src/rpc/transports/ws) `->` [`alloy::transports::ws`](https://github.com/alloy-rs/alloy/tree/main/crates/transport-ws)
- Signers: [`ethers::signers`](https://github.com/gakonst/ethers-rs/tree/master/ethers-signers) `->` Signer [`alloy::signers`](https://github.com/alloy-rs/alloy/tree/main/crates/signer)
  - AWS: [`ethers::signers::aws::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-signers/src/aws) `->` [`alloy::signers::aws`](https://github.com/alloy-rs/alloy/tree/main/crates/signer-aws)
  - Ledger: [`ethers::signers::ledger::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-signers/src/ledger) `->` [`alloy::signers::ledger`](https://github.com/alloy-rs/alloy/tree/main/crates/signer-ledger)
  - Trezor: [`ethers::signers::trezor::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-signers/src/trezor) `->` [`alloy::signer::trezor`](https://github.com/alloy-rs/alloy/tree/main/crates/signer-trezor)
  - Wallet: [`ethers::signers::wallet::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-signers/src/wallet) `->` [`alloy::signer::local`](https://github.com/alloy-rs/alloy/tree/main/crates/signer-local)

#### Types

##### Primitives

- Address: [`ethers::types::Address`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::Address`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- U64: [`ethers::types::U64`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::U64`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- U128: [`ethers::types::U128`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::U128`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- U256: [`ethers::types::U256`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::U256`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- U512: [`ethers::types::U512`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::U512`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- H32: [`ethers::types::H32`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::aliases::B32`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- H64: [`ethers::types::H64`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::B64`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- H128: [`ethers::types::H128`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::B128`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- H160: [`ethers::types::H160`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::B160`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- H256: [`ethers::types::H256`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::B256`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- H512: [`ethers::types::H512`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::B512`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- Bloom: [`ethers::types::Bloom`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::Bloom`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- TxHash: [`ethers::types::TxHash`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) `->` [`alloy::primitives::TxHash`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)

Due to a [limitation](https://github.com/alloy-rs/core/issues/554#issuecomment-1978620017) in `ruint`, BigEndianHash [`ethers::types::BigEndianHash`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/mod.rs) can be expressed as follows:

```rust
use alloy_primitives::{U256, B256};
// `U256` => `B256`
let x = B256::from(u256);

// `B256` => `U256`
let x: U256 = b256.into();
let x = U256::from_be_bytes(b256.into())
```

Due to [Rust issue #50133](https://github.com/rust-lang/rust/issues/50133), the native `TryFrom` trait is not supported for `Uint`s. Instead, use [`UintTryFrom`](https://docs.rs/alloy/latest/alloy/primitives/ruint/trait.UintTryFrom.html) as follows:

```rust
use alloy_primitives::ruint::UintTryFrom;

let x: U512 = uint!(1234_U512);
let y: U256 = U256::uint_try_from(x).unwrap();

let num = U16::from(300);
// Wraps around the U16 value to fit it in the u8 type.
let x = num.wrapping_to::<u8>();
assert_eq!(x, 44);

// Saturates the expected type and returns the maximum value if the number is too large.
let y = num.saturating_to::<u8>();
assert_eq!(y, 255);

// Attempts to convert and panics if number is too large for the expected type.
let z = num.to::<u8>();
```

##### RPC

- Bytes: [`ethers::types::bytes::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/bytes.rs) `->` [`alloy::primitives::Bytes`](https://github.com/alloy-rs/core/tree/main/crates/primitives/src/lib.rs)
- Chains: [`ethers::types::Chain`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/chain.rs) `->` [`alloy-rs/chains`](https://github.com/alloy-rs/chains)
- ENS: [`ethers::types::ens`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/ens.rs) `->` [`alloy-ens`](https://github.com/alloy-rs/alloy/blob/main/crates/ens/src/lib.rs)
- Trace: [`ethers::types::trace::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/trace) `->` [`alloy::rpc::types::trace`](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-trace)
- {Block, Fee, Filter, Log, Syncing, Transaction, TxPool}: [`ethers::types::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types) `->` [`alloy::rpc::types::eth::*`](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-eth/src/lib.rs)
- Proof: [`ethers::types::proof::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/proof.rs) `->` Account [`alloy::rpc::types::eth::account::*`](https://github.com/alloy-rs/alloy/tree/main/crates/rpc-types-eth/src/lib.rs)
- Signature: [`ethers::types::signature::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/signature.rs) `->` [`alloy::primitives::Signature*`](https://github.com/alloy-rs/core/blob/main/crates/primitives/src/signature/mod.rs)
- Withdrawal [`ethers::types::withdrawal::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/withdrawal.rs) `->` EIP4895 [`alloy::eips::eip4895`](https://github.com/alloy-rs/alloy/tree/main/crates/eips/src/eip4895.rs)
- Opcode: [`ethers::types::opcode::*`](https://github.com/gakonst/ethers-rs/tree/master/ethers-core/src/types/opcode.rs) `->` [`syn-solidity`](https://github.com/alloy-rs/core/tree/main/crates/syn-solidity)

#### ABI

- Bindings: [`abigen!`](https://github.com/gakonst/ethers-rs/tree/51fe937f6515689b17a3a83b74a05984ad3a7f11/ethers-contract/ethers-contract-abigen) `->` [`sol!`](https://github.com/alloy-rs/core/tree/main/crates/sol-types), available on [`alloy::sol`](https://github.com/alloy-rs/alloy/blob/aea7e07b4b335a3a35e3870a6c277d397d0f3932/crates/alloy/src/lib.rs#L52-L64).

### Other breaking changes

- [Removal of the deprecated `Signature` type. `PrimitiveSignature` is now aliased to `Signature`](https://github.com/alloy-rs/core/pull/899)
- [Renaming methods in User-defined types (UDT)'s bindings and implementing `From` and `Into` traits for UDT's](https://github.com/alloy-rs/core/pull/905)
- [Bumping `getrandom` and `rand`](https://github.com/alloy-rs/core/pull/869)
- [Removal of `From<String>` for `Bytes`](https://github.com/alloy-rs/core/pull/907)

### HTTP Provider

The `Http` provider establishes an HTTP connection with a node, allowing you to send JSON-RPC requests to the node to fetch data, simulate calls, send transactions and much more.

#### Initializing an Http Provider

The recommended way of initializing a `Http` provider is by using the [`connect_http`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.connect_http) method on the [`ProviderBuilder`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html).

```rust
//! Example of creating an HTTP provider using the `connect_http` method on the `ProviderBuilder`.

use alloy::providers::{Provider, ProviderBuilder}; // [!code focus]
use std::error::Error;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Set up the HTTP transport which is consumed by the RPC client.
    let rpc_url = "https://reth-ethereum.ithaca.xyz/rpc".parse()?;

    // Create a provider with the HTTP transport using the `reqwest` crate.
    let provider = ProviderBuilder::new().connect_http(rpc_url); // [!code focus]

    Ok(())
}
```

### RPC Provider

A [`Provider`](https://docs.rs/alloy/latest/alloy/providers/trait.Provider.html) is an abstraction of a connection to the Ethereum network, providing a concise, consistent interface to standard Ethereum node functionality.

#### Provider Builder Pattern

The correct way of creating a [`Provider`](https://docs.rs/alloy/latest/alloy/providers/trait.Provider.html) is through the [`ProviderBuilder`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html), a [builder](https://rust-unofficial.github.io/patterns/patterns/creational/builder.html).

Alloy provides concrete transport implementations for [`HTTP`](/rpc-providers/http-provider), [`WS` (WebSockets)](/rpc-providers/ws-provider) and [`IPC` (Inter-Process Communication)](/rpc-providers/ipc-provider.md), as well as higher level transports which wrap a single or multiple transports.

The [`connect`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.connect) method on the [`ProviderBuilder`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html) will automatically determine the connection type (`Http`, `Ws` or `Ipc`) depending on the format of the URL.

```rust showLineNumbers
//! Example of setting up a provider using the `.connect` method.

use alloy::providers::{Provider, ProviderBuilder}; // [!code focus]
use std::error::Error;

const RPC_URL: &str = "https://reth-ethereum.ithaca.xyz/rpc";
#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {

    // Instanties a provider using a string.
    let provider = ProviderBuilder::new().connect(RPC_URL).await?; // [!code focus]

    Ok(())
}
```

In order to instantiate a provider in synchronous settings use [`connect_http`](/rpc-providers/http-provider).

### IPC Provider

The [IPC (Inter-Process Communication)](https://en.wikipedia.org/wiki/Inter-process_communication) transport allows our program to communicate with a node over a local [Unix domain socket](https://en.wikipedia.org/wiki/Unix_domain_socket) or [Windows named pipe](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipes).

Using the IPC transport allows the ethers library to send JSON-RPC requests to the Ethereum client and receive responses, without the need for a network connection or HTTP server. This can be useful for interacting with a local Ethereum node that is running on the same network. Using IPC [is faster than RPC](https://github.com/0xKitsune/geth-ipc-rpc-bench), however you will need to have a local node that you can connect to.

#### Initializing an `Ipc` Provider

The recommended way of initializing an `Ipc` provider is by using the [`connect_ipc`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.connect_ipc) method on the [`ProviderBuilder`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html) with an [`IpcConnect`](https://docs.rs/alloy/latest/alloy/providers/struct.IpcConnect.html) configuration.

```rust
//! Example of creating an IPC provider using the `connect_ipc` method on the `ProviderBuilder`.

use alloy::providers::{IpcConnect, Provider, ProviderBuilder}; // [!code focus]
use std::error::Error;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Set up the IPC transport which is consumed by the RPC client.
    let ipc_path = "/tmp/reth.ipc";

    // Create the provider.
    let ipc = IpcConnect::new(ipc_path.to_string()); // [!code focus]
    let provider = ProviderBuilder::new().connect_ipc(ipc).await?; // [!code focus]

    Ok(())
}
```

### Understanding `Fillers`

[Fillers](https://docs.rs/alloy/latest/alloy/providers/fillers/index.html) decorate a [`Provider`](https://docs.rs/alloy/latest/alloy/providers/trait.Provider.html), filling transaction details before they are sent to the network. Fillers are used to set the nonce, gas price, gas limit, and other transaction details, and are called before any other layer.

#### Recommended Fillers

`RecommendedFillers` are enabled by default when initializing the `Provider` using `ProviderBuilder::new`.

```rust
// [!include ~/snippets/fillers/examples/recommended_fillers.rs]
```

#### Gas Filler

```rust
// [!include ~/snippets/fillers/examples/gas_filler.rs]
```

#### Nonce Filler

```rust
// [!include ~/snippets/fillers/examples/nonce_filler.rs]
```

#### Wallet Filler

```rust
// [!include ~/snippets/fillers/examples/wallet_filler.rs]
```

### WS Provider

The `Ws` provider establishes an WebSocket connection with a node, allowing you to send JSON-RPC requests to the node to fetch data, simulate calls, send transactions and much more. The `Ws` provider can be used with any Ethereum node that supports WebSocket connections. This allows programs to interact with the network in real-time without the need for HTTP polling for things like new block headers and filter logs.

#### Initializing a `Ws` Provider

The recommended way of initializing a `Ws` provider is by using the [`connect_ws`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html#method.connect_ws) method on the [`ProviderBuilder`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html) with a [`WsConnect`](https://docs.rs/alloy/latest/alloy/providers/struct.WsConnect.html) configuration.

```rust
//! Example of creating an WS provider using the `connect_ws` method on the `ProviderBuilder`.

use alloy::providers::{Provider, ProviderBuilder, WsConnect}; // [!code focus]
use std::error::Error;

#[tokio::main]
async fn main() -> eyre::Result<(), Box<dyn Error>> {
    // Set up the WS transport which is consumed by the RPC client.
    let rpc_url = "wss://eth-mainnet.g.alchemy.com/v2/your-api-key";

    // Create the provider.
    let ws = WsConnect::new(rpc_url); // [!code focus]
    let provider = ProviderBuilder::new().connect_ws(ws).await?; // [!code focus]

    Ok(())
}
```

#### Ws with Authorization

Similar to the other providers, you can also establish an authorized connection with a node via websockets.

```rust
// [!include ~/snippets/providers/examples/ws_with_auth.rs]
```

### Crafting Transactions

The simplest way to craft transactions is by using the [TransactionRequest](https://docs.rs/alloy-rpc-types/latest/alloy_rpc_types/transaction/struct.TransactionRequest.html) builder with the help of the [TransactionBuilder](https://docs.rs/alloy-network/latest/alloy_network/trait.TransactionBuilder.html). The `TransactionBuilder` provides a convenient interface for setting transaction fields such as recipient, value, gas, data and more, allowing you to easily construct different types of transactions whether you're sending ETH, calling a contract, or deploying a new contract.

Here's a short example of crafting a simple ETH transfer request:

```rust showLineNumbers
use alloy::{
    rpc::types::TransactionRequest,
    network::TransactionBuilder,
    primitives::{address, U256},
};

let tx = TransactionRequest::default()
    .with_to(address!("0x1234567890abcdef1234567890abcdef12345678"))
    .with_value(U256::from(1000));
```

This approach ensures your transaction is correctly structured and ready to be signed and submitted to the network. Note that we didn't set `from`, `nonce`, `chain_id`, or any gas related fields. These necessary fields are automatically filled by the `RecommendedFillers` before dispatch making our code less verbose. You can find more details about a transactions lifecycle and `RecommendedFillers` in the [Transaction Lifecycle](/transactions/transaction-lifecycle) post.

### Building specific transaction types

Alloy supports building a transaction request for all types of transactions via the same `TransactionRequest` builder we used above for crafting an ETH transfer. By default, the `TransactionRequest` attempts to build an [EIP1559](https://eips.ethereum.org/EIPS/eip-1559) transaction. However, you can also build other types of transactions by specifying the required type-specific fields or using specialized builders:

- **Legacy transactions:** Set the `gas_price` field. Omit EIP-1559 fields like `max_fee_per_gas` and `max_priority_fee_per_gas`.
- **EIP-2930 transactions:** Set the `access_list` field. This creates an access-list transaction.
- **EIP-1559 transactions:** Set the `max_fee_per_gas` and `max_priority_fee_per_gas` fields. Omit the `gas_price` field.
- **EIP-4844 transaction:** Use the `TransactionBuilder4844` to set blob specific fields using the `.with_blob_sidecar(..)` method.
- **EIP-7702 transaction:** Use the `TransactionBuilder7702` to set the authorization list using the `.with_authorization_list(..)` method.

#### Legacy Transactions

Setting the `gas_price` field hints the builder to construct a legacy transaction i.e `TxType = 0`.

```rust showLineNumbers
use alloy::{
    rpc::types::TransactionRequest,
    network::TransactionBuilder,
    primitives::{address, U256},
};

let tx = TransactionRequest::default()
    .with_to(address!("0x1234567890abcdef1234567890abcdef12345678"))
    .with_value(U256::from(10000))
    .with_gas_price(U256::from(100)); // [!code hl]
```

Find the full example [here](/transactions/sending-a-legacy-transaction).

#### EIP-2930 Transaction

[EIP-2930](https://eips.ethereum.org/EIPS/eip-2930) access list transaction (`TxType = 1`) can be built by setting the `access_list` field. You can learn more about the `AccessList` [here](https://docs.rs/alloy-rpc-types-eth/latest/alloy_rpc_types_eth/transaction/struct.AccessList.html).

```rust showLineNumbers
use alloy::{
    rpc::types::TransactionRequest,
    network::TransactionBuilder,
    primitives::{address, U256},
};

// ..snip..

let tx = TransactionRequest::default()
    .with_to(address!("0x1234567890abcdef1234567890abcdef12345678"))
    .with_value(U256::from(100))
    .with_input(calldata)
    .with_access_list(access_list); // [!code hl]
```

Find the full example [here](/transactions/using-access-lists).

#### EIP-1559 Transaction

By default the builder attempts to construct an [EIP1559](https://eips.ethereum.org/EIPS/eip-1559) transaction (`TxType = 2`). You can make this explicit by specifiying the priority gas fields.

```rust showLineNumbers
use alloy::{
    rpc::types::TransactionRequest,
    network::TransactionBuilder,
    primitives::{address, U256},
};

let tx = TransactionRequest::default()
    .with_to(address!("0x1234567890abcdef1234567890abcdef12345678"))
    .with_value(U256::from(10000))
    .with_max_fee_per_gas(1000) // [!code hl]
    .with_max_priority_fee_per_gas(100); // [!code hl]
```

Find the full example [here](/transactions/sending-an-EIP-1559-transaction).

#### EIP-4844 Transaction

EIP-4844 transactions (`TxType = 3`) are specific to Ethereum mainnet. One can build such transactions using the `TransactionBuilder4844` struct. This builder provides methods to set blob specific fields using the `.with_blob_sidecar(..)` method.

```rust showLineNumbers
use alloy::{
    rpc::types::TransactionRequest,
    network::{TransactionBuilder, TransactionBuilder4844},
    primitives::{address, U256},
};

// ..snip..

let tx = TransactionRequest::default()
    .with_to(address!("0x1234567890abcdef1234567890abcdef12345678"))
    .with_value(U256::from(1000))
    .with_blob_sidecar(blob_sidecar); // [!code hl]
```

Find the full example [here](/transactions/sending-an-EIP-4844-transaction).

#### Example: EIP-7702 Transaction

EIP-7702 transaction (`TxType = 4`)

```rust showLineNumbers
use alloy::{
    rpc::types::TransactionRequest,
    network::{TransactionBuilder, TransactionBuilder7702},
    primitives::{address, U256},
};

// .. snip..

let tx = TransactionRequest::default()
    .with_to(address!("0x1234567890abcdef1234567890abcdef12345678"))
    .with_value(U256::from(1000))
    .with_authorization_list(authorization_list); // [!code hl]
```

Find the full example [here](/transactions/sending-an-EIP-7702-transaction).

#### Inspecting Transaction Type Output

The `TransactionBuilder` provides methods inspect the transaction type while building it:

- **`.complete_type(tx_type: TxType)`**: Check if all necessary keys are present to build the specified type, returning a list of missing keys.
- **`.output_tx_type()`**: Returns the transaction type that this builder will attempt to build. This does not imply that the builder is ready to build.
- **`.output_tx_type_checked()`**: Like `.output_tx_type()`, Returns `None` if the builder is not ready to build.

### Sending a legacy transaction

Send a [pre-EIP-2718](https://eips.ethereum.org/EIPS/eip-2718) legacy transaction by specifying the `gas_price` field.

```rust
// [!include ~/snippets/transactions/examples/send_legacy_transaction.rs]
```

### Sending an EIP-1559 transaction

Send an [EIP-1559](https://eips.ethereum.org/EIPS/eip-1559) transaction by specifying the `max_fee_per_gas` and `max_priority_fee_per_gas` fields. This is also known as a dynamic or priority fee transaction.

```rust
// [!include ~/snippets/transactions/examples/send_eip1559_transaction.rs]
```

### Sending an EIP-4844 transaction

Send an [EIP-4844](https://eips.ethereum.org/EIPS/eip-4844) transaction by specifying the `blob_sidecar` field. This is also known as a blob transaction.

```rust
// [!include ~/snippets/transactions/examples/send_eip4844_transaction.rs]
```

### Sending an EIP-7702 transaction

Send an [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702) transaction by specifying the `authorization_list` field. This is also known as a set code transaction.

```rust
// [!include ~/snippets/transactions/examples/send_eip7702_transaction.rs]
```

### The transaction lifecycle

This article will walk you through the process of defining a transaction to send `100 wei` from `Alice` to `Bob`, signing the transaction and broadcasting the signed transaction to the Ethereum network.

Let's express our intent in the form of a [`TransactionRequest`](https://docs.rs/alloy/latest/alloy/rpc/types/eth/struct.TransactionRequest.html):

```rust
// Build a transaction to send 100 wei from Alice to Bob.
let tx = TransactionRequest::default()
    .with_from(alice)
    .with_to(bob)
    .with_nonce(nonce)
    .with_chain_id(chain_id)
    .with_value(U256::from(100))
    .with_gas_price(gas_price)
    .with_gas_limit(gas_limit);
```

#### Setup

First we will set up our environment:

We start by defining the RPC URL of our local Ethereum node [Anvil](https://github.com/foundry-rs/foundry/tree/master/crates/anvil) node.
If you do not have `Anvil` installed see the [Foundry](https://github.com/foundry-rs/foundry) [installation instructions](https://book.getfoundry.sh/getting-started/installation).

```rust
// Spin up a local Anvil node.
// Ensure `anvil` is available in $PATH.
let anvil = Anvil::new().try_spawn()?;

// Get the RPC URL.
let rpc_url = anvil.endpoint().parse()?;
```

```rust
// Alternatively you can use any valid RPC URL found on https://chainlist.org/
let rpc_url = "https://reth-ethereum.ithaca.xyz/rpc".parse()?;
```

Next let's define a `signer` for Alice. By default `Anvil` defines a mnemonic phrase: `"test test test test test test test test test test test junk"`. Make sure to not use this mnemonic phrase outside of testing environments. We add a signer to the `Provider` using the `.wallet` method which is responsible for signing the transactions.s

Derive the first key of the mnemonic phrase for `Alice`:

```rust
// Set up signer from the first default Anvil account (Alice).
let signer: PrivateKeySigner = anvil.keys()[0].clone().into();
```

Next lets grab the address of our users `Alice` and `Bob`:

```rust
// Create two users, Alice and Bob.
let alice = anvil.addresses()[0];
let bob = anvil.addresses()[1];
```

Next we can build the [`Provider`](https://docs.rs/alloy/latest/alloy/providers/trait.Provider.html) using the [`ProviderBuilder`](https://docs.rs/alloy/latest/alloy/providers/struct.ProviderBuilder.html).

```rust
// Create a provider with the signer.
// `ProviderBuilder::new` initializes the recommended fillers.
let provider = ProviderBuilder::new()
    .wallet(signer)
    // Previously, on_http
    .connect_http(rpc_url);
```

Note that the [ProviderBuilder](/rpc-providers/introduction) constructor `new` initializes the [RecommendedFillers](/rpc-providers/understanding-fillers).

Let's modify our original `TransactionRequest` to make use of the [RecommendedFiller](https://docs.rs/alloy/latest/alloy/providers/fillers/type.RecommendedFiller.html) installed on the `Provider` to automatically fill out transaction details.

The `RecommendedFillers` includes the following fillers:

- [GasFiller](https://docs.rs/alloy/latest/alloy/providers/fillers/struct.GasFiller.html)
- [BlobGasFiller](https://docs.rs/alloy-provider/latest/alloy_provider/fillers/struct.BlobGasFiller.html)
- [NonceFiller](https://docs.rs/alloy/latest/alloy/providers/fillers/struct.NonceFiller.html)
- [ChainIdFiller](https://docs.rs/alloy/latest/alloy/providers/fillers/struct.ChainIdFiller.html)

Because we are using `RecommendedFillers` for filling the `TransactionRequest` we only need a subset of the original fields:

```diff showLineNumbers
// Build a transaction to send 100 wei from Alice to Bob.
let tx = TransactionRequest::default()
-   .with_from(alice)
    .with_to(bob)
-   .with_nonce(nonce)
-   .with_chain_id(chain_id)
    .with_value(U256::from(100))
-   .with_gas_price(gas_price)
-   .with_gas_limit(gas_limit);
```

Changes to:

```rust showLineNumbers
// Build a transaction to send 100 wei from Alice to Bob.
// The `from` field is automatically filled to the first signer's address (Alice).
let tx = TransactionRequest::default()
    .with_to(bob)
    .with_value(U256::from(100));
```

Much better!

#### Signing and broadcasting the transaction

Given that we have configured a signer on our `Provider` we can sign the transaction locally and broadcast in a single line:

There are three ways to listen for transaction inclusion after broadcasting the transaction, depending on your requirements:

```rust
// Send the transaction and listen for the transaction to be broadcasted.
let pending_tx = provider.send_transaction(tx).await?.register().await?;
```

```rust
// Send the transaction and listen for the transaction to be included.
let tx_hash = provider.send_transaction(tx).await?.watch().await?;
```

```rust
// Send the transaction and fetch the receipt after the transaction was included.
let tx_receipt = provider.send_transaction(tx).await?.get_receipt().await?;
```

Let's dive deeper into what we just did.

By calling:

```rust
let tx_builder = provider.send_transaction(tx).await?;
```

The [`Provider::send_transaction`](https://docs.rs/alloy/latest/alloy/providers/trait.Provider.html#method.send_transaction) method returns a [`PendingTransactionBuilder`](https://docs.rs/alloy/latest/alloy/providers/struct.PendingTransactionBuilder.html) for configuring the pending transaction watcher.

On it we can for example, set the [`required_confirmations`](https://docs.rs/alloy/latest/alloy/providers/struct.PendingTransactionBuilder.html#method.set_required_confirmations) or set a [`timeout`](https://docs.rs/alloy/latest/alloy/providers/struct.PendingTransactionBuilder.html#method.set_timeout):

```rust
// Configure the pending transaction.
let pending_tx_builder = provider.send_transaction(tx)
    .await?
    .with_required_confirmations(2)
    .with_timeout(Some(std::time::Duration::from_secs(60)));
```

By passing the `TransactionRequest`, we populate any missing fields. This involves filling in details such as the nonce, chain ID, gas price, and gas limit:

```diff
// Build a transaction to send 100 wei from Alice to Bob.
let tx = TransactionRequest::default()
+   .with_from(alice)
    .with_to(bob)
+   .with_nonce(nonce)
+   .with_chain_id(chain_id)
    .with_value(U256::from(100))
+   .with_gas_price(gas_price)
+   .with_gas_limit(gas_limit);
```

As part [Wallet's `fill` method](https://docs.rs/alloy/latest/alloy/providers/fillers/trait.TxFiller.html#tymethod.fill), registered on the `Provider`, we build a signed transaction from the populated `TransactionRequest` using our signer, Alice.

At this point, the `TransactionRequest` becomes a `TransactionEnvelope`, ready to send across the network. By calling either [`register`](https://docs.rs/alloy/latest/alloy/providers/struct.PendingTransactionBuilder.html#method.register), [`watch`](https://docs.rs/alloy/latest/alloy/providers/struct.PendingTransactionBuilder.html#method.watch) or [`get_receipt`](https://docs.rs/alloy/latest/alloy/providers/struct.PendingTransactionBuilder.html#method.get_receipt) we can broadcast the transaction and track the status of the transaction.

For instance:

```rust
// Send the transaction and fetch the receipt after the transaction was included.
let tx_receipt = provider.send_transaction(tx).await?.get_receipt().await?;
```

The [`TransactionReceipt`](https://docs.rs/alloy/latest/alloy/rpc/types/struct.TransactionReceipt.html) provides a comprehensive record of the transaction's journey and outcome, including the transaction hash, block details, gas used, and addresses involved.

```rust
pub struct TransactionReceipt {
    // ...

    /// Transaction Hash.
    pub transaction_hash: TxHash,

    /// Index within the block.
    pub transaction_index: Option<TxIndex>,

    /// Hash of the block this transaction was included within.
    pub block_hash: Option<BlockHash>,

    /// Number of the block this transaction was included within.
    pub block_number: Option<BlockNumber>,

    /// Gas used by this transaction alone.
    pub gas_used: u128,

    /// Address of the sender.
    pub from: Address,

    /// Address of the receiver. None when its a contract creation transaction.
    pub to: Option<Address>,

    /// Contract address created, or None if not a deployment.
    pub contract_address: Option<Address>,

    // ...
}
```

This completes the journey of broadcasting a signed transaction. Once the transaction is included in a block, it becomes an immutable part of the Ethereum blockchain, ensuring that the transfer of `100 wei` from `Alice` to `Bob` is recorded permanently.

### Putting it all together

```rust
// [!include ~/snippets/transactions/examples/transfer_eth.rs]
```

### Using access lists

Send an [EIP-2930](https://eips.ethereum.org/EIPS/eip-2930) access list transaction by specifying the `access_list` field.

```rust
// [!include ~/snippets/transactions/examples/with_access_list.rs]
```

### Using the `TransactionBuilder`

The [`TransactionBuilder`](https://docs.rs/alloy/latest/alloy/network/trait.TransactionBuilder.html) is a network specific transaction builder configurable with `.with_*` methods.

Common fields one can configure are:

- [with_from](https://docs.rs/alloy/latest/alloy/network/trait.TransactionBuilder.html#method.with_from)
- [with_to](https://docs.rs/alloy/latest/alloy/network/trait.TransactionBuilder.html#method.with_to)
- [with_nonce](https://docs.rs/alloy/latest/alloy/network/trait.TransactionBuilder.html#method.with_nonce)
- [with_chain_id](https://docs.rs/alloy/latest/alloy/network/trait.TransactionBuilder.html#method.with_chain_id)
- [with_value](https://docs.rs/alloy/latest/alloy/network/trait.TransactionBuilder.html#method.with_value)
- [with_gas_limit](https://docs.rs/alloy/latest/alloy/network/trait.TransactionBuilder.html#method.with_gas_limit)
- [with_max_priority_fee_per_gas](https://docs.rs/alloy/latest/alloy/network/trait.TransactionBuilder.html#method.with_max_priority_fee_per_gas)
- [with_max_fee_per_gas](https://docs.rs/alloy/latest/alloy/network/trait.TransactionBuilder.html#method.with_max_fee_per_blob_gas)

It is generally recommended to use the builder pattern, as shown, rather than directly setting values (`with_to` versus `set_to`).

```rust
// Build a transaction to send 100 wei from Alice to Bob.
let tx = TransactionRequest::default()
        .with_to(bob)
        .with_nonce(0)
        .with_chain_id(provider.get_chain_id().await?)
        .with_value(U256::from(100))
        .with_gas_limit(21_000)
        .with_max_priority_fee_per_gas(1_000_000_000)
        .with_max_fee_per_gas(20_000_000_000);
```

### Initializing Big Numbers

```rust
// [!include ~/snippets/big-numbers/examples/create_instances.rs]
```

### Common conversions

```rust
// [!include ~/snippets/big-numbers/examples/conversion.rs]
```

### Comparisons and equivalence

```rust
// [!include ~/snippets/big-numbers/examples/comparison_equivalence.rs]
```

### Basic hash and address types

#### Bytes and Address

```rust
// [!include ~/snippets/primitives/examples/bytes_and_address_types.rs]
```

#### Hashing

```rust
// [!include ~/snippets/primitives/examples/hashing_functions.rs]
```

### Primitives

Alloy provides a set of performant EVM primitive types serving as the building block for crucial off-chain infrastructure and applications. These primitives are aided with various [macros](https://docs.rs/alloy-primitives/latest/alloy_primitives/#macros) and [aliases](https://docs.rs/alloy-primitives/latest/alloy_primitives/#reexports) to make them easier to work with. Here are the most basic ones that you will encounter:

#### Address

An Ethereum address, 20 bytes in length.

```rust
use alloy::primitives::{address, Address};


// The address! macro provides an intuitive way to instantiate the Address type from a string literal.
let expected = address!("0xd8da6bf26964af9d7eed9e03e53415d37aa96045"); // [!code hl]


let checksummed = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045";
//  Parse an Ethereum address, verifying its EIP-55 checksum.
let address = Address::parse_checksummed(checksummed, None).expect("valid checksum");
assert_eq!(address, expected);
```

There are many other ways to instantiate an `Address` type, you can find them [here](https://docs.rs/alloy-primitives/latest/alloy_primitives/struct.Address.html#method.from_word).

#### U256

256-bit unsigned integer type. This is a wrapper over [ruint::U256](https://docs.rs/ruint/latest/ruint/struct.Uint.html) with 4, 64 bit limbs.

This is necessary because the EVM operates on a 256-bit word size, which is different from the usual 32-bit or 64-bit of modern machines

`U256` implements the `std::ops::*` traits, meaning it supports all arithmetic operations.

```rust
use alloy::primitives::U256;

let a = U256::from(10);
let b = U256::from(2);

// addition
let sum = a + b;
assert_eq!(sum, U256::from(12));

// subtraction
let difference = a - b;
assert_eq!(difference, U256::from(8));

// multiplication
let product = a * b;
assert_eq!(product, U256::from(20));

// division
let quotient = a / b;
assert_eq!(quotient, U256::from(5));

// modulo
let remainder = a % b;
assert_eq!(remainder, U256::ZERO); // equivalent to `U256::from(0)`

// exponentiation
let power = a.pow(b);
assert_eq!(power, U256::from(100));
```

#### FixedBytes

A byte array of fixed length `[u8; N]`.

This type allows us to more tightly control serialization, deserialization. rlp encoding, decoding, and other type-level attributes for fixed-length byte arrays.

Users looking to prevent type-confusion between byte arrays of different lengths should use the `wrap_fixed_bytes!` macro to create a new fixed-length byte array type.

For example the aforementioned `Address` type is a wrapper around `FixedBytes<20>` built using the [wrap_fixed_bytes](https://docs.rs/alloy-primitives/latest/alloy_primitives/macro.wrap_fixed_bytes.html) macro.

```rust
use alloy::primitives::{FixedBytes, fixed_bytes, b256};
use alloy_primitives::{fixed_bytes, FixedBytes};

const ZERO: FixedBytes <0> = fixed_bytes!();
assert_eq!(ZERO, FixedBytes::ZERO);

// 32-bytes tx hash
let byte_array = fixed_bytes!("0xda7f09ac9b43acb4eb7d7c74dd5de20906ddd33fd4d82d8cb96997694b2d8e79");
let b256 = b256!("0xda7f09ac9b43acb4eb7d7c74dd5de20906ddd33fd4d82d8cb96997694b2d8e79");

assert_eq!(byte_array, b256);
```

### Using big numbers

Ethereum uses big numbers (also known as "bignums" or "arbitrary-precision integers") to represent certain values in its codebase and in blockchain transactions. This is necessary because the [EVM](https://ethereum.org/en/developers/docs/evm) operates on a 256-bit word size, which is different from the usual 32-bit or 64-bit of modern machines. This was chosen for the ease of use with 256-bit cryptography (such as [Keccak-256](https://github.com/ethereum/eth-hash) hashes or [secp256k1](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm) signatures).

It is worth noting that Ethereum is not the only blockchain or cryptocurrency that uses big numbers. Many other blockchains and cryptocurrencies also use big numbers to represent values in their respective systems.

#### Utilities

In order to create an application, it is often necessary to convert between the representation of values that is easily understood by humans (such as ether) and the machine-readable form that is used by contracts and math functions (such as wei). This is particularly important when working with Ethereum, as certain values, such as balances and gas prices, must be expressed in wei when sending transactions, even if they are displayed to the user in a different format, such as ether or gwei. To help with this conversion, `alloy::primitives::utils` provides two functions, [`parse_units`](https://github.com/alloy-rs/core/blob/main/crates/primitives/src/utils/units.rs) and [`format_units`](https://github.com/alloy-rs/core/blob/main/crates/primitives/src/utils/units.rs), which allow you to easily convert between human-readable and machine-readable forms of values. parse_units can be used to convert a string representing a value in ether, such as "1.1", into a big number in wei, which can be used in contracts and math functions. format_units can be used to convert a big number value into a human-readable string, which is useful for displaying values to users.

#### Math Operations

```rust
// [!include ~/snippets/big-numbers/examples/math_operations.rs]
```

#### Parsing and formatting units

```rust
// [!include ~/snippets/big-numbers/examples/math_utilities.rs]
```

import Template from '../../templates/advanced/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/advanced/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `any_network`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example any_network`

```rust
// [!include ~/snippets/advanced/examples/any_network.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/advanced/examples/any_network.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/advanced/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `decoding_json_abi`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example decoding_json_abi`

```rust
// [!include ~/snippets/advanced/examples/decoding_json_abi.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/advanced/examples/decoding_json_abi.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/advanced/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `encoding_dyn_abi`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example encoding_dyn_abi`

```rust
// [!include ~/snippets/advanced/examples/encoding_dyn_abi.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/advanced/examples/encoding_dyn_abi.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/advanced/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `encoding_sol_static`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example encoding_sol_static`

```rust
// [!include ~/snippets/advanced/examples/encoding_sol_static.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/advanced/examples/encoding_sol_static.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/advanced/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `foundry_fork_db`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example foundry_fork_db`

```rust
// [!include ~/snippets/advanced/examples/foundry_fork_db.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/advanced/examples/foundry_fork_db.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/advanced/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `reth_db_layer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example reth_db_layer`

```rust
// [!include ~/snippets/advanced/examples/reth_db_layer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/advanced/examples/reth_db_layer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/advanced/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `reth_db_provider`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example reth_db_provider`

```rust
// [!include ~/snippets/advanced/examples/reth_db_provider.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/advanced/examples/reth_db_provider.rs).

import Template from '../../templates/big-numbers/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/big-numbers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `comparison_equivalence`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example comparison_equivalence`

```rust
// [!include ~/snippets/big-numbers/examples/comparison_equivalence.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/big-numbers/examples/comparison_equivalence.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/big-numbers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `conversion`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example conversion`

```rust
// [!include ~/snippets/big-numbers/examples/conversion.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/big-numbers/examples/conversion.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/big-numbers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `create_instances`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example create_instances`

```rust
// [!include ~/snippets/big-numbers/examples/create_instances.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/big-numbers/examples/create_instances.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/big-numbers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `math_operations`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example math_operations`

```rust
// [!include ~/snippets/big-numbers/examples/math_operations.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/big-numbers/examples/math_operations.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/big-numbers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `math_utilities`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example math_utilities`

```rust
// [!include ~/snippets/big-numbers/examples/math_utilities.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/big-numbers/examples/math_utilities.rs).

import Template from '../../templates/comparison/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/comparison/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `compare_new_heads`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example compare_new_heads`

```rust
// [!include ~/snippets/comparison/examples/compare_new_heads.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/comparison/examples/compare_new_heads.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/comparison/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `compare_pending_txs`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example compare_pending_txs`

```rust
// [!include ~/snippets/comparison/examples/compare_pending_txs.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/comparison/examples/compare_pending_txs.rs).

import Template from '../../templates/contracts/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `arb_profit_calc`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example arb_profit_calc`

```rust
// [!include ~/snippets/contracts/examples/arb_profit_calc.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/arb_profit_calc.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `deploy_and_link_library`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example deploy_and_link_library`

```rust
// [!include ~/snippets/contracts/examples/deploy_and_link_library.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/deploy_and_link_library.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `deploy_from_artifact`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example deploy_from_artifact`

```rust
// [!include ~/snippets/contracts/examples/deploy_from_artifact.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/deploy_from_artifact.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `deploy_from_bytecode`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example deploy_from_bytecode`

```rust
// [!include ~/snippets/contracts/examples/deploy_from_bytecode.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/deploy_from_bytecode.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `deploy_from_contract`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example deploy_from_contract`

```rust
// [!include ~/snippets/contracts/examples/deploy_from_contract.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/deploy_from_contract.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `helpers`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example helpers`

```rust
// [!include ~/snippets/contracts/examples/helpers.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/helpers.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `interact_with_abi`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example interact_with_abi`

```rust
// [!include ~/snippets/contracts/examples/interact_with_abi.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/interact_with_abi.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `interact_with_contract_instance`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example interact_with_contract_instance`

```rust
// [!include ~/snippets/contracts/examples/interact_with_contract_instance.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/interact_with_contract_instance.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `jsonrpc_error_decoding`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example jsonrpc_error_decoding`

```rust
// [!include ~/snippets/contracts/examples/jsonrpc_error_decoding.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/jsonrpc_error_decoding.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `revert_decoding`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example revert_decoding`

```rust
// [!include ~/snippets/contracts/examples/revert_decoding.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/revert_decoding.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `simulation_uni_v2`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example simulation_uni_v2`

```rust
// [!include ~/snippets/contracts/examples/simulation_uni_v2.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/simulation_uni_v2.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `unknown_return_types`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example unknown_return_types`

```rust
// [!include ~/snippets/contracts/examples/unknown_return_types.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/unknown_return_types.rs).

import Template from '../../templates/fillers/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/fillers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `gas_filler`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example gas_filler`

```rust
// [!include ~/snippets/fillers/examples/gas_filler.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/fillers/examples/gas_filler.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/fillers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `nonce_filler`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example nonce_filler`

```rust
// [!include ~/snippets/fillers/examples/nonce_filler.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/fillers/examples/nonce_filler.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/fillers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `recommended_fillers`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example recommended_fillers`

```rust
// [!include ~/snippets/fillers/examples/recommended_fillers.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/fillers/examples/recommended_fillers.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/fillers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `urgent_filler`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example urgent_filler`

```rust
// [!include ~/snippets/fillers/examples/urgent_filler.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/fillers/examples/urgent_filler.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/fillers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `wallet_filler`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example wallet_filler`

```rust
// [!include ~/snippets/fillers/examples/wallet_filler.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/fillers/examples/wallet_filler.rs).

import Template from '../../templates/layers/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/layers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `delay_layer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example delay_layer`

```rust
// [!include ~/snippets/layers/examples/delay_layer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/layers/examples/delay_layer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/layers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `fallback_layer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example fallback_layer`

```rust
// [!include ~/snippets/layers/examples/fallback_layer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/layers/examples/fallback_layer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/layers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `hyper_http_layer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example hyper_http_layer`

```rust
// [!include ~/snippets/layers/examples/hyper_http_layer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/layers/examples/hyper_http_layer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/layers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `logging_layer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example logging_layer`

```rust
// [!include ~/snippets/layers/examples/logging_layer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/layers/examples/logging_layer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/layers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `retry_layer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example retry_layer`

```rust
// [!include ~/snippets/layers/examples/retry_layer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/layers/examples/retry_layer.rs).

import Template from '../../templates/node-bindings/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/node-bindings/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `anvil_deploy_contract`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example anvil_deploy_contract`

```rust
// [!include ~/snippets/node-bindings/examples/anvil_deploy_contract.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/node-bindings/examples/anvil_deploy_contract.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/node-bindings/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `anvil_fork_instance`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example anvil_fork_instance`

```rust
// [!include ~/snippets/node-bindings/examples/anvil_fork_instance.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/node-bindings/examples/anvil_fork_instance.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/node-bindings/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `anvil_fork_provider`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example anvil_fork_provider`

```rust
// [!include ~/snippets/node-bindings/examples/anvil_fork_provider.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/node-bindings/examples/anvil_fork_provider.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/node-bindings/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `anvil_local_instance`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example anvil_local_instance`

```rust
// [!include ~/snippets/node-bindings/examples/anvil_local_instance.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/node-bindings/examples/anvil_local_instance.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/node-bindings/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `anvil_local_provider`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example anvil_local_provider`

```rust
// [!include ~/snippets/node-bindings/examples/anvil_local_provider.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/node-bindings/examples/anvil_local_provider.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/node-bindings/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `anvil_set_storage_at`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example anvil_set_storage_at`

```rust
// [!include ~/snippets/node-bindings/examples/anvil_set_storage_at.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/node-bindings/examples/anvil_set_storage_at.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/node-bindings/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `geth_local_instance`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example geth_local_instance`

```rust
// [!include ~/snippets/node-bindings/examples/geth_local_instance.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/node-bindings/examples/geth_local_instance.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/node-bindings/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `reth_local_instance`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example reth_local_instance`

```rust
// [!include ~/snippets/node-bindings/examples/reth_local_instance.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/node-bindings/examples/reth_local_instance.rs).

import Template from '../../templates/primitives/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/primitives/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `bytes_and_address_types`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example bytes_and_address_types`

```rust
// [!include ~/snippets/primitives/examples/bytes_and_address_types.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/primitives/examples/bytes_and_address_types.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/primitives/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `hashing_functions`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example hashing_functions`

```rust
// [!include ~/snippets/primitives/examples/hashing_functions.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/primitives/examples/hashing_functions.rs).

import Template from '../../templates/providers/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `basic_provider`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example basic_provider`

```rust
// [!include ~/snippets/providers/examples/basic_provider.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/basic_provider.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `batch_rpc`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example batch_rpc`

```rust
// [!include ~/snippets/providers/examples/batch_rpc.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/batch_rpc.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `builder`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example builder`

```rust
// [!include ~/snippets/providers/examples/builder.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/builder.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `builtin`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example builtin`

```rust
// [!include ~/snippets/providers/examples/builtin.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/builtin.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `dyn_provider`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example dyn_provider`

```rust
// [!include ~/snippets/providers/examples/dyn_provider.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/dyn_provider.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `embed_consensus_rpc`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example embed_consensus_rpc`

```rust
// [!include ~/snippets/providers/examples/embed_consensus_rpc.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/embed_consensus_rpc.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `http`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example http`

```rust
// [!include ~/snippets/providers/examples/http.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/http.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `http_with_auth`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example http_with_auth`

```rust
// [!include ~/snippets/providers/examples/http_with_auth.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/http_with_auth.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `ipc`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example ipc`

```rust
// [!include ~/snippets/providers/examples/ipc.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/ipc.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `mocking`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example mocking`

```rust
// [!include ~/snippets/providers/examples/mocking.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/mocking.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `multicall`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example multicall`

```rust
// [!include ~/snippets/providers/examples/multicall.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/multicall.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `multicall_batching`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example multicall_batching`

```rust
// [!include ~/snippets/providers/examples/multicall_batching.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/multicall_batching.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `wrapped_provider`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example wrapped_provider`

```rust
// [!include ~/snippets/providers/examples/wrapped_provider.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/wrapped_provider.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `ws`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example ws`

```rust
// [!include ~/snippets/providers/examples/ws.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/ws.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/providers/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `ws_with_auth`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example ws_with_auth`

```rust
// [!include ~/snippets/providers/examples/ws_with_auth.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/providers/examples/ws_with_auth.rs).

import Template from '../../templates/queries/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/queries/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `query_contract_storage`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example query_contract_storage`

```rust
// [!include ~/snippets/queries/examples/query_contract_storage.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/queries/examples/query_contract_storage.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/queries/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `query_deployed_bytecode`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example query_deployed_bytecode`

```rust
// [!include ~/snippets/queries/examples/query_deployed_bytecode.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/queries/examples/query_deployed_bytecode.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/queries/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `query_logs`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example query_logs`

```rust
// [!include ~/snippets/queries/examples/query_logs.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/queries/examples/query_logs.rs).

import Template from '../../templates/sol-macro/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/sol-macro/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `all_derives`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example all_derives`

```rust
// [!include ~/snippets/sol-macro/examples/all_derives.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/sol-macro/examples/all_derives.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/contracts/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `deploy_from_contract`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example deploy_from_contract`

```rust
// [!include ~/snippets/contracts/examples/deploy_from_contract.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/contracts/examples/deploy_from_contract.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/sol-macro/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `decode_returns`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example decode_returns`

```rust
// [!include ~/snippets/sol-macro/examples/decode_returns.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/sol-macro/examples/decode_returns.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/sol-macro/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `events_errors`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example events_errors`

```rust
// [!include ~/snippets/sol-macro/examples/events_errors.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/sol-macro/examples/events_errors.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/sol-macro/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `extra_derives`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example extra_derives`

```rust
// [!include ~/snippets/sol-macro/examples/extra_derives.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/sol-macro/examples/extra_derives.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/sol-macro/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `structs_enums`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example structs_enums`

```rust
// [!include ~/snippets/sol-macro/examples/structs_enums.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/sol-macro/examples/structs_enums.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/sol-macro/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `user_defined_types`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example user_defined_types`

```rust
// [!include ~/snippets/sol-macro/examples/user_defined_types.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/sol-macro/examples/user_defined_types.rs).

import Template from '../../templates/subscriptions/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/subscriptions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `event_multiplexer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example event_multiplexer`

```rust
// [!include ~/snippets/subscriptions/examples/event_multiplexer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/subscriptions/examples/event_multiplexer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/subscriptions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `poll_logs`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example poll_logs`

```rust
// [!include ~/snippets/subscriptions/examples/poll_logs.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/subscriptions/examples/poll_logs.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/subscriptions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `subscribe_all_logs`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example subscribe_all_logs`

```rust
// [!include ~/snippets/subscriptions/examples/subscribe_all_logs.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/subscriptions/examples/subscribe_all_logs.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/subscriptions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `subscribe_blocks`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example subscribe_blocks`

```rust
// [!include ~/snippets/subscriptions/examples/subscribe_blocks.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/subscriptions/examples/subscribe_blocks.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/subscriptions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `subscribe_logs`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example subscribe_logs`

```rust
// [!include ~/snippets/subscriptions/examples/subscribe_logs.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/subscriptions/examples/subscribe_logs.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/subscriptions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `subscribe_pending_transactions`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example subscribe_pending_transactions`

```rust
// [!include ~/snippets/subscriptions/examples/subscribe_pending_transactions.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/subscriptions/examples/subscribe_pending_transactions.rs).

import Template from '../../templates/transactions/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `debug_trace_call_many`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example debug_trace_call_many`

```rust
// [!include ~/snippets/transactions/examples/debug_trace_call_many.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/debug_trace_call_many.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `decode_input`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example decode_input`

```rust
// [!include ~/snippets/transactions/examples/decode_input.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/decode_input.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `decode_receipt_log`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example decode_receipt_log`

```rust
// [!include ~/snippets/transactions/examples/decode_receipt_log.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/decode_receipt_log.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `encode_decode_eip1559`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example encode_decode_eip1559`

```rust
// [!include ~/snippets/transactions/examples/encode_decode_eip1559.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/encode_decode_eip1559.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `gas_price_usd`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example gas_price_usd`

```rust
// [!include ~/snippets/transactions/examples/gas_price_usd.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/blob/main/examples/transactions/examples/gas_price_usd.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `permit2_signature_transfer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example permit2_signature_transfer`

```rust
// [!include ~/snippets/transactions/examples/permit2_signature_transfer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/permit2_signature_transfer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `send_eip1559_transaction`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example send_eip1559_transaction`

```rust
// [!include ~/snippets/transactions/examples/send_eip1559_transaction.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/send_eip1559_transaction.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `send_eip4844_transaction`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example send_eip4844_transaction`

```rust
// [!include ~/snippets/transactions/examples/send_eip4844_transaction.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/send_eip4844_transaction.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `send_eip7702_transaction`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example send_eip7702_transaction`

```rust
// [!include ~/snippets/transactions/examples/send_eip7702_transaction.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/send_eip7702_transaction.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `send_legacy_transaction`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example send_legacy_transaction`

```rust
// [!include ~/snippets/transactions/examples/send_legacy_transaction.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/send_legacy_transaction.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `send_private_transaction`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example send_private_transaction`

```rust
// [!include ~/snippets/transactions/examples/send_private_transaction.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/send_private_transaction.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `send_raw_transaction`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example send_raw_transaction`

```rust
// [!include ~/snippets/transactions/examples/send_raw_transaction.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/send_raw_transaction.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `trace_call`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example trace_call`

```rust
// [!include ~/snippets/transactions/examples/trace_call.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/trace_call.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `trace_call_many`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example trace_call_many`

```rust
// [!include ~/snippets/transactions/examples/trace_call_many.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/trace_call_many.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `trace_transaction`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example trace_transaction`

```rust
// [!include ~/snippets/transactions/examples/trace_transaction.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/trace_transaction.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `transfer_erc20`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example transfer_erc20`

```rust
// [!include ~/snippets/transactions/examples/transfer_erc20.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/transfer_erc20.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `transfer_eth`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example transfer_eth`

```rust
// [!include ~/snippets/transactions/examples/transfer_eth.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/transfer_eth.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/transactions/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `with_access_list`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example with_access_list`

```rust
// [!include ~/snippets/transactions/examples/with_access_list.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/transactions/examples/with_access_list.rs).

import Template from '../../templates/wallets/README.mdx'

<Template />

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `aws_signer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example aws_signer`

```rust
// [!include ~/snippets/wallets/examples/aws_signer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/aws_signer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `create_keystore`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example create_keystore`

```rust
// [!include ~/snippets/wallets/examples/create_keystore.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/create_keystore.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `ethereum_wallet`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example ethereum_wallet`

```rust
// [!include ~/snippets/wallets/examples/ethereum_wallet.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/ethereum_wallet.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `gcp_signer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example gcp_signer`

```rust
// [!include ~/snippets/wallets/examples/gcp_signer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/gcp_signer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `keystore_signer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example keystore_signer`

```rust
// [!include ~/snippets/wallets/examples/keystore_signer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/keystore_signer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `ledger_signer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example ledger_signer`

```rust
// [!include ~/snippets/wallets/examples/ledger_signer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/ledger_signer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `mnemonic_signer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example mnemonic_signer`

```rust
// [!include ~/snippets/wallets/examples/mnemonic_signer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/mnemonic_signer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `private_key_signer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example private_key_signer`

```rust
// [!include ~/snippets/wallets/examples/private_key_signer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/private_key_signer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `sign_message`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example sign_message`

```rust
// [!include ~/snippets/wallets/examples/sign_message.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/sign_message.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `sign_permit_hash`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example sign_permit_hash`

```rust
// [!include ~/snippets/wallets/examples/sign_permit_hash.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/sign_permit_hash.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `trezor_signer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example trezor_signer`

```rust
// [!include ~/snippets/wallets/examples/trezor_signer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/trezor_signer.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `verify_message`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example verify_message`

```rust
// [!include ~/snippets/wallets/examples/verify_message.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/verify_message.rs).

{/_DO NOT EDIT THIS FILE. IT IS GENERATED BY RUNNING `./scripts/update.sh`
ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN
EDIT OR CREATE THIS TEMPLATE INSTEAD: ./vocs/docs/pages/templates/wallets/README.mdx
LATEST UPDATE: https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1
_/}

### Example: `yubi_signer`

To run this example:

- Clone the [examples](https://github.com/alloy-rs/examples) repository: `git clone git@github.com:alloy-rs/examples.git`
- Run: `cargo run --example yubi_signer`

```rust
// [!include ~/snippets/wallets/examples/yubi_signer.rs]
```

Find the source code on Github [here](https://github.com/alloy-rs/examples/tree/15c1d3e6e758d6a9dfe747200b5c8d12f5a027f1/examples/wallets/examples/yubi_signer.rs).

### Simply ABI encoding and decoding

- [ABI encoding function return structs](./encoding-return-structs.md)
- [Removing `validate: bool` from the `abi_decode` methods](./removing-validate-bool.md)

### Encoding return structs

[core#909](https://github.com/alloy-rs/core/pull/909) improves return type encoding by allowing to pass the return struct directly into `SolCall::abi_encode_returns`.

Consider the following:

```rust
sol! {
    function something() returns (uint256, address);
}
```

#### Before

A tuple would need to passed of the fields from return type, `somethingReturn`

```rust
let encoding = somethingCall::abi_encode_returns(&(somethingReturn._0, somethingReturn._1));
```

#### After

One can now pass the return struct directly without deconstructing it as a tuple.

```rust
let encoding = somethingCall::abi_encode_returns(&somethingReturn);
```

### Removing the `validate: bool` from the `abi_decode` methods

[core#863](https://github.com/alloy-rs/core/pull/863) removes the `validate: bool` parameter from the `abi_decode_*` methods. The behavior of these `abi_decode_*` methods is now equivalent to passing `validate = false`.

### sol! changes

- [Removing the `T` transport generic](./removing-T-generic.md)
- [Improving function return type](./improving-function-return-types.md)
- [Changes to function call bindings](./changes-to-function-call-bindings.md)
- [Changes to event bindings](./changes-to-event-bindings.md)
- [Changes to error bindings](./changes-to-error-bindings.md)

### Changes to error bindings

[core#883](https://github.com/alloy-rs/core/pull/883) makes similar changes to the error bindings that [core#884](https://github.com/alloy-rs/core/pull/884) did to function call bindings in the sense that the form of the generated type is dependent upon two factors:

1. Number of parameters the error has.
2. Whether the parameter is named or unnamed in case it has only **one** param

Consider the following example:

```rust
sol! {
   // No params/args
   error Some();
   // Exactly one unnamed param
   error Another(uint256);
   // Exactly one named param - bindings for this remain unchanged
   error YetAnother(uint256 a);
}
```

### Before

All of the above were generated as regular structs.

```rust
// Empty struct
pub struct SomeError { };

pub struct AnotherError {
    _0: U256
}

pub struct YetAnotherError {
    a: U256
}
```

### After

```rust

// Unit struct for error with no params
pub struct SomeError;

// Tuple struct for SINGLE UNNAMED param
pub struct AnotherError(pub U256);
```

Bindings remain **unchanged** for errors with **multiple params** and **single but named param**.

### Changes to event bindings

[core#885](https://github.com/alloy-rs/core/pull/885) makes changes to the event bindings in a breaking but very minimal way.
It changes the bindings for **only** events with no parameters

Consider the following event:

```rust
sol! {
    event Incremented();
}
```

#### Before

The generated struct was an empty struct like below:

```rust
pub struct Incremented { };
```

#### After

A unit struct is generated like below:

```rust
pub struct Incremented;
```

Bindings for events with parameters remain **unchanged**.

### Changes to function call bindings

With [core#884](https://github.com/alloy-rs/core/pull/884) the form of the generated call type (used for abi-encoding) is now dependent upon two factors:

1. Number of parameters/args does the function take
2. Whether the parameter is named or unnamed in case it has only **one** param

Consider the following:

```rust
sol! {
    // No params/args
    function totalSupply() returns (uint256)
    // Exactly one unnamed param
    function balanceOf(address) returns (uint256);
    // Multiple params - Bindings for this remain unchanged.
    function approve(address spender, uint256 amount) returns (bool);
}
```

#### Before

Generated bindings were independent of the number of parameters and names, and the following struct were generated for the above function calls

```rust
// A struct with no fields as there are no parameters.
pub struct totalSupplyCall { };
let encoding = totalSupplyCall { }.abi_encode();

pub struct balanceOfCall { _0: Address };
let encoding = balanceOfCall { _0: Address::ZERO }.abi_encode();
```

#### After

```rust
// A unit struct is generated when there are no parameters.
pub struct totalSupplyCall;
let encoding = totalSupplyCall.abi_encode();

// A tuple struct with a single value is generated in case of a SINGLE UNNAMED param.
pub struct balanceOfCall(pub Address);
let encoding = balanceOfCall(Address::ZERO).abi_encode();
```

Now if the parameter in `balanceOf` was named like so:

```rust
sol! {
    function balanceOf(address owner) returns (uint256);
}
```

Then a regular struct would be generated like before:

```rust, ignore
pub struct balanceOfCall { owner: Address };
```

Bindings for function calls with **multiple parameters** are **unchanged**.

### Improving function call return types

With the inclusion of [core#855](https://github.com/alloy-rs/core/pull/855) return values of function calls with a _singular_ value is more intuitive and easier to work with.

Consider the following example of reading the balance of an ERC20:

```rust
sol! {
    #[sol(rpc)]
    contract ERC20 {
        // Note: Only a single value is being returned
        function balanceOf(address) returns (uint256);
    }
}
```

### Before

Calling the `balanceOf` fn would return a struct `balanceOfReturn` which encapsulated the actual balance value.

```rust
// .. snip ..
let balance_return: balanceOfReturn = erc20.balanceOf(owner).await?;

let actual_balance = balance_return._0;
```

### After

Calling the `balanceOf` fn would now yield the balance directly instead of a struct wrapping it.

```rust
// .. snip ..
let balance: U256 = erc20.balanceOf(owner).await?;
```

It is important to note that this change only applies to function calls that have a **singular** return value.

Function calls that **return multiple values** have their return types **unchanged**, i.e they still return a struct with values inside it.

```rust
sol! {
    function multiValues() returns (uint256 a, address b, bytes c);
}

// The above function call will have the following return type.

pub struct multiValuesReturn {
    pub a: U256,
    pub b: Address,
    pub c: Bytes,
}
```

### Removing the `T` transport generic

Since [alloy#1859](https://github.com/alloy-rs/alloy/pull/1859) the `Provider` is independent of the `Transport`, making it easier to roll types that wrap the `Provider`. This improvement was reflected in the [`CallBuilder`](https://docs.rs/alloy-contract/latest/alloy_contract/struct.CallBuilder.html) type but not carried to the `sol!` macro bindings.

[core#865](https://github.com/alloy-rs/core/pull/865) removes the `T` transport generic from the `sol!` macro bindings, making the contract and RPC codegen cleaner.

This can be demonstrated using a simple example that wraps an `ERC20Instance` type.

#### Before

```rust
struct Erc20<P: Provider> {
    instance: ERC20Instance<(), P>,
}
```

#### After

```rust
struct Erc20<P: Provider> {
    instance: ERC20Instance<P>,
}
```

### Advanced

- [Using `AnyNetwork`](/examples/advanced/any_network)
- [Decoding with `json_abi`](/examples/advanced/decoding_json_abi)
- [Encoding with `dyn_abi`](/examples/advanced/encoding_dyn_abi)
- [Static encoding with `sol!`](/examples/advanced/encoding_sol_static)
- [Using `foundry-fork-db`](/examples/advanced/foundry_fork_db)
- [Wrapping `Provider` trait over `reth-db`](/examples/advanced/reth_db_provider)

### Big numbers

- [Comparison and equivalence](/examples/big-numbers/comparison_equivalence)
- [Conversion](/examples/big-numbers/conversion)
- [Creating instances](/examples/big-numbers/create_instances)
- [Math operations](/examples/big-numbers/math_operations)
- [Math utilities](/examples/big-numbers/math_utilities)

### Comparison

- [Compare block headers between providers](/examples/comparison/compare_new_heads)
- [Compare pending transactions between providers](/examples/comparison/compare_pending_txs)

### Contracts

- [Deploy from artifact](/examples/contracts/deploy_from_artifact)
- [Deploy from bytecode](/examples/contracts/deploy_from_bytecode)
- [Deploy from contract](/examples/contracts/deploy_from_contract)
- [Deploy and link library](/examples/contracts/deploy_and_link_library)
- [Interact with ABI](/examples/contracts/interact_with_abi)
- [Interact with contract instance](/examples/contracts/interact_with_contract_instance)
- [Handling unknown return types](/examples/contracts/unknown_return_types)
- [Decode revert](/examples/contracts/revert_decoding)

### Fillers

- [Gas estimation filler](/examples/fillers/gas_filler)
- [Nonce management filler](/examples/fillers/nonce_filler)
- [Recommended fillers](/examples/fillers/recommended_fillers)
- [Wallet management filler](/examples/fillers/wallet_filler)

### Layers

- [Fallback layer](/examples/layers/fallback_layer)
- [Hyper layer transport](/examples/layers/hyper_http_layer)
- [Request / response logging layer](/examples/layers/logging_layer)
- [Retry-backoff layer](/examples/layers/retry_layer)

### Node bindings

- [Deploy contract on local Anvil instance](/examples/node-bindings/anvil_deploy_contract)
- [Fork instance on Anvil](/examples/node-bindings/anvil_fork_instance)
- [Fork provider on Anvil](/examples/node-bindings/anvil_fork_provider)
- [Local instance on Anvil](/examples/node-bindings/anvil_local_instance)
- [Local provider on Anvil](/examples/node-bindings/anvil_local_provider)
- [Local provider on Geth](/examples/node-bindings/geth_local_instance)
- [Local provider on Reth](/examples/node-bindings/reth_local_instance)
- [Mock WETH balance with Anvil](/examples/node-bindings/anvil_set_storage_at)

### Primitives

- [Bytes and address types](/examples/primitives/bytes_and_address_types)
- [Hashing functions](/examples/primitives/hashing_functions)

### Providers

- [Builder](/examples/providers/builder)
- [Builtin](/examples/providers/builtin)
- [HTTP](/examples/providers/http)
- [HTTP with authentication](/examples/providers/http_with_auth)
- [Wrapping a Provider](/examples/providers/wrapped_provider)
- [WS](/examples/providers/ws)
- [IPC](/examples/providers/ipc)
- [Multicall Builder](/examples/providers/multicall)
- [Multicall Batch Layer](/examples/providers/multicall_batching)
- [Mocking a Provider](/examples/providers/mocking)
- [WS with authentication](/examples/providers/ws_with_auth)
- [JSON-RPC Batch Request](/examples/providers/batch_rpc)
- [DynProvider](/examples/providers/dyn_provider)

### Queries

- [Query contract storage](/examples/queries/query_contract_storage)
- [Query contract deployed bytecode](/examples/queries/query_deployed_bytecode)
- [Query logs](/examples/queries/query_logs)

### The `sol!` macro

- [Contract](/examples/sol-macro/contract)
- [Events and errors](/examples/sol-macro/events_errors)
- [Structs and enums](/examples/sol-macro/structs_enums)
- [User defined types](/examples/sol-macro/user_defined_types)
- [`all_derives` attribute](/examples/sol-macro/all_derives)
- [`extra_derives` attribute](/examples/sol-macro/extra_derives)

### Subscriptions

- [Watch and poll for contract event logs](/examples/subscriptions/poll_logs)
- [Subscribe and watch blocks](/examples/subscriptions/subscribe_blocks)
- [Subscribe and listen for specific contract event logs](/examples/subscriptions/subscribe_logs)
- [Subscribe and listen for all contract event logs](/examples/subscriptions/subscribe_all_logs)
- [Subscribe and listen to pending transactions in the public mempool](/examples/subscriptions/subscribe_pending_transactions)

### Transactions

- [Decode input](/examples/transactions/decode_input)
- [Encode and decode EIP-1559 transaction](/examples/transactions/encode_decode_eip1559)
- [Get gas price in USD](/examples/transactions/gas_price_usd)
- [Decode logs from transaction receipt](/examples/transactions/decode_receipt_log)
- [Send EIP-1559 transaction](/examples/transactions/send_eip1559_transaction)
- [Send EIP-4844 transaction](/examples/transactions/send_eip4844_transaction)
- [Send EIP-7702 transaction](/examples/transactions/send_eip7702_transaction)
- [Send legacy transaction](/examples/transactions/send_legacy_transaction)
- [Send private transaction using Flashbots Protect](/examples/transactions/send_private_transaction)
- [Sign and send a raw transaction](/examples/transactions/send_raw_transaction)
- [Simulate using `debug_traceCallMany`](/examples/transactions/debug_trace_call_many)
- [Simulate using `trace_callMany`](/examples/transactions/trace_call_many)
- [Trace call](/examples/transactions/trace_call)
- [Trace transaction](/examples/transactions/trace_transaction)
- [Transfer ERC20 token](/examples/transactions/transfer_erc20)
- [Transfer ETH](/examples/transactions/transfer_eth)
- [Send transaction with access list](/examples/transactions/with_access_list)
- [Transfer ERC20 token using a signed permit](/examples/transactions/permit2_signature_transfer)

### Wallets

- [AWS signer](/examples/wallets/aws_signer)
- [GCP signer](/examples/wallets/gcp_signer)
- [Ledger signer](/examples/wallets/ledger_signer)
- [Private key signer](/examples/wallets/private_key_signer)
- [Mnemonic signer](/examples/wallets/mnemonic_signer)
- [Sign message](/examples/wallets/sign_message)
- [Verify message](/examples/wallets/verify_message)
- [Sign permit hash](/examples/wallets/sign_permit_hash)
- [Trezor signer](/examples/wallets/trezor_signer)
- [Yubi signer](/examples/wallets/yubi_signer)
- [Keystore signer](/examples/wallets/keystore_signer)
- [Create keystore](/examples/wallets/create_keystore)

</user_prompt>

---

This guide provides comprehensive context for building Ethereum applications with Alloy. Use these patterns and examples as building blocks for generating production-ready Rust code that leverages Alloy's performance optimizations and type safety.

<migrate_from_ethers>

## Migrating from ethers-rs

[ethers-rs](https://github.com/gakonst/ethers-rs/) has been deprecated in favor of [Alloy](https://github.com/alloy-rs/) and [Foundry](https://github.com/foundry-rs/). This section provides comprehensive migration guidance.

### Crate Mapping

#### Core Components

```rust
// ethers-rs -> Alloy migration

// Meta-crate
use ethers::prelude::*;  // OLD
use alloy::prelude::*;   // NEW

// Providers
use ethers::providers::{Provider, Http, Ws, Ipc};  // OLD
use alloy::providers::{ProviderBuilder, Provider};  // NEW

// Signers
use ethers::signers::{LocalWallet, Signer};  // OLD
use alloy::signers::{local::PrivateKeySigner, Signer};  // NEW

// Contracts
use ethers::contract::{Contract, abigen};  // OLD
use alloy::contract::ContractInstance;     // NEW
use alloy::sol;  // NEW (replaces abigen!)

// Types
use ethers::types::{Address, U256, H256, Bytes};  // OLD
use alloy::primitives::{Address, U256, B256, Bytes};  // NEW

// RPC types
use ethers::types::{Block, Transaction, TransactionReceipt};  // OLD
use alloy::rpc::types::eth::{Block, Transaction, TransactionReceipt};  // NEW
```

#### Major Architectural Changes

**Providers and Middleware** → **Providers with Fillers**

```rust
// ethers-rs middleware pattern (OLD)
use ethers::{
    providers::{Provider, Http, Middleware},
    middleware::{gas_oracle::GasOracleMiddleware, nonce_manager::NonceManagerMiddleware},
    signers::{LocalWallet, Signer}
};

let provider = Provider::<Http>::try_from("https://eth.llamarpc.com")?;
let provider = GasOracleMiddleware::new(provider, EthGasStation::new(None));
let provider = NonceManagerMiddleware::new(provider, wallet.address());
let provider = SignerMiddleware::new(provider, wallet);

// Alloy filler pattern (NEW)
use alloy::{
    providers::{ProviderBuilder, Provider},
    signers::local::PrivateKeySigner,
};

let signer = PrivateKeySigner::from_bytes(&private_key)?;
let provider = ProviderBuilder::new()
    .with_recommended_fillers()  // Includes gas, nonce, and chain ID fillers
    .wallet(signer)              // Wallet filler for signing
    .connect_http("https://eth.llamarpc.com".parse()?);
```

**Contract Bindings** - `abigen!` → `sol!`

```rust
// ethers-rs abigen (OLD)
use ethers::contract::abigen;

abigen!(
    IERC20,
    r#"[
        function totalSupply() external view returns (uint256)
        function balanceOf(address account) external view returns (uint256)
        function transfer(address to, uint256 amount) external returns (bool)
        event Transfer(address indexed from, address indexed to, uint256 value)
    ]"#,
);

// Alloy sol! macro (NEW)
use alloy::sol;

sol! {
    #[allow(missing_docs)]
    #[sol(rpc)]
    contract IERC20 {
        function totalSupply() external view returns (uint256);
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);

        event Transfer(address indexed from, address indexed to, uint256 value);
    }
}
```

### Type Migrations

#### Primitive Types

```rust
// Hash types: H* -> B*
use ethers::types::{H32, H64, H128, H160, H256, H512};  // OLD
use alloy::primitives::{B32, B64, B128, B160, B256, B512};  // NEW

// Address remains the same name but different import
use ethers::types::Address;  // OLD
use alloy::primitives::Address;  // NEW

// Unsigned integers
use ethers::types::{U64, U128, U256, U512};  // OLD
use alloy::primitives::{U64, U128, U256, U512};  // NEW

// Bytes
use ethers::types::Bytes;  // OLD
use alloy::primitives::Bytes;  // NEW

// Specific type conversions
let h256: H256 = H256::random();  // OLD
let b256: B256 = B256::random();  // NEW

// U256 <-> B256 conversions
let u256 = U256::from(12345);
let b256 = B256::from(u256);  // U256 -> B256
let u256_back: U256 = b256.into();  // B256 -> U256
let u256_back = U256::from_be_bytes(b256.into());  // Alternative
```

#### RPC Types

```rust
// Block types
use ethers::types::{Block, Transaction, TransactionReceipt};  // OLD
use alloy::rpc::types::eth::{Block, Transaction, TransactionReceipt};  // NEW

// Filter and log types
use ethers::types::{Filter, Log, ValueOrArray};  // OLD
use alloy::rpc::types::eth::{Filter, Log};  // NEW

// Block number
use ethers::types::BlockNumber;  // OLD
use alloy::rpc::types::BlockNumberOrTag;  // NEW

let block_num = BlockNumber::Latest;  // OLD
let block_num = BlockNumberOrTag::Latest;  // NEW
```

### Conversion Traits for Migration

When migrating gradually, use conversion traits to bridge ethers-rs and Alloy types:

```rust
use alloy::primitives::{Address, Bytes, B256, U256};

// Conversion traits for gradual migration
pub trait ToAlloy {
    type To;
    fn to_alloy(self) -> Self::To;
}

pub trait ToEthers {
    type To;
    fn to_ethers(self) -> Self::To;
}

// Implement conversions for common types
impl ToAlloy for ethers::types::H160 {
    type To = Address;

    fn to_alloy(self) -> Self::To {
        Address::new(self.0)
    }
}

impl ToAlloy for ethers::types::H256 {
    type To = B256;

    fn to_alloy(self) -> Self::To {
        B256::new(self.0)
    }
}

impl ToAlloy for ethers::types::U256 {
    type To = U256;

    fn to_alloy(self) -> Self::To {
        U256::from_limbs(self.0)
    }
}

impl ToEthers for Address {
    type To = ethers::types::H160;

    fn to_ethers(self) -> Self::To {
        ethers::types::H160(self.0.0)
    }
}

// Usage in migration
let ethers_addr: ethers::types::H160 = ethers::types::H160::random();
let alloy_addr: Address = ethers_addr.to_alloy();
let back_to_ethers: ethers::types::H160 = alloy_addr.to_ethers();
```

### Complete Migration Examples

#### Basic Provider Setup

```rust
// ethers-rs (OLD)
use ethers::{
    providers::{Provider, Http, Middleware},
    types::Address,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let provider = Provider::<Http>::try_from("https://eth.llamarpc.com")?;
    let block_number = provider.get_block_number().await?;
    println!("Latest block: {}", block_number);
    Ok(())
}

// Alloy (NEW)
use alloy::{
    providers::{Provider, ProviderBuilder},
    primitives::Address,
};

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let provider = ProviderBuilder::new()
        .connect_http("https://eth.llamarpc.com".parse()?);

    let block_number = provider.get_block_number().await?;
    println!("Latest block: {}", block_number);
    Ok(())
}
```

#### Contract Interaction

```rust
// ethers-rs (OLD)
use ethers::{
    contract::{abigen, Contract},
    providers::{Provider, Http},
    types::{Address, U256},
};

abigen!(IERC20, "path/to/erc20.json");

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let provider = Provider::<Http>::try_from("https://eth.llamarpc.com")?;
    let contract_address = address!("A0b86a33E6441d1b3C0D2c9b1e3b6eE4c4d5e5e1");
    let contract = IERC20::new(contract_address, provider.into());

    let total_supply: U256 = contract.total_supply().call().await?;
    println!("Total supply: {}", total_supply);
    Ok(())
}

// Alloy (NEW)
use alloy::{
    providers::{Provider, ProviderBuilder},
    primitives::{Address, U256},
    sol,
};

sol! {
    #[allow(missing_docs)]
    #[sol(rpc)]
    contract IERC20 {
        function totalSupply() external view returns (uint256);
    }
}

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let provider = ProviderBuilder::new()
        .connect_http("https://eth.llamarpc.com".parse()?);

    let contract_address = address!("A0b86a33E6441d1b3C0D2c9b1e3b6eE4c4d5e5e1");
    let contract = IERC20::new(contract_address, provider);

    let total_supply = contract.totalSupply().call().await?;
    println!("Total supply: {}", total_supply._0);
    Ok(())
}
```

#### Transaction Sending

```rust
// ethers-rs (OLD)
use ethers::{
    providers::{Provider, Http, Middleware},
    signers::{LocalWallet, Signer},
    middleware::SignerMiddleware,
    types::{TransactionRequest, U256},
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let provider = Provider::<Http>::try_from("https://eth.llamarpc.com")?;
    let wallet: LocalWallet = "your-private-key".parse()?;
    let client = SignerMiddleware::new(provider, wallet);

    let tx = TransactionRequest::new()
        .to("0xrecipient".parse::<Address>()?)
        .value(U256::from(1000000000000000000u64)); // 1 ETH

    let tx_hash = client.send_transaction(tx, None).await?.await?;
    println!("Transaction sent: {:?}", tx_hash);
    Ok(())
}

// Alloy (NEW)
use alloy::{
    providers::{Provider, ProviderBuilder},
    signers::local::PrivateKeySigner,
    rpc::types::TransactionRequest,
    primitives::{Address, U256},
    network::TransactionBuilder,
};

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let signer: PrivateKeySigner = "your-private-key".parse()?;
    let provider = ProviderBuilder::new()
        .wallet(signer)
        .connect_http("https://eth.llamarpc.com".parse()?);

    let tx = TransactionRequest::default()
        .with_to(address!("d8dA6BF26964aF9D7eEd9e03E53415D37aA96045"))
        .with_value(U256::from(1000000000000000000u64)); // 1 ETH

    let tx_hash = provider.send_transaction(tx).await?.watch().await?;
    println!("Transaction sent: {:?}", tx_hash);
    Ok(())
}
```

### Migration Checklist

1. **Update Dependencies**

   ```toml
   # Remove
   # ethers = "2.0"

   # Add
   alloy = { version = "1.0", features = ["full"] }
   eyre = "0.6"  # Better error handling
   ```

2. **Update Imports**

   - Replace `ethers::types::*` with `alloy::primitives::*` for basic types
   - Replace `ethers::providers::*` with `alloy::providers::*`
   - Replace `ethers::signers::*` with `alloy::signers::*`
   - Replace `ethers::contract::*` with `alloy::contract::*`

3. **Update Type Names**

   - `H160`, `H256`, etc. → `B160`, `B256`, etc.
   - `BlockNumber` → `BlockNumberOrTag`
   - Update address and hash type usage

4. **Update Provider Pattern**

   - Replace middleware stack with `ProviderBuilder` and fillers
   - Use `with_recommended_fillers()` for common functionality
   - Add wallet to provider with `.wallet(signer)`

5. **Update Contract Bindings**

   - Replace `abigen!` with `sol!` macro
   - Add `#[sol(rpc)]` attribute for contract generation
   - Update contract instantiation pattern

6. **Update Error Handling**
   - Consider using `eyre` for better error ergonomics
   - Update error handling patterns for new API

### Performance Benefits After Migration

- **60% faster** U256 operations
- **10x faster** ABI encoding/decoding with `sol!` macro
- **Better type safety** with compile-time contract bindings
- **Improved async patterns** with modern Rust async/await
- **Modular architecture** with fillers and layers for customization

</migrate_from_ethers>
