# Bridging ETH contract flow

## High level overview

There are two parties at play which will interact with the `Bridge` contract, which is deployed on **both** Layer 1 (L1) and Layer 2 (L2):

- The initiator of the bridge request (calls `Bridge.sendMessage`).
- The relayer (calls `Bridge.processMessage`).

The initiator will start the request, making it known on the Bridge contract via a signal. The relayer will pick this request up and process it.

## Diving deeper

Let's go deeper into the steps that occur when bridging ETH from L1 to L2:

### Send message

User initiates a bridge transaction with `sendMessage` on the source chain which includes:

- `depositValue`, `callValue`, and `processingFee` -- these must sum to `msg.value`.
- The destination chain's ID (must be enabled via `Bridge.enableDestChain()`).

Inside the `sendMessage` call, the `msg.value` amount of Ether is sent to the L1 `EtherVault` contract. Next, a `signal` is created from the message, and a `key` is stored on the L1 bridge contract address. The `key` is a hash of the `signal` and the L1 bridge contract address. The `key` is stored on the `Bridge` contract with a value of `1`, and a `MessageSent` event is emitted for the relayer to pick up.

### Process message

The off-chain relayer picks up the event and **generates a proof from L1** -- this can be obtained with `eth_getProof` on the L1 bridge contract. This proof is sent along with the signal to `processMessage` on the L2 bridge contract.

The `processMessage` call will first check that the message has not been processed yet, this status is stored in the L1 bridge contract state as `messageStatus`. Next, the proof is checked during `processMessage`, inside of a method `isSignalReceived`. The proof demonstrates that the storage on the `Bridge` contract on L1 contains the `key` with a value of `1`. `LibTrieProof` takes the proof, the signal, and the message sender address to check the `key` is set on the L1 bridge contract state. This verifies that the message is sent on L1. Next, `isSignalReceived` gets the header hash on L2 of the header height specified in the proof. It then checks that this hash is equal to the hash specified in the proof. This will verify that the message is received on L2.

The `processMessage` call will then proceed to invoke the message call, which will actually take the Ether from the vault and send it to the specified address. If it succeeds, it will mark the message as "DONE" on the L1 bridge state. If it fails, it will mark the message as "RETRIABLE" and send the Ether back to the vault. Later, `retryMessage` can be called (`processMessage` cannot be called again for this message).

Finally, any unused funds are sent back to the user as a refund.
