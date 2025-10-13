## Goal

The goal of this document is to outline a plan for the Pacaya->Shasta transition in the most secure and gas efficient way possible. **Since the Shasta Inbox contract will still be deployed with a whitelisted set of preconfers, we can make use of those security assumptions to simplify the transition and avoid having to do too much on-chain.**

## Terminology

- `FORK_BLOCK`: The L1 block where the Pacaya -> Shasta transition should happen
- `FORK_TIMESTAMP`: The timestamp of the `FORK_BLOCK`
- `SHASTA_INITIALIZER`: The address responsible for initializing the shasta inbox

## Should we have a fork router?

The fork router is intended to help a smooth transition between forks. But this is only possible if the storage layouts match and the transition can be made on-chain. In the case of shasta, the changes are all breaking and the benefits of a fork router are arguably much smaller.
The reasons why we might want to keep the fork router(or add a new one) are:

1. Address stability: The inbox's entrypoint does not change
2. Forward compatibility: Even if Shasta is a breaking upgrade, the next ones will likely not be. So deploying the inbox behind a fork router allows us to have smoother future upgrades.
   NOTE: we can always do this by upgrading the inbox in the future to a fork router, that then calls the new inbox.

## Pros and Cons

### Pros

1. Get rid of the fork router. This means less complexity, and more gas efficiency.
2. Remove any storage layout compatibility requirements with Pacaya. The inbox can simply be constructed as a standalone, new contract.
3. Remove the `withdrawBond` function from the inbox. This was added to ensure proposers could withdraw their Pacaya bonds. Instead proposers can withdraw via the old inbox(via the fork router).
4. Reduced contract size since we can get rid of `withdrawBond` and backwards compatibility entirely.

### Cons

1. Complete trust on the `SHASTA_INITIALIZER`. This address will be able to set any initial state they want. But if they choose the wrong `_genesisBlockHash` proposals won't be able to be proven afterwards. There might also not be a more trustless solution to this, since the storage slots are not compatible, it won't be possible to do an on-chain transition as with Ontake->Pacaya.
2. Time sensitive: The `SHASTA_INITIALIZER` needs to call `activate` after `FORK_BLOCK` and before the next proposal lands on-chain. Since we have a set of whitelisted proposers, we can be sure this does not happen before the fork (and we could even keep only Taiko as a preconfer during the transition period to guarantee this). This gives the `SHASTA_INITIALIZER` at least an epoch (>6min), which should be enough time.
3. The inbox is now at a different address: This means off-chain software(and contracts) need to be updated to listen to the new address. This will be necessary for almost every case, since the functions and events are different, the upgrade will necessarily be messy. Bridges use the signal service, so we should only need to upgrade the SS to support the upgrade(we may need to support old and new state roots if we want to avoid proofs needing to be reconstructed).

### Conclusion

There does not seem to be a tangible advantage from having a fork router in the transition from Pacaya -> Shasta. Since this is a radical new version of the protocol, we might as well just use a new address and gain the efficiencies from doing so(and we can always add a fork router later if needed). Because of that my proposal is to deploy the inbox to a new address and get rid of the fork router for shasta. Below are the steps for the hard fork.

## Steps

1. Deploy all the Shasta contracts, and initialize the inbox with `_genesisBlockHash` set to zero. This sets the inbox to an empty state. ** No proposals should happen to the inbox at this point **
   NOTE: We can enforce this onchain by reverting if a proposal happens before `FORK_BLOCK`, but this will increase the cost of every subsequent call to the inbox. Given we have a whitelisted set of proposers another option is to rely on that trust assumption, and not add the on-chain check.
2. Upgrade the Pacaya Inbox to stop accepting proposals after `FORK_BLOCK`.
3. At `FORK_BLOCK` proposers stop submitting proposals to the Pacaya Inbox. This ensures we have a reliable state. After this moment proposers should start preconfing with the new shasta block structure.
4. The `SHASTA_INITIALIZER` calls the `activate` function on the shasta inbox with the `_genesisBlockHash` as of the latest Pacaya batch.
   NOTE: This can be computed off-chain, and while it has not been proven yet, the `SHASTA_INITIALIZER` can ensure it will eventually be proven.
5. Proposers submit their proposals to the new shasta inbox, the fork has officially happened.
6. Proposers and provers can still call the old inbox contract via the fork router, in order to prove pacaya batches and withdraw their bonds.

## Preconfer Operator Transition

**Note:** The **Shasta fork** `timestamp` should be set to the L1 epoch beginning timestamp.

* The **Pacaya operator** of the last Pacaya epoch should continue **preconfirming** until the `HANDOVER_WINDOW`, **submitting** batches to L1 during this window.
* The **next Pacaya operator** of the last Pacaya epoch should **skip preconfirming** during the `HANDOVER_WINDOW`.
* The **Shasta operator** should start **preconfirming** at the Shasta fork `timestamp`.
