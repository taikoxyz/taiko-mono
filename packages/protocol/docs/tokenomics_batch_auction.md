# Batch Auction-Based Tokenomics

## Objectives and Key Metrics
Please read our [objective and metrics in tokenomics design](./tokenomics_objective_metrics.md).
\\,.
## The Proposal
An auction mechanism is suggested to realign provers' incentives towards cost-effectiveness. This mechanism allows provers to bid for block rewards, thereby establishing a transparent fee market. Furthermore, this model promotes resource conservation by enabling provers to commit to resource-intensive Zero-Knowledge Proof (ZKP) computations only after they have definitively won a block.


### Batch-Based Approach
In light of the high gas fees associated with Ethereum, a batch-based strategy for conducting auctions is recommended. This strategy grants the winning bidder the right to verify a batch of blocks, thus reducing per-block gas costs. During the testnet phases, we plan to begin with a smaller batch size, eventually scaling up to 256 blocks by the mainnet launch.

### Provisions for Upcoming Blocks and Gas Costs
To offset potential delays in ZKP, it's recommended to conduct auctions for forthcoming blocks even before they are proposed. This introduces a certain level of uncertainty for provers due to the unknown block gas used and data size at the beginning of the auction. To counter this, an auction pricing model based on the gas/data usage of the auctioned block is proposed. Here, the block reward would be calculated as `b*g`, where `b` is the winning bid in TKO tokens per gas and `g` is the actual gas used (or gas limit) by the block. In this context, `b` will be referred to as the *bid per gas*, or simply the *bid*.

### Bidding Procedures and Deposit Requirements

The auction mechanism employed will follow the traditional English auction model, where all bids are publicly visible throughout the auction period. This choice makes the secretive, second-price auction model unsuitable for our context. Additionally, the initial implementation of our tokenomics design (in alpha-1) adopts elements of a Dutch auction, characterized by escalating rewards over time.

For each new auction, the initial bidding price will be set at `s=2*p`, where `p` represents the moving average bid for all verified blocks. Subsequent bids should be at least 10% lower than the current bid. To participate in the auction, bidders will be required to deposit `s * max_block_gas_limit * num_blocks * 1.5` Taiko tokens as the minimum amount for the batch. If the auction winner fails to submit a valid proof within the designated timeframe, the deposit for the corresponding block will be burnt. On the other hand, successful completion of the proof submission will result in a refund of the deposit.

To maintain stability, the initial bidding price will not undergo drastic changes, such as exceeding a 50% decrease or 100% increase within a 24-hour period.

#### Scoring Bids
A key concern is the risk of a monopolistic scenario, where one highly efficient prover continuously wins auctions, particularly if they're prepared to operate with a slim profit margin. This could marginalize other provers, even those with slightly higher costs, leaving them devoid of work and potentially leading them to exit the system. To encourage diverse participation and avert single-prover dominance, we may need to refine our bid scoring methodology. Rather than focusing solely on the bid price , we could factor in other parameters such as the deposit amount , the prover's average proof delay , and the ratio of their proof submissions to the number of verified blocks they've won. This multi-dimensional evaluation would promote a more equitable competition, ensuring the system's sustainability.

Bid increments in English auctions serve as an effective strategy to encourage serious bidding, ensure fair competition, reduce on-chain transaction costs, and minimize proof rewards. By requiring new bids to exceed the current winning bid by a specified percentage in score(e.g., 10% higher), trivial bids are filtered out, enabling the auction to quickly reach the lowest bid per gas.

#### Internal metrics
It is essential to maintain various internal metrics to effectively score bids  and facilitate off-chain analysis:

1. **Average proof window**: This metric represents the moving average of proof window. The average proof window provides insights into the efficiency of the proof submission process, enabling optimization and monitoring of the overall system performance. Alternatively, we can keep track of *average proof delay* if the auction can incentivize provers to submit proofs immediately after proofs become available. The actual proof delay is not factored into adjusting *average proof window* to avoid reducing the proof window due to early submissions. This approach ensures that slower provers, who require more time to generate proofs, are not discouraged from promptly submitting their proofs.

2. **Average bid per gas for verified blocks**: This metric quantifies the average bid per unit of gas for blocks that have successfully passed the verification process. It provides valuable information about bidding behavior and the value assigned to gas consumption in successful blocks.

3. **Average bid per gas for all blocks**: This optional metric calculates the average bid per unit of gas for all blocks, including those that are currently undergoing the auction process. By considering all blocks, this metric offers a comprehensive view of the average bidding behavior and expenditure on gas across the entire system.

4. **Per bidder proof submission success rate**: This optional metric measures the success rate of proof submissions by individual bidders. Specifically, it evaluates the ratio of proofs submitted by a bidder that were subsequently used for block verification compared to the total number of blocks won through auctions. Proofs submitted to other blocks that the bidder did not win are excluded from this calculation. This metric allows for the assessment of bidder reliability and the effectiveness of their proof submission process.


### Bid Period, Proofing Window, and Managing Multiple Auctions
The bid period for an auction begins with the first bid and lasts for 5 minutes. Blocks can only be proven after the auction has ended entirely. To ensure fairness, particularly for late participants, it is crucial not to end auctions prematurely. It is recommended that an auction concludes when the following conditions are met:

1. The 5-minute bid period has elapsed.
2. The most recent proposed block is within `min_blocks_to_end_auctions` blocks of the first block in the batch.

Auctions are conducted in increasing order of block batches, and the next batch's auction can start as soon as the previous batch's auction has started.

The winning bidder is required to submit the proof for the block within the proof window, typically `proof_window` seconds after either the block proposal or the end of the auction, whichever occurs last. Other participants can only submit proofs after the proof window expires.

### Reward and Penalty Mechanisms
If the chosen fork for the verified block originates from the auction winner's proof, the winner's deposit are refunded and reward are minted. If the selected fork comes from another prover's proof, the latter receives half the deposit, with the remaining half being burnt. This mechanism ensures fair competition and discourages manipulation, such as winners submitting correct proofs via different addresses.

### Absence of Fallback Mode
There is no secondary fee/reward model for blocks that aren't auctioned. This simplifies the auction design and eliminates the need for dual tokenomics systems, namely, an auction-based primary system and an alternate fallback system.

### Block Fees
A fee in Taiko tokens should be levied from the block proposer, calculated as `p * gas_limit`, where `p` is the moving average bid for all verified blocks.

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
