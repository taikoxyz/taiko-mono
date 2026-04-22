# About Contestable Validity Rollup

For a given block, a transition can be uniquely identified by its _parent hash_. The transition's _block hash_ (and _signal root_) may change over time by new proofs, but the transition is always referred to as the same transition in this document.

## Terminology

- **The First Transition**: Refers to the transition with ID = 1.

- **Liveness Bond**: The bond provided by a block's assigned prover, serving as a commitment to initially prove the first transition and to provide post-contest proofs within the corresponding proving window.

- **Validity Bond**: The bond provided by the actual prover of a proof, signifying their commitment that the proof is indeed correct and that they are ready to withstand a contest.

- **Contest Bond**: The bond provided by the contester.

## The First Transition

The _first transition_ of a block is reserved for the block's assigned prover. However, this exclusivity is contingent upon the assigned prover successfully proving the block within the stipulated proving window of the tier. If the assigned prover fails to meet this deadline, the transition is considered _open_. Upon its opening, the assigned prover is no longer allowed to prove the first transition.

For all other transitions, the proving window doesn't apply. Here, the principle is straightforward: the quickest prover takes the lead. Importantly, the assigned prover is not allowed to prove transitions other than the first one.

## Proof Tier Selection

After a block is contested, it's eligible to be re-proven using a higher-tier proof. The onus of selecting the tier — whether it's one level higher or more — rests entirely with the new prover stepping in to prove the block.

Each tier is associated with a distinct proving window. Generally, it's advisable for provers to opt for a lower-tier proof when feasible, as choosing a higher-tier proof, despite its acceptability, might not be the most efficient or profitable choice.

## Validity Bonds and Contest Bonds

Each tier mandates two values: a _validity bond_ and a _contest bond_.

Submitting a tier-N proof necessitates depositing a tier-N validity bond into the transition. If a subsequent higher-tier proof invalidates this transition, the bond is burned. Conversely, contesting a tier-N transition requires a contester to deposit the respective contest bond, which is forfeited if the contest is wrong.

### Contest Bond Configuration

To determine the size of the contest bond in relation to the validity bond, a few considerations come into play:

1. **Tier Differences:** As we move up the tiers, the assumed trustworthiness of proofs increases. Given this, contests against higher tiers should necessitate larger bonds, reflecting the increased certainty and reliability of these tiers. A contest against a high-tier transition asserts that a major flaw exists in a supposedly secure tier, and so the bond should match this gravity.

2. **Optimistic (tier-1):** Given that tier-1 is an optimistic assertion without a proof, it's logical for its contest bond to be equal to its validity bond. This recognizes the provisional nature of such transitions and ensures that contests are neither discouraged nor incentivized excessively.

In essence, the size of the contest bond should mirror the risk and certainty levels associated with the proofs and contests in each tier.

## Re-proving a Transition

Consider Alice proves a transition with a $10,000 bond, and Bob contests it with a bond of $20,000. Now, Cindy can prove this transition with a validity bond of $5,000.

**If Cindy's proof upholds Alice:**

- Alice receives $15,000 (= $10,000 + $20,000/4);
- Bob loses all his bond $20,000;
- Cindy's total bond in the transition is $10,000 (= $5,000 + $20,000/4).

**If Bob's contest stands:**

- Alice loses all her bond $10,000;
- Bob receives $22,500 (= $20,000 + $10,000/4);
- Cindy's total bond in the transition is $7,500 (= $5,000 + $10,000/4).

In either scenario, Cindy becomes the new prover for this transition, staking a bond in the transition together with rewards from either Alice or Bob. This bond is retrievable only when the transition is used for block verification.

The protocol ensures a segment of either the prover's or contester's bond undergoes burning. This safeguards against collusion between the three participants by enforcing a significant cost. Also, retaining the new prover's rewards within the transition and their fresh bond is crucial. The bond and past reward are lost if this prover is later refuted.

## Erasing Proving History

Given two transitions, A and B:

Transition A undergoes a two-tier proving process. Initially, it's validated with a tier-2 proof. Subsequently, after being contested, it's validated by a tier-4 proof. In contrast, Transition B is directly verified with a tier-4 proof.

Considering the bonds of transitions A and B, should there be any disparity?

The logical proposition here is that both transitions should bear identical bonds. There's no intrinsic attribute in either transition A or B to denote one as being inherently riskier or more trustworthy than the other. If this rationale is embraced, then it implies that the validation by a superior-tier proof should effectively "reset" or erase the history of the transition.

To exemplify, given the accepted rationale, the bond distribution dynamics would be as follows:

**If Cindy's proof upholds Alice:**

- Alice receives $15,000 (= $10,000 + $20,000/4);
- Bob loses all his bond $20,000;
- Cindy receives $5,000 (= $20,000/4) and deposits a bond of $5,000.

**If Bob's contest stands:**

- Alice loses all her bond $10,000;
- Bob receives $22,500 (= $20,000 + $10,000/4);
- Cindy receives $2,500 (= $10,000/4) and deposits a bond of $5,000.

From an engineering standpoint, this approach of erasing prior proving impacts streamlines the implementation and reduces code complexity.

Indeed, allowing a new prover to deposit a validity bond that's smaller than the potential reward from either the original prover or the contester is not viewed as a system flaw or bug. The rationale behind this is that the new proof is expected to be more trustworthy than the previous one.

## Prover Fees

The prover assignment serves as a social contract between a proposer and a prover. It's crucial that this assignment explicitly defines the fee amount for each acceptable tier.

Specifically, the assignment details the payment terms **only for the first proof of the first transition**. However, it's important to note that for all other transitions, the initial proof does not receive direct payment. Instead, if the transition is used in the verification of a block, the prover is compensated from a portion of the block's assigned prover's prover bond, which should be much larger in value than the prover fee for the first transition.
