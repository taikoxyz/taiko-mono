# Building a Batch-Based Auction System for Cost-Effective Prover Rewards

## Overview

The current tokenomics structure rewards the fastest prover, inadvertently promoting speed over cost-effectiveness. This contradicts Taiko's goal of delivering cost-efficient proofs. By shifting the incentives towards cost-effective proofs, we can dramatically decrease Taiko's overall Layer 2 (L2) expenses, thereby augmenting our competitive standing in the market.

## Key Metrics

After numerous attempts at developing and implementing Taiko's tokenomics, several crucial insights have been obtained:

- The complexity and time commitment involved in this task may have been initially underestimated. A year into the process, it appears we are essentially back at the starting point.
- A metric system is necessary to objectively evaluate and compare different designs. A comparison based on a set of metrics will facilitate objective discussions and ensure focus on the essential elements of various ideas, rather than unnecessary details.

Based on the provided insights and inputs from Brecht and Hugo (zkpool), the following proposed metrics for evaluating tokenomics are presented. These metrics are categorized based on their perceived significance, and I encourage further discussion and feedback to refine and enhance them.

1. **Taiko Token Centric**: The tokenomics design should primarily revolve around our Taiko token, rather than other tokens such as USD stable coins. An equilibrium should be achieved between proposer fees and prover rewards, aiming to maintain or slightly decrease the supply of Taiko tokens over time. This approach ensures the long-term stability and value of our native token.

1. **Efficient Use of Proving Resources**: Provers should not squander computational resources on non-profitable tasks. If resources are wasted, provers will understandably require higher returns from accepted proofs to offset their losses. This would invariably raise the average cost of proofs.

1. **Cheaper Proofs over Faster Proofs**: While ideally, proofs should be both cost-efficient and fast, cheaper proofs should be prioritized if two proofs result in the same time delay. In the case of time delays within a specific upper limit, say, one hour, the less expensive proof should also be prioritized. This approach encourages provers to optimize for cost over speed, thus reducing our L2 transaction costs.

1. **Prover Redundancy/Decentralization**: The system should incentivize multiple provers to remain active for block verification, rather than leading to a single prover verifying all blocks which could potentially cause unexpectedly high withdrawal times.

1. **No Built-In PoS Reward**: To prevent being classified as a security, our tokenomics design should not offer tokens to stakers as rewards. A prover may establish a staking-based reward system allowing token holders to delegate their power, but this should not be considered as part of our tokenomics.

1. **Simplified Decision Making**: Decisions regarding the proof of Taiko's blocks should not rely on complex algorithms. The fewer inputs required for such decisions, the better.

1. **Immediate Proof Submission**: Provers shouldn't be obligated to withhold their proofs and wait offline for the optimal submission moment. Implementing such a system would necessitate the development of supplementary infrastructure to hold proofs and make strategic decisions about submission timings. In comparison to our competitors, this added complexity could deter potential provers. Consequently, our tokenomics should incentivize immediate proof submissions upon readiness. This will ultimately drive provers to optimize both proof time and cost in the long term, with an emphasis on prioritizing cost efficiency.

1. **Simplicity in Design**: It's crucial for our tokenomics to be understandable and accessible, particularly for the decision-makers and engineers within prover companies. The design should encapsulate core concepts in a succinct and coherent manner, facilitating a rapid comprehension of the fundamental principles. This clarity enables provers to efficiently devise their strategies and algorithms, thereby streamlining their participation in the system.

1. **Minimal Prover Fee**: This is different from "Preference for Cheaper Proofs over Faster Proofs". Factors such as uncertainty about the number and types of blocks to be verified within a given period, and whether the prover can distribute the risk of such uncertainty over a constant stream of future blocks, will also influence the minimum reward the prover will accept for blocks.

1. **Implementation Complexity and Minimal L1 Cost**: The complexity of the required code in the smart contracts/node is also an important factor to consider. Our tokenomics should strive to minimize the average additional cost per block on its base layer. Provers will likely impose higher fees on L2 to offset this cost, potentially leaving out transactions with lower fees.

1. **Prover Work Security**: Provers should be confident about their ability to verify blocks in the foreseeable future. However, if they are more expensive than other provers, they should gradually lose their work.


The above comparison metrics should guide our discussions and prevent an overemphasis on subjective opinions.

## Proposed Solution
An auction mechanism is suggested to realign provers' incentives towards cost-effectiveness. This mechanism allows provers to bid for block rewards, thereby establishing a transparent fee market. Furthermore, this model promotes resource conservation by enabling provers to commit to resource-intensive Zero-Knowledge Proof (ZKP) computations only after they have definitively won a block reward.

