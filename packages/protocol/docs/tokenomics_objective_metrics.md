# Objective and Metrics in Tokenomics Design

## Objective

Taiko's goal is to promote cost-efficient proofs, which dramatically decreases Taiko's overall Layer 2 (L2) expenses, thereby augmenting our competitive standing in the market.

## Key Metrics

Based on the provided insights and inputs from Brecht and Hugo (zkpool), the following proposed metrics for evaluating tokenomics are presented. These metrics are categorized based on their perceived significance, and I encourage further discussion and feedback to refine and enhance them.

1. **Taiko Token Centric**: The tokenomics design should primarily revolve around our Taiko token, rather than other tokens such as USD stable coins. An equilibrium should be achieved between proposer fees and prover rewards, aiming to maintain or even slightly decrease the supply of Taiko tokens over time.

2. **Efficient Use of Proving Resources**: Provers should not squander computational resources on non-profitable tasks. If resources are wasted, provers will understandably require higher returns from accepted proofs to offset their losses. This would invariably raise the average cost of proofs.

3. **Cheaper Proofs over Faster Proofs**: While ideally, proofs should be both cost-efficient and fast, cheaper proofs should be prioritized if two proofs result in the same time delay. In the case of time delays within a specific upper limit, say, one hour, the less expensive proof should also be prioritized. This approach encourages provers to optimize for cost over speed, thus reducing our L2 transaction costs.

4. **Prover Redundancy/Decentralization**: The system should incentivize multiple provers to remain active for block verification, rather than leading to a single prover verifying all blocks which could potentially cause some users to be censored.

5. **No Built-In PoS Reward**: To prevent being classified as a security, our tokenomics design should not offer tokens to stakers as rewards. A prover may establish a staking-based reward system allowing token holders to delegate their power, but this should not be considered as part of our tokenomics.

6. **Simplicity in Design**: Ensuring simplicity in the design of our tokenomics is of paramount importance. It is imperative for decision-makers and engineers within prover companies to easily comprehend the system. The design should encapsulate core concepts concisely and coherently, allowing for rapid understanding of the fundamental principles. This clarity facilitates efficient formulation of strategies and algorithms by provers, enhancing their system participation.

7. **Minimal L1 Cost**: The complexity of the required code in the smart contracts/node is also an important factor to consider. Our tokenomics should strive to minimize the average additional cost per block on its base layer. Provers will likely impose higher fees on L2 to offset this cost, potentially leaving out transactions with lower fees.

8. **Immediate Proof Submission**: Provers should not be required to withhold their proofs and wait offline for the optimal submission moment. Introducing such a system would entail the development of additional infrastructure to store proofs and make strategic decisions regarding submission timings. This increased complexity compared to our competitors could discourage potential provers from participating. Therefore, our tokenomics should incentivize immediate proof submissions as soon as they are ready. This approach enables the system to accurately capture the actual time taken by each proof, facilitating automatic adjustment of relevant parameters.

The above comparison metrics should guide our discussions and prevent an overemphasis on subjective opinions.
