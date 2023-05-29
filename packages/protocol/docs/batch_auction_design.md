# Building a Batch-Based Auction System for Cost-Effective Prover Rewards

## Introduction

The existing tokenomics infrastructure currently prioritizes speed over economic prudence when rewarding provers. However, Taiko aims to provide cost-effective proofs. To align with this goal and reduce comprehensive Layer 2 (L2) costs, it is necessary to transition the reward system to favor economically efficient proofs.

## Evaluation Metrics

Based on insights gained during the development of Taiko's tokenomics and contributions from Brecht and Hugo (zkpool), the following metrics are proposed for evaluating tokenomics designs. These metrics are classified based on their relevance and can be further refined through discussion and feedback.

1. **Taiko Token Centricity**: The tokenomics design should prioritize the Taiko token over other tokens, such as USD stable coins. Maintaining a balance between proposer fees and prover rewards will help preserve or slightly reduce the supply of Taiko tokens over time, ensuring the long-term stability and value of the native token.

2. **Efficiency of Proving Resources**: Provers should avoid wasting computational resources on non-profitable tasks. Frivolous resource expenditure would require higher returns from accepted proofs to compensate for losses, resulting in increased average proof costs.

3. **Preference for Economical Proofs over Rapid Proofs**: While proofs should ideally be both economical and quick, cost-effectiveness should be prioritized when two proofs result in the same time delay. When time delays are within a specified upper limit, such as one hour, the cheaper proof should take precedence. This strategy encourages provers to prioritize cost over speed, reducing L2 transaction costs.

4. **Prover Redundancy/Decentralization**: The system should incentivize multiple provers to remain active in block verification, rather than relying on a single prover to verify all blocks. Having a single prover can lead to unpredictable withdrawal times.

5. **Absence of Built-In PoS Reward**: To avoid classification as a security, the tokenomics design should not offer tokens as rewards to stakers. Provers can set up a staking-based reward system that allows token holders to delegate their power, but this feature should not be integrated into the tokenomics.

6. **Streamlined Decision Making**: Decisions related to block verification should not rely on complex algorithms. The process should be efficient and require minimal inputs.

7. **Immediate Proof Submission**: Provers should be encouraged to submit proofs immediately without withholding them to wait for an optimal submission moment. Requiring proof storage and strategic decision-making about submission timings would add complexity and potentially discourage provers. Encouraging immediate proof submission promotes long-term optimization of proof time and cost, with an emphasis on cost efficiency.

8. **Simplicity in Design**: The tokenomics should be easy to understand and accessible, especially for decision-makers and engineers within prover organizations. The design should clearly capture core concepts, facilitating rapid understanding of the fundamental principles. This clarity enables provers to formulate strategies and algorithms efficiently, enhancing their participation in the system.

9. **Minimal Prover Fee**: This metric considers factors such as uncertainty about the quantity and types of blocks to be verified within a given period. The prover's ability to distribute the risk of uncertainty over future blocks affects the minimum reward they would accept for blocks.

10. **Implementation Complexity and Minimal L1 Cost**: The complexity of the smart contract/node code is crucial. The tokenomics should aim to minimize the average extra cost per block on the base layer. Provers may impose higher fees on L2 to compensate for this cost, potentially excluding transactions with lower fees.

11. **Prover Work Security**: Provers should feel secure about their ability to verify blocks in the foreseeable future. However, if they are more expensive than other provers, they should gradually lose their work.

These metrics provide a framework for objective evaluation and discourage subjective opinions in discussions.

## Proposed Solution

An auction mechanism is proposed to align provers' incentives with cost-effectiveness. This mechanism allows provers to bid for block rewards, establishing a transparent fee market. Additionally, this model promotes resource conservation by enabling provers to commit to resource-intensive Zero-Knowledge Proof (ZKP) computations only after winning a block auction.

### Batch-Based Approach

Considering the high gas fees on Ethereum, a batch-based strategy is recommended for conducting auctions. This approach grants the winning bidder the right to verify a batch of blocks, reducing per-block gas costs. The batch size will start smaller during testnet phases and scale up to 256 blocks by the mainnet launch.

### Provisions for Upcoming Blocks and Gas Costs

To offset potential delays in ZKP, auctions for forthcoming blocks should be conducted before their proposal. This introduces uncertainty for provers due to unknown block gas usage and data size at the start of the auction. To address this, an auction pricing model based on the gas/data usage of the auctioned block is proposed. The block reward would be calculated as `b*g`, where `b` represents the winning bid in TKO tokens per gas and `g` is the actual gas used by the block. The winning bid (`b`) will be referred to as the *bid per gas* or *bid*.

### Bidding Procedures and Deposit Requirements

The traditional English auction model, with publicly visible bids, is employed to ensure transparency. A secretive, second-price auction model is unsuitable for this context. The initial bidding price for new auctions should be set at `s=2*p`, where `p` represents a moving average bid for all verified blocks. Subsequent bids should be at least 5% lower than the current bid. Bidders are required to deposit `s * max_block_gas_limit * num_blocks * 1.5` Taiko tokens for the batch. A penalty of `s * max_block_gas_limit * 1.5` Taiko tokens will be imposed and burnt for each block the winner fails to verify within the designated timeframe. Successful completion results in a refund of the deposit.

