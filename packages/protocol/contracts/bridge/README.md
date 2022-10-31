# Bridging ETH contract flow

`contracts/bridge/Bridge.sol` is to be deployed on both the Layer 1 and Layer 2 chains.

1. User initiates a bridge transaction with `sendMessage` on the source chain which includes:
   - The amount to send
   - The destination chain's ID
   - The processing fee for the relayer
2. The funds are stored on the `EtherVault` contract and a `signal` is created by hashing the message with the L1 bridge contract address. The `signal` is stored on the `Bridge` contract, and a `MessageSent` event is emitted.
3. The off-chain relayer captures the event and:
   1. Generates a proof from L1 (see `LibTrieProof.test.ts` for how to generate one).
   2. Initiates `processMessage` on the destination chain which will verify the signal was sent and check that the message has not been processed already.
4. `processMessage` will verify the proof, and if valid will attempt to send Ether to `message.owner`, marking the message as "DONE". Else, the message will be marked as "RETRIABLE" and `retryMessage` will need to be called.
5. Any remaining funds are sent as a refund.
