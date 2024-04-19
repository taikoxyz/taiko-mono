# Analysis Report

## Approach taken in evaluating the codebase

### Time spent on this audit: 21 days (Full duration of the contest)

Day 1

- Consuming resources provide in the README
- Understanding and noting down the logical scope

Day 2-7

- Reviewing base contracts (least inherited)
- Adding inline bookmarks for notes
- Understanding RLP encoding, EIP-4844,

Day 8-12

- Reviewing core libs such as LibDepositing, Proposing, Verifying, Proving
- Adding inline bookmarks for problems in libs
- Gas optimizations for libs

Day 13-14

- Other L1, L2 contracts for taiko

Day 15-19

- Reviewing bridge contracts, timelocktokenpool, airdrop contracts

Day 19-21

- Writing reports

## Architecture recommendations

### What's unique?

1. Allowing custom processing - Allowing users to take over the processing aspect gives them control over how and when they want to process their messages.
2. On L2s and L2s that have no invocation delays, the team has created an MEV market from the bridge itself since the processing fees are rewarded to the fastest processor.
3. Use to transient storage - The team has used TSTORE and TLOAD in two places. One is to enable cheaper reentrancy locks and the second is to provide external applications with context. Having context is important since it allows anyone e.g. the vaults to verify whether the source sending the transactions is valid.

### What's using existing patterns and how this codebase compare to others I'm familiar with

- Comparing Taiko to Starknet, the taiko model is much superior since it takes Ethereum's security and uses it to provide cheaper fees to user. The risk associated with Taiko is lesser as well even though it is a type-1 zkevm. This is because Taiko uses guardians while Starknet implements escape hatches, which are more centralized.

## Centralization risks

### Actors Involved and their roles

1. The biggest trust assumption in the contract is the owner role handling all the Address manager contracts. This role can pause the contracts at anytime.
2. The second trust assumption is the guardians multisig. Currently, the guardians are trusted and will be removed over time. But since they are the highest tier, the centralization risk in the proving system exists.
3. ANother role is the bridge watchdog. This role can ban and suspend any messages at will. It is the most important risk of the bridge contracts.
4. The snapshooter role has some risks associated since it takes snapshots on the TaikoToken.

There are more roles in the codebase but these are the foremost and most central to the protocol.

## Resources used to gain deeper context on the codebase

1. Based Rollups and decentralized sequencing