To avoid monopolistic scenarios and encourage diverse participation, bid scoring methodology can be refined. In addition to bid price, parameters such as deposit amount, average proof delay, and the ratio of proof submissions to verified blocks won can be considered. This multi-dimensional evaluation promotes equitable competition and ensures the system's sustainability.

```python
def will_new_bid_win(new_bid, old_bid):
    if new_bid.bid_per_gas < old_bid.bid_per_gas * 0.9:
        return False
    if new_bid.deposit < old_bid.deposit * 0.5:
        return False
    if new_bid.success_rate == 0:
        return False

    new_score = 0.0
    old_score = 0.0

    if new_bid.bid_per_gas <= old_bid.bid_per_gas:
        new_score += 1 - (new_bid.bid_per_gas / old_bid.bid_per_gas)
    else:
        old_score += 1 - (old_bid.bid_per_gas / new_bid.bid_per_gas)

    deposit_for_score = min(new_bid.deposit, 2 * old_bid.deposit)
    if deposit_for_score >= 2 * old_bid.deposit:
        new_score += deposit_for_score / old_bid.deposit - 1
    else:
        old_score += old_bid.deposit / deposit_for_score - 1

    if new_bid.success_rate >= old_bid.success_rate * 1.15:
        new_score += new_bid.success_rate / old_bid.success_rate - 1
    else:


        old_score += old_bid.success_rate / new_bid.success_rate - 1

    return new_score > old_score
```

### Auction Window, Proofing Window, and Managing Multiple Auctions

The auction window begins with the first bid and concludes after either 5 minutes or 25 Ethereum blocks. Blocks can only be proven once the auction officially ends. The auction winner must submit the initial Zero-Knowledge Proof (ZKP) for the block within the proofing window, which is set to 60 minutes after the block proposal or the auction's end, whichever is later. Other provers can submit proofs, creating alternative fork choices, either after the initial ZKP submission or after the proofing window has elapsed. While simultaneous auctions for different batches are allowed, it is advisable to limit this to the upcoming 100 batches for efficient management.

Provers are incentivized to submit proofs promptly to increase their chances of winning future block auctions and potentially reduce the proofing window. This strategy can outmaneuver competitors who generate low-cost proofs but require close to the proofing window time.

### Reward and Penalty Mechanisms

If the chosen fork for the verified block originates from the auction winner's proof, the winner's deposit and reward TKO tokens are refunded. If the selected fork comes from another prover's proof, the latter receives half the deposit, and the remaining half is burnt. This mechanism ensures fair competition and discourages manipulation, such as winners submitting correct proofs via different addresses.

### Absence of Fallback Mode

There is no secondary fee/reward model for unauctioned blocks. This simplifies the auction design and eliminates the need for dual tokenomics systems, reducing complexity.

### Block Fees

A fee in Taiko tokens should be levied from the block proposer, calculated as `p * gas_limit`, where `p` is the moving average bid for all verified blocks. Another moving average `q` could be introduced to cover the bid of all unverified blocks that have been auctioned. For example, the fee could be calculated as `(p * 0.5 + q * 0.5) * gas_limit`.

## Best Strategy for a Prover

### Bidding

Provers should monitor recent winning bid scores to assess the current market status. Based on this information, they can calculate appropriate bidding prices aligned with their proof generation costs. Additional Taiko tokens can be deposited as collateral to enhance their bid scores.

### Proof Submission

Provers should submit proofs as soon as possible.

### Optimization

Provers should prioritize cost reduction as the primary optimization focus. After reducing proof costs, minimizing proof delay and improving the rate of proof submissions should be addressed. Acquiring more Taiko tokens as a strategy to boost score perpetually is optional.

### Pool Participation

Provers can join prover pools to engage in off-chain auctions managed by the pool. The pool then participates in the on-chain auction on behalf of its members, managing Taiko token deposits and enhancing bid scores for all participants. This strategy allows for pooled resources and risk, potentially providing an advantage in the competitive bidding process.

## Challenges

### Lack of Competition

The success of the proposed auction framework relies on active participation from numerous independent entities. Collusion or alliances among provers to maximize profits by strategically placing a single bid at the highest price (`s`) could undermine cost-efficient competition. However, such behavior may inadvertently stimulate competition as higher rewards attract more provers, restoring equilibrium and maintaining competitive integrity.

### Low Bid Attacks

Malicious provers may attempt to manipulate starting prices of future auctions by placing extremely low bids to win multiple batches. This manipulation could discourage other provers from participating in subsequent auctions. To mitigate this, a mechanism ensuring incremental and consistent changes to starting prices for future auctions is necessary to maintain a fair and competitive bidding environment.

### Added Verification Delay

Introducing an auction window inevitably introduces an additional delay in the verification time. While this delay may not be noticeable when the average verification time is relatively long, it could become significant as proof generation times decrease. However, the primary objective is cost-effectiveness, not speed. While the additional delay is a consideration, it is unlikely to significantly hinder the primary goal of achieving cost efficiency.

