# Building a Batch-Based Auction System for Cost-Effective Prover Rewards

## Overview

The current tokenomics structure rewards the fastest prover, inadvertently promoting speed over cost-effectiveness. This contradicts Taiko's goal of delivering cost-efficient proofs. By shifting the incentives towards cost-effective proofs, we can dramatically decrease Taiko's overall Layer 2 (L2) expenses, thereby augmenting our competitive standing in the market.

## Key Metrics

Based on the provided insights and inputs from Brecht and Hugo (zkpool), the following proposed metrics for evaluating tokenomics are presented. These metrics are categorized based on their perceived significance, and I encourage further discussion and feedback to refine and enhance them.

1. **Taiko Token Centric**: The tokenomics design should primarily revolve around our Taiko token, rather than other tokens such as USD stable coins. An equilibrium should be achieved between proposer fees and prover rewards, aiming to maintain or even slightly decrease the supply of Taiko tokens over time.

1. **Efficient Use of Proving Resources**: Provers should not squander computational resources on non-profitable tasks. If resources are wasted, provers will understandably require higher returns from accepted proofs to offset their losses. This would invariably raise the average cost of proofs.

1. **Cheaper Proofs over Faster Proofs**: While ideally, proofs should be both cost-efficient and fast, cheaper proofs should be prioritized if two proofs result in the same time delay. In the case of time delays within a specific upper limit, say, one hour, the less expensive proof should also be prioritized. This approach encourages provers to optimize for cost over speed, thus reducing our L2 transaction costs.

1. **Prover Redundancy/Decentralization**: The system should incentivize multiple provers to remain active for block verification, rather than leading to a single prover verifying all blocks which could potentially cause some users to be censored.

1. **No Built-In PoS Reward**: To prevent being classified as a security, our tokenomics design should not offer tokens to stakers as rewards. A prover may establish a staking-based reward system allowing token holders to delegate their power, but this should not be considered as part of our tokenomics.

1. **Immediate Proof Submission**: Provers should not be required to withhold their proofs and wait offline for the optimal submission moment. Introducing such a system would entail the development of additional infrastructure to store proofs and make strategic decisions regarding submission timings. This increased complexity compared to our competitors could discourage potential provers from participating. Therefore, our tokenomics should incentivize immediate proof submissions as soon as they are ready. This approach enables the system to accurately capture the actual time taken by each proof, facilitating automatic adjustment of relevant parameters.

1. **Simplicity in Design**: Ensuring simplicity in the design of our tokenomics is of paramount importance. It is imperative for decision-makers and engineers within prover companies to easily comprehend the system. The design should encapsulate core concepts concisely and coherently, allowing for rapid understanding of the fundamental principles. This clarity facilitates efficient formulation of strategies and algorithms by provers, enhancing their system participation.

1. **Minimal L1 Cost**: The complexity of the required code in the smart contracts/node is also an important factor to consider. Our tokenomics should strive to minimize the average additional cost per block on its base layer. Provers will likely impose higher fees on L2 to offset this cost, potentially leaving out transactions with lower fees.

The above comparison metrics should guide our discussions and prevent an overemphasis on subjective opinions.

## Proposed Solution
An auction mechanism is suggested to realign provers' incentives towards cost-effectiveness. This mechanism allows provers to bid for block rewards, thereby establishing a transparent fee market. Furthermore, this model promotes resource conservation by enabling provers to commit to resource-intensive Zero-Knowledge Proof (ZKP) computations only after they have definitively won a block reward.


### Batch-Based Approach
In light of the high gas fees associated with Ethereum, a batch-based strategy for conducting auctions is recommended. This strategy grants the winning bidder the right to verify a batch of blocks, thus reducing per-block gas costs. During the testnet phases, we plan to begin with a smaller batch size, eventually scaling up to 256 blocks by the mainnet launch.

### Provisions for Upcoming Blocks and Gas Costs
To offset potential delays in ZKP, it's recommended to conduct auctions for forthcoming blocks even before they are proposed. This introduces a certain level of uncertainty for provers due to the unknown block gas used and data size at the beginning of the auction. To counter this, an auction pricing model based on the gas/data usage of the auctioned block is proposed. Here, the block reward would be calculated as `b*g`, where `b` is the winning bid in TKO tokens per gas and `g` is the actual gas used by the block. In this context, `b` will be referred to as the *bid per gas*, or simply the *bid*.

### Bidding Procedures and Deposit Requirements

We will employ the traditional English auction model, where all bids are publicly visible throughout the course of the auction, thus making a secretive, second-price auction model unsuitable in this context. Additionally, our inaugural tokenomics design emulates a Dutch auction, distinguished by its feature of escalating rewards over time.


The initial bidding price for new auctions should be set at `s=2*p`, where `p` represents a moving average *bid* for all verified blocks. Each subsequent bid should be at least 10% lower than the current bid. Bidders would need to deposit `s * max_block_gas_limit * num_blocks * 1.5` Taiko tokens for the batch. A penalty of `s * max_block_gas_limit * 1.5` Taiko tokens will be imposed and subsequently burnt for each block the winner fails to verify within the designated timeframe. Successful completion will result in a refund of the deposit.


A key concern is the risk of a monopolistic scenario, where one highly efficient prover continuously wins bids, particularly if they're prepared to operate with a slim profit margin. This could marginalize other provers, even those with slightly higher costs, leaving them devoid of work and potentially leading them to exit the system. To encourage diverse participation and avert single-prover dominance, we may need to refine our bid scoring methodology. Rather than focusing solely on the bid price , we could factor in other parameters such as the deposit amount , the prover's average proof delay , and the ratio of their proof submissions to the number of verified blocks they've won. This multi-dimensional evaluation would promote a more equitable competition, ensuring the system's sustainability.