## Design Factors
### Batch-Based Approach
In light of the high gas fees associated with Ethereum, a batch-based strategy for conducting auctions is recommended. This strategy grants the winning bidder the right to verify a batch of blocks, thus reducing per-block gas costs. During the testnet phases, we plan to begin with a smaller batch size, eventually scaling up to 256 blocks by the mainnet launch.

### Provisions for Upcoming Blocks and Gas Costs
To offset potential delays in ZKP, it's recommended to conduct auctions for forthcoming blocks even before they are proposed. This introduces a certain level of uncertainty for provers due to the unknown block gas used and data size at the beginning of the auction. To counter this, an auction pricing model based on the gas/data usage of the auctioned block is proposed. Here, the block reward would be calculated as `b*g`, where `b` is the winning bid in TKO tokens per gas and `g` is the actual gas used by the block. In this context, `b` will be referred to as the *bid per gas*, or simply the *bid*.

### Bidding Procedures and Deposit Requirements
The initial bidding price for new auctions should be set at `s=2*p`, where `p` represents a moving average *bid* for all verified blocks. Each subsequent bid should be at least 5% lower than the current bid. Bidders would need to deposit `s * max_block_gas_limit * num_blocks * 1.5` Taiko tokens for the batch. A penalty of `s * max_block_gas_limit * 1.5` Taiko tokens will be imposed and subsequently burnt for each block the winner fails to verify within the designated timeframe. Successful completion will result in a refund of the deposit.

### Auction Window, Verification Window, and Multiple Auction Management
The auction window commences with the first bid and concludes either after 5 minutes or 25 Ethereum blocks. Blocks become eligible for verification only after the auction has officially ended. The winner of the auction must submit the initial ZKP for the block within 60 minutes of the block proposal or the auction's conclusion, whichever is later. Other provers can submit proofs to create alternative fork choices either after the initial ZKP submission or upon the expiration of the verification window. Concurrent auctions for different batches are permissible. However, it's recommended to limit this to the forthcoming 100 batches for better management.

### Reward and Penalty Mechanisms
If the chosen fork for the verified block originates from the auction winner's proof, the winner's deposit and reward TKO

 tokens are refunded. If the selected fork comes from another prover's proof, the latter receives half the deposit, with the remaining half being burnt. This mechanism ensures fair competition and discourages manipulation, such as winners submitting correct proofs via different addresses.

### Absence of Fallback Mode
There is no secondary fee/reward model for blocks that aren't auctioned. This simplifies the auction design and eliminates the need for dual tokenomics systems, namely, an auction-based primary system and an alternate fallback system.

### Block Fees
A fee in Taiko tokens should be levied from the block proposer, calculated as `p * gas_limit`, where `p` is the moving average bid for all verified blocks. Another moving average `q` could be introduced to cover the bid of all unverified blocks that have been auctioned. For example, the fee could be calculated as `(p * 0.5 + q * 0.5) * gas_limit`.

### Challenges

#### Lack of Competition 
The proposed auction framework's success heavily depends on the active participation of numerous independent entities. In the event of collusion or alliances among provers to boost their profits, they could strategically place a single bid at the initial/highest price `s`, leading to a continual increase in rewards. This goes against the system's intention of promoting cost-efficient competition.

However, such behavior might inadvertently stimulate competition. As the reward for verifying considerably increases, it's likely to pique the interest of other provers, thus promoting their participation. This market self-regulation could restore equilibrium and maintain the auction process's competitive integrity.

#### Avoiding a Monopoly

A potential pitfall with the aforementioned design is the likelihood of a 'winner-takes-all' scenario. A prover capable of producing the most cost-effective proofs within the necessary timeframe could consistently secure victories, especially if they are willing to operate with a lower profit margin. This could leave other provers, even those with only slightly higher costs, without any work, causing them to exit the system over time. To foster a healthier competition and prevent the domination by a single prover, we might need to adjust our bid scoring calculations. Instead of relying solely on the bidding price `b`, we could consider other parameters such as the deposit amount `m` and the prover's moving average proof delay `d`.

#### Added Verification Delay
Introducing an auction window inevitably introduces an additional delay to the verification time. This delay might not be noticeable when the average verification time is relatively long (over 30 minutes). However, it could become significant in future scenarios where proof generation takes just a few minutes.

Despite this, as stressed at the beginning of the proposal, our goal is to optimize for cost, not speed. While this additional delay is a vital consideration, it's unlikely to pose a significant obstacle to our primary objective of cost-effectiveness.