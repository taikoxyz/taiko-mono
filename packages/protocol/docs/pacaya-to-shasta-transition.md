# Pacaya → Shasta Transition Plan

This document captures the current strategy for migrating the rollup from the Pacaya fork to Shasta using a **timestamp-gated activation** in the most secure and gas efficient way possible.

## TL;DR

- We rely on a timestamp for the fork activation, contrary to previous approaches of using block height.

- The inbox is deployed to a new address, with a different abi. **Client software and prover need to be aware of this new address**.
- The new Anchor contract is deployed behind a fork router, and it is the responsibility of the client to decide which functions to call(the router decides based on the function selector). **The client should call `anchorV3` before FORK_TIMESTAMP and `anchorV4` after**.
- The SignalService(both on L1 and L2) are deployed behind a fork router. The abi is the same(to maintain backwards compatibility with bridges). The router decides which SignalService to call based on the timestamp.

## Terminology

- **FORK_TIMESTAMP** – The L1 timestamp that determines when the fork should occur.
- **SAFETY_WINDOW** - The amount of seconds before `FORK_TIMESTAMP` proposers stop preconfing L2 blocks.
- **SHASTA_INITIALIZER** – The privileged address allowed to call `Inbox.activate` after the fork timestamp. It initializes the genesis state hash for the new inbox.

## Fork Implementation

The following paragraphs describe in more detail how each part of the protocol handles the fork and what client, prover and other software integrating should be aware of.

- **Inbox**: [Shasta inbox](../contracts/layer1/mainnet/MainnetInbox.sol) will be deployed as an upgradable contract **to a new address**. No fork router is used for proposals or proofs. The proposers are expected to call the new inbox for the new proposal after `FORK_TIMESTAMP` has passed. The shasta inbox needs to be activated with the latest state of the Pacaya inbox(which will not be proven on-chain by then, but will be known to ayone running a Taiko node). The `SHASTA_INITIALIZER` is the address authorized to do so. This can be done only once.  
  _Pacaya inbox remains callable through the existing router for legacy withdrawals and proof submissions(until the Pacaya batches are finalized)._  
  _The Taiko preconfer is the best entity to activate the inbox before submitting the first proposal. We can remove the rest of the preconfers during this period to ensure no one else proposes before the inbox is activated_  
  _Forced inclusions submitted before the fork and not processed before it will be lost, and need to be submitted again to the new inbox_

- **Anchor**: The Shasta [anchor contract](../contracts/layer2/core/Anchor.sol) will be deployed as an upgradable contract to a new address, but the entrypoint is kept using the [AnchorForkRouter](../contracts/layer2/core/AnchorForkRouter.sol). This fork router will be deployed to the existing Anchor address and route to the old and new implementation based on the function signature. Calls to the `anchorV3` will be routed to the Pacaya anchor and calls to `anchorV4` will be routed to the new shasta anchor.
  Preconfers need to deposit their bonds into the `BondManager` contract on L2 before their first turn to propose after `FORK_TIMESTAMP` to avoid their proposal being treated as a low bond proposal. This contract will be deployed with anticipation, so proposers can do this long before their turn to propose.
  **IMPORTANT: The `FORK_TIMESTAMP` refers to the L1 timestamp. Event if the Anchor is an L2 contract, proposers will start calling `anchorV4` after the timestamp is hit on L1**
  **The contract does not handle fork logic based on the timestamp, and it is up to the preconfer to decide which function to call based on the timestamp.**
  _Withdrawals will be available via the existing address_

