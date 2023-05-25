# Prover dynamics

## How the proof reward is determined

A proof reward in TTKO is rewarded for successfully proving a block. This reward is dependent on the `proofTimeTarget`. You can see the current proof reward by calling `getProofReward` on the TaikoL1 contract.

So that we don't grow a long list of unverified blocks for too long, we want to target proofs coming in at a certain rate. So we set a target proof time. If it has taken a long time since the last verified block, the proof reward increases to incentivize provers to generate a proof.

Conversely, if everyone is submitting proofs quickly, then the proof reward decreases towards zero. This means that as a prover, you should query `getProofReward` on the TaikoL1 contract to determine if it is profitable to generate a proof. If you submit proofs as quickly as possible, then the proof reward will trend towards zero.

## Default in simple-taiko-node

The [simple-taiko-node](https://github.com/taikoxyz/simple-taiko-node) will come pre-configured to not submit proofs as quickly as possible, by querying `getProofReward`. This hopefully means that most nodes in the network are acting in the group interest, by responsibly not submitting the proof as quickly as possible. However, because the first prover will win the reward, and because the project is open source, anybody can modify the [taiko-client](https://github.com/taikoxyz/taiko-client) and act rationally to submit a proof slightly earlier than the default set in `simple-taiko-node`. As you can see, it causes somewhat of a prisoner's dilemma.

## Your role as a prover

We are describing this dynamic so you can be informed when you run a prover. It's very possible that without the correct strategy, you will not be profitable as a prover. You are naturally competing in an open space where others could have more efficient hardware and generate a proof in a short amount of time that you cannot compete against.
