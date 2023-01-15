# Bridging ETH contract flow

## High level overview

There are two parties at play which will interact with the `Bridge` contract, which is deployed on **both** the **source chain (srcChain)** and the **destination chain (destChain)**:

- The initiator of the bridge request (calls `Bridge.sendMessage`).
- The relayer (calls `Bridge.processMessage`).

The initiator will start the request, making it known on the Bridge contract via a signal. The relayer will pick this request up and process it.

## Diving deeper

Let's go deeper into the steps that occur when bridging ETH from srcChain to destChain:

### Send message

User initiates a bridge transaction with `sendMessage` on the source chain which includes:

- `depositValue`, `callValue`, and `processingFee` -- these must sum to `msg.value`.
- The destination chain's ID (must be enabled via setting `addressResolver` for `${chainID}.bridge`).

Inside the `sendMessage` call, the `msg.value` amount of Ether is sent to the srcChain `EtherVault` contract. Next, a `signal` is created from the message, and a `key` is stored on the srcChain bridge contract address. The `key` is a hash of the `signal` and the srcChain bridge contract address. The `key` is stored on the `Bridge` contract with a value of `1`, and a `MessageSent` event is emitted for the relayer to pick up.

### Process message

If the `processingFee` is set to 0, only the user can call `processMessage`. Otherwise, either the user or an off-chain relayer can process the message. Let's explain the next steps in the case of a relayer -- the user will have to do the same steps anyways. In the case of a relayer, the relayer picks up the event and **generates a proof from srcChain** -- this can be obtained with `eth_getProof` on the srcChain bridge contract. This proof is sent along with the signal to `processMessage` on the destChain bridge contract.

The `processMessage` call will first check that the message has not been processed yet, this status is stored in the srcChain bridge contract state as `messageStatus`. Next, the proof is checked during `processMessage`, inside of a method `isSignalReceived`. The proof demonstrates that the storage on the `Bridge` contract on srcChain contains the `key` with a value of `1`. `LibTrieProof` takes the proof, the signal, and the message sender address to check the `key` is set on the srcChain bridge contract state. This verifies that the message is sent on srcChain. Next, `isSignalReceived` gets the header hash on destChain of the header height specified in the proof. It then checks that this hash is equal to the hash specified in the proof. This will verify that the message is received on destChain.

The `processMessage` call will then proceed to invoke the message call, which will actually take the Ether from the vault and send it to the specified address. If it succeeds, it will mark the message as "DONE" on the srcChain bridge state. If it fails, it will mark the message as "RETRIABLE" and send the Ether back to the vault. Later, `retryMessage` can be called **only** by the user (`processMessage` cannot be called again for this message by the relayer).

Finally, any unused funds are sent back to the user as a refund.