- [Understanding the Concept of Based Rollups](https://ethresear.ch/t/based-rollups-superpowers-from-l1-sequencing/15016)
- [Based Rollup FAQ](https://taiko.mirror.xyz/7dfMydX1FqEx9_sOvhRt3V8hJksKSIWjzhCVu7FyMZU)
- [X space - Part 1](https://www.youtube.com/watch?v=eS5s08sgjuo)
- [X space - Part 2](https://www.youtube.com/watch?v=RqgIEkAfpks)

2. Based Contestable Rollup (BCR)

- [Understanding the concept of Based Contestable Rollup](https://taiko.mirror.xyz/Z4I5ZhreGkyfdaL5I9P0Rj0DNX4zaWFmcws-0CVMJ2A)
- [Based Contestable Rollup 101](https://www.youtube.com/watch?v=A6ncZirXPfc)

3. Protocol Documentation

- [Website Docs](https://docs.taiko.xyz/core-concepts/what-is-taiko/)
- [Markdown concept-specific docs](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/docs)

## Mechanism Review

### Protocol Goals

![Imgur](https://i.imgur.com/eWUK7d5.png)

### High Level System Overview

![Imgur](https://i.imgur.com/C2NE56L.png)

### Understanding Taiko BCR

1. Taiko has no sequencer - block builders/sequencing is decided by Ethereum validators. Permissionless block proposing, building and proving of taiko blocks. Since it uses what Ethereum has to provide (the market of proposers/builders) to its advantage and is not reinventing the wheel, Taiko is "based".

2. Why do we need contestable rollups?

Although ZK is the future, it does introduce complexity in the implementation of the system and thus the chances of bugs. There might be a small % of proofs that are invalid but can still be verified onchain. As a protocol designer, Taiko has to handle these small odds. No validity proof can be trusted without battle testing in short. A malicious block proposer (since proposing blocks is permissionless) can bundle a lot of transactions in a block and create an invalid proof, which would not be handleable by the MerkleTrie verification system. This is why contestable rollups are introduced to prevent these kind of situations/attacks.

Due to this since not all blocks are ZK-provable (block gas limit <> ZK constraint limit), Taiko introduced the guardian role to override invalid proofs.

Another reason why this tier-based contestable rollup design is used is in case, app chains, other layer 2s and layer3s want to use different proof systems other than ZK (so opt out of ZK proofs and maybe opt into SGX proof a.k.a Optimistic proofs).

3. How the guardian will be chosen

DAO => Security Council (owner of all smart contracts) => security council is a multisig with a lot of actors not only from taiko but also the community (like token holders) => security council will decide who will be the guardians => guardian is the multisig smart contract onchain => each guardian will have to run their own full node => each guardian works independently and they do not need to reach consensus offchain => they independently correct the wrong onchain => if the aggregated approval onchain is greater than let's say 2/3rd of the guardians, then the previous proof is overwritten by the guardian to make sure the network is on the right path and has the right state.

This guardian proving should be really rare since there is this taiko token-based bond design i.e. validity bond which will be burnt if the proof is re-proven to be incorrect or they have the contestation bond i.e. if you contest a proof and it ends up that the original proof is correct and you are wrong, then your contestation bond is burnt.

This prevents people from spamming the network (unless they want to burn bonds, which is dumb).

Eventually, after the best tier i.e. highest tier proof (ZK proof) is solid and battle-tested and is really bug free, then the guardian provers should be gone since it's really just for the training wheel.

4. Benefits of Based Contestable Rollup

- Abstraction of special if-else code into a tier-based proof system makes the developers aware that the team cannot just shut down the chain uasing guardian prover and does not have control over it.
- Taiko has 3 types of bonds - validity bonds, contestation bonds and liveness bonds. We've spoken about the first two. Liveness bonds are basically, le's say, I have a prover off-chain and this prover is supposed to submit the proof within 15 minutes, then if the prover does not submit the proof in that time, then the prover's liveness bond is burnt.
- As an app dev, you can always change your config a long way. You can just use one layer-1 transaction to go from 100% optimistic to 100% ZK rollup.
- As ZK becomes more trustworthy, the team will slowly increase the % to ZK until they become fully ZK and remove the guardian prover.

5. Cooldown window for validity proofs

Since we know ZK is not fully trustworthy, let's give it 2-3 hours, so that if nobody challenges this ZK proof, it is final. So from that perspective, Taiko always allows validity proofs to be challenged and overwritten with a higher-tier proof. This adds security.

6. Another Benefit of Based Contestable Rollup

If someone says "I don't like the contestable feature", they can always configure their rollup with only one (top) tier. Then all proofs are not contestable and final. No validity bond nor contestable bond applies.

7. Taiko Mainnet Proofs

Initially: Optimistic => SGX => PSE zkEVM => Guardians

Later: Optimistic => SGX => PSE zkEVM => zkVM (risc0) => Guardians

End game: multiple zkVMs (Guardians removed)

### Chains supported

- Ethereum
- Taiko L2s/L3s

### Grouping of Core Contracts

![Imgur](https://i.imgur.com/HMD27NM.png)

### Recall specific scenario

![Imgur](https://i.imgur.com/cHzS1vH.png)

## Systemic Risks/Architecture-level weak spots and how they can be mitigated

There are a few risks associated with the protocol:

- The protocol does not have a robust on-chain fee estimation mechanism. On calling the on-chain functions, the relayers should provide the contracts with upto date prices for users or atleast maintain a default amount of gas to send across.
- The protocol would not work perfectly with swapping protocols. This is because the bridge includes invocation delays which can cause swaps to go outdated.
- There is an issue related to custom coinbase transfers which can create a risk among block proposers.

### Time spent:

200 hours
