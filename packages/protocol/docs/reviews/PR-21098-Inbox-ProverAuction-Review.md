# PR 21098 Review: Inbox.sol + ProverAuction.sol

Date: 2026-01-03

Scope:

- packages/protocol/contracts/layer1/core/impl/Inbox.sol
- packages/protocol/contracts/layer1/core/impl/ProverAuction.sol

Summary:
This PR removes the prover whitelist and bond manager from Inbox, integrates
ProverAuction for designated prover selection/slashing, and changes the ETH
payment flow in propose(). Overall the logic is cohesive, but there are a few
edge cases and OpenZeppelin-pattern mismatches that should be clarified or
tightened before merge.

OpenZeppelin pattern checklist used:

- Access control: Ownable2Step (owner-only init/activate)
- ReentrancyGuard / CEI ordering for external calls
- Pausable for emergency stops
- SafeERC20 for ERC20 transfers
- Pull-payment vs push-payment for ETH refunds

Findings

M-01: Unpaid prover fees can become permanently stuck in Inbox
Location: packages/protocol/contracts/layer1/core/impl/Inbox.sol:180-223, 686-720
Details: _settleProposalPayments() deducts the prover fee from available ETH
and then attempts to pay the prover via sendEther (which can fail without
reverting). If the prover rejects payment, the fee remains in the Inbox with
no sweep/claim path. This contradicts the propose() docstring which states
unpaid fees are refunded. This can strand ETH and create accounting drift
between expected and actual payouts.
Recommendation: Either (a) refund unpaid prover fee to the proposer when
sendEther fails, or (b) escrow unpaid fees for later prover withdrawal (pull
pattern). If the current behavior is intended, update the propose() comment
and add explicit documentation of stuck funds.

M-02: Designated prover binding in proofs is not enforced on-chain
(needs confirmation)
Location: packages/protocol/contracts/layer1/core/impl/Inbox.sol:538-563,
660-682, 761-804
Details: Proposals now include a designatedProver from the auction, but
prove() does not verify that commitment.transitions[i].designatedProver
matches the proposal data for each proposal being finalized. Slashing uses
transitions[offset].designatedProver. If the proof circuit does not bind
transition data to proposal hashes, a prover could submit a late proof that
slashes an arbitrary address.
Recommendation: Confirm the proof circuit enforces designatedProver
consistency with proposal hashes. If not, add an on-chain check (or hash
binding) to ensure transitions' designatedProver matches the stored proposal
hash for the slashed proposal.

L-01: Comment/behavior mismatch in propose() payment flow
Location: packages/protocol/contracts/layer1/core/impl/Inbox.sol:180-192, 686-720
Details: The docstring claims unpaid prover fees are refunded to the proposer,
but the implementation keeps the unpaid fee in the contract.
Recommendation: Align comment with code or update code to match the documented behavior.

L-02: Forced inclusion fee recipient semantics changed
Location: packages/protocol/contracts/layer1/core/impl/Inbox.sol:522-597, 686-720
Details: Forced inclusion fees are no longer immediately paid to the proposer;
they now offset the prover fee. This is an economic shift from "fee to proposer"
to "fee to prover (via offset)."
Recommendation: Confirm this is intended and update docs/tests accordingly.

L-03: Prover selection uses block.prevrandao (manipulable randomness)
Location: packages/protocol/contracts/layer1/core/impl/ProverAuction.sol:368-381
Details: prevrandao can be influenced by block producers, so selection is not
fully unbiased.
Recommendation: If fairness is a security requirement, consider commit/reveal
or VRF. Otherwise, document this as an accepted risk.

L-04: CEI ordering in ProverAuction external transfers
Location: packages/protocol/contracts/layer1/core/impl/ProverAuction.sol:
208-229, 312-342
Details: deposit() transfers before balance update; slashProver() transfers
reward before optional pool ejection. nonReentrant limits impact, but OZ
guidance favors effects before interactions.
Recommendation: Consider reordering effects before external calls if practical.

Suggested test gaps

- Inbox propose() payment flow:
  - msg.value + forced inclusion fees == prover fee (no refund)
  - msg.value + forced inclusion fees > prover fee (refund path)
  - insufficient msg.value triggers InsufficientProverFee
  - designatedProver rejects ETH (ensure intended behavior is exercised)
- Proof slashing path:
  - On-time vs late proof behavior for slashProver
  - actualProver reward handling
- ProverAuction:
  - checkBondDeferWithdrawal behavior for self-prover path
  - slashProver ejection threshold edge cases
- Transition designatedProver consistency (if intended): add a test that
  mismatched designatedProver in proof commitment is rejected.

Open questions

1) Does the proof circuit bind commitment.transitions[].designatedProver to
   proposal hashes, or is this only validated off-chain? If not bound, slashing
   could be misdirected.
2) Is keeping unpaid prover fees in the Inbox acceptable, or should they be refundable/claimable?

Checks performed

- Reviewed PR diff for Inbox.sol and current ProverAuction.sol implementation.
- Verified payment flow and ETH transfer behavior (LibAddress sendEther/sendEtherAndVerify).
- Searched for any Inbox ETH sweep/withdraw paths (none found).