```python
# this is just to demostrate an idea, the actual implementation needs
# aa more careful algo design.
def will_new_bid_win(new_bid, old_bid):

    # return False immediately if new_bid does not meet these conditions
    if new_bid.bid_per_gas < old_bid.bid_per_gas * 0.9:
        return False
    if new_bid.deposit < old_bid.deposit * 0.5:
        return False
    if new_bid.success_rate == 0:
        return False

    new_score = 0.0
    old_score = 0.0

    # calculate scores for each field
    if new_bid.bid_per_gas <= old_bid.bid_per_gas:
        new_score += 1 - (new_bid.bid_per_gas / old_bid.bid_per_gas)  # higher score if new_bid.bid_per_gas is smaller but not 10% smaller
    else:
        old_score += 1 - (old_bid.bid_per_gas / new_bid.bid_per_gas)  # higher score if old_bid.bid_per_gas is smaller

    deposit_for_score = min(new_bid.deposit, 2 * old_bid.deposit)
    if deposit_for_score >= 2 * old_bid.deposit:
        new_score += deposit_for_score / old_bid.deposit - 1  # higher score if new_bid.deposit is much larger
    else:
        old_score += old_bid.deposit / deposit_for_score - 1  # higher score if old_bid.deposit is much larger

    if new_bid.success_rate >= old_bid.success_rate * 1.15:
        new_score += new_bid.success_rate / old_bid.success_rate - 1  # higher score if new_bid.success_rate is much larger
    else:
        old_score += old_bid.success_rate / new_bid.success_rate - 1  # higher score if old_bid.success_rate is much larger

    # if new_bid's total score is higher, it's considered better
    return new_score > old_score * 1.1


```


### Auction Window, Proofing Window, and Managing Multiple Auctions
The auction window initiates with the first bid and concludes after either 5 minutes or 25 Ethereum blocks. Blocks become provable only once the auction has officially concluded. The auction winner is required to submit the initial Zero-Knowledge Proof (ZKP) for the block within the proofing window—e.g., 60 minutes—of either the block proposal or the auction's end, whichever is later. Other provers are permitted to submit proofs, creating alternative fork choices, either following the initial ZKP submission or after the proofing window has elapsed. While simultaneous auctions for different batches are permissible, it's advisable to restrict this to the upcoming 100 batches for optimal management.

Provers are incentivized to submit proofs promptly. This shall increase their chances of winning future block auctions and potentially allows them to gradually reduce the proofing window. This can serve as a strategy to outmaneuver competitors who can generate low-cost proofs but require a time close to the proofing window to do so.


### Reward and Penalty Mechanisms
If the chosen fork for the verified block originates from the auction winner's proof, the winner's deposit and reward TKO tokens are refunded. If the selected fork comes from another prover's proof, the latter receives half the deposit, with the remaining half being burnt. This mechanism ensures fair competition and discourages manipulation, such as winners submitting correct proofs via different addresses.

### Absence of Fallback Mode
There is no secondary fee/reward model for blocks that aren't auctioned. This simplifies the auction design and eliminates the need for dual tokenomics systems, namely, an auction-based primary system and an alternate fallback system.

### Block Fees
A fee in Taiko tokens should be levied from the block proposer, calculated as `p * gas_limit`, where `p` is the moving average bid for all verified blocks. Another moving average `q` could be introduced to cover the bid of all unverified blocks that have been auctioned. For example, the fee could be calculated as `(p * 0.5 + q * 0.5) * gas_limit`.

## Best Strategy for a Prover


### Bidding
A prover should consistently monitor recent winning bid scores to gauge the current market status. From there, he can calculate an appropriate bidding price that aligns with his proof generation costs. Optionally, to enhance his score, he could deposit additional Taiko tokens as auction collateral.

### Proof Submission
He should submit proofs at the earliest opportunity.

### Optimization
The prover's optimization should be conducted in a hierarchical manner, with cost reduction as the primary focus. After reducing proof costs, the next step would be to minimize proof delay, followed by improving the rate of proof submissions. An additional optional strategy could be to acquire more Taiko tokens to perpetually boost his score.

### Pool Participation
A prover may opt to join a prover pool to engage in off-chain auctions managed by the pool itself. Subsequently, the pool participates in the on-chain auction on behalf of its members and manages the deposits of Taiko tokens, thereby enhancing the bid scores for all participants within the pool. This strategy allows for pooled resources and risk, potentially offering an advantage in the competitive bidding process.

## Challenges

### Lack of Competition
The proposed auction framework's success heavily depends on the active participation of numerous independent entities. In the event of collusion or alliances among provers to boost their profits, they could strategically place a single bid at the initial/highest price `s`, leading to a continual increase in rewards. This goes against the system's intention of promoting cost-efficient competition.

However, such behavior might inadvertently stimulate competition. As the reward for verifying considerably increases, it's likely to pique the interest of other provers, thus promoting their participation. This market self-regulation could restore equilibrium and maintain the auction process's competitive integrity.


### Low Bid Attacks

A malicious prover may strategize to win numerous batches by placing extremely low bids, aiming to manipulate the starting price of future auctions. This could potentially discourage other provers from participating in subsequent auctions. To safeguard against such manipulation, it's imperative to establish a mechanism that ensures the starting price for future auctions changes incrementally and consistently, thereby maintaining a fair and competitive bidding environment.


### Added Verification Delay
Introducing an auction window inevitably introduces an additional delay to the verification time. This delay might not be noticeable when the average verification time is relatively long (over 30 minutes). However, it could become significant in future scenarios where proof generation takes just a few minutes.

Despite this, as stressed at the beginning of the proposal, our goal is to optimize for cost, not speed. While this additional delay is a vital consideration, it's unlikely to pose a significant obstacle to our primary objective of cost-effectiveness.