- **Signal Service**: The [SignalService](../contracts/shared/signal/SignalService.sol) is deployed as an upgradable contract to a new address, but a fork router will be used. The new SignalService is abi compatible for sending and receiving signals with the Pacaya implementation to ensure backwards compatibility for bridges.  
  But between the time the new version is deployed and the fork activated we need to keep verification working with the old checkpoint mechanism. Because of that [SignalForkRouter](../contracts/shared/signal/SignalServiceForkRouter.sol) will be deployed to the existing SignalService address and redirect calls based on timestamp. Before `FORK_TIMESTAMP` it will send calls to the Pacaya implementation, and afterwards to the shasta implementation.
  _Note that on L2, `FORK_TIMESTAMP` might happen a few moments before or after L1. Because of this the fork on L2 for the SignalService will in practice happen at a different moment to its L1 counterpart, but this should not be an issue(some signals might fail to be verified on L2, but not more than that)_
  _Note that signals sent before the fork will still be available and can be verified, but a new merkle proof needs to be generated(this is because the checkpoints are different, so the old proof won't pass validation)_

## Steps

1. **Deploy Shasta contracts**
   Deploy Shasta inbox(with Taiko Labs multisig as the owner), anchor, signal service and other shasta contracts. Set `_genesisBlockHash = 0` on the inbox at deployment time. This sets the inbox to an empty state. **No proposals should happen to the inbox at this point**.
   The `FORK_TIMESTAMP` should already be set to the shasta fork timestamp.  
   **After this point proposers can deposit their bonds to the `BondManager` contract on L2**.

2. **Deploy Pacaya Fork Router with fork guard**
   Deploy a new implementation of the Pacaya Fork Router contract(which serves as the entry point for batch proposals) with an additional safe guard that prevents any proposals from happening after `FORK_TIMESTAMP`. This is a safety measure to ensure the old inbox state cannot be modified after the fork has occured. Changes for this have been implemented on this [PR](https://github.com/taikoxyz/taiko-mono/pull/20641).

3. **Deploy the fork routers**
   Now that both Pacaya and Shasta contracts are ready we can deploy the `AnchorForkRouter` and `SignalServiceForkRouter`. They will still route all calls to the Pacaya contracts.

   - `oldFork` must be set to the implementation address for both the SignalService and the Anchor. This is because the proxy will be upgraded to use the fork router code.
   - `newFork` should be set to the newly deployed shasta proxy contracts.

4. **Submit upgrade to the DAO**
   Submit an upgrade proposal to the DAO to:

   - upgrade the Pacaya Fork Router to the new implementation(with the added guard)
   - upgrade the SignalService(on both L1 and L2) to point to the new `SignalServiceForkRouter`
   - upgrade the Anchor(L2) to point to the new `AnchorForkRouter`

5. **Reduce the whitelist**
   A few minutes before the `FORK_TIMESTAMP` we remove every preconfer from the whitelist, except Taiko Labs. This ensures the first proposer after the fork is known and is controlled bythe same entity that will activate the inbox.

6. At least `SAFETY_WINDOW` seconds `FORK_TIMESTAMP` the proposer stops submitting proposals to the Pacaya Inbox. This ensures we have a reliable state for the transition. After this moment proposers should start preconfing with the new shasta block structure.

7. The `SHASTA_INITIALIZER` calls the activate function on the shasta inbox with the `_genesisBlockHash` set to the latest pacaya block hash.  
   _NOTE: This can be computed off-chain, and while it has not been proven yet, the `SHASTA_INITIALIZER` can ensure it will eventually be proven._  
   _NOTE: The `activate` function will be called manually, so that the genesis block hash can be verified before submitting. This will be verified by different members from the team before sending the tx._

8. The next preconfer submits their proposal to the new shasta inbox. At this point the fork has officially happened and all calls should be redirected to the new contracts.

9. After a few succesful proposal(s) from Taiko Labs proposer the rest of the preconfers that have their sidecars ready for shasta are added back to the whitelist.

10. After Shasta is stable for a few days a new proposal to upgrade the Anchor and the SignalService(both on L1 and L2) is submitted. This proposal removes the fork router to simplify the deployment and save gas.

11. Transfer the ownership of the new shasta inbox to the DAO. The rest of the contracts are already owned by the DAO.
