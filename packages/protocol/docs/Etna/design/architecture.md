# Etna architecture map — non-normative

This is a navigation guide to the seven HTML reference pages, not an additional specification or a review verdict. The linked HTML rules control every encoding, predicate, interface and parameter. **Assumed — A-IMPLEMENTATION:** the mechanism summaries below describe the specified rules, not deployed behavior. Claim labels and conditional proofs are defined in [Arguments](arguments.html#classification); current review status is controlled solely by [Arguments: verdict](arguments.html#verdict).

| Read | Controlling reference |
|---|---|
| Canonical state, one-second soft service and atomic L1 acceptance | [Core specification](index.html#state) |
| Prior public data, exact context and producer assent | [Staging](staging.html#encoding) |
| Execution profile, complete bytes, anchors and fragment commitments | [Codec](codec.html#profile) |
| Open roles, lifecycle, funding and economics | [Roles](roles.html#role-matrix) |
| Signed duties, publication receipts, evidence and payouts | [Accountability](accountability.html#obligations) |
| Existing custody contracts and the legacy-to-Etna boundary | [Migration](migration.html#boundary) |
| Conditional safety/liveness, requirement claims and limitations | [Arguments](arguments.html#assumptions) |

## From a soft block to an accepted head

Any address may build, stage, authorize, prove or relay an eligible candidate under the objective rules. No publisher ticket, custodian certificate, assigned worker, CL lookahead or exclusive sequencer grants canonical priority. Ethereum chooses among eligible proof-bearing successors. See [role boundary](roles.html#boundary) and [producer authorization](staging.html#authorization).

The soft service targets one-second issuance. A node checks the complete block, parent, authenticated origin, anchor and execution locally; a missing dependency is UNKNOWN. Soft validity does not imply canonical selection or finality. The exact bytes and commitments are fixed by the [codec](codec.html#body), [manifests](codec.html#manifests) and [preconfirmation rules](codec.html#preconf). User latency and the bounded unsafe horizon are specified in [core preconfirmation](index.html#preconf).

A sealed candidate first publishes actual complete data and execution context through the nonexclusive DARegistry. Its selected receipt must be 360–900 seconds old at acceptance, while the authenticated origin also satisfies its separate freshness limit. Staging reserves no parent and publishes no checkpoint. The later payable canonical action republishes the complete matching data **together with the valid proof**, checks authorization, current parent, forced work and admission rent, then atomically advances the head and publishes its checkpoint. Follow [stage lifecycle](staging.html#lifecycle), [acceptance](staging.html#acceptance), [landing](index.html#landing), [verifier interface](index.html#verifier-interface) and [DA modes](index.html#da).

The execution context commitment determines the ordinary successor Head; payment, job and staging-salt choices are recorded separately and do not mutate identical execution history. [Core state](index.html#state) and [staging encoding](staging.html#encoding) define the exact noncircular hashes. Ethereum finality remains distinct from acceptance.

## Bonded fragments and objective evidence

Every publisher or custodian **EtnaDuty version-2 DutyClaim** promises complete fragment calldata **and the exact FR preimage by `issuedAt+240`**. Any holder may fulfill it. The immutable first matching receipt decides timeliness; generic blob staging alone does not discharge a fragment promise. No prior challenge is needed to prove a missed deadline, and late publication cannot cure it. See [fragment publication](accountability.html#fragment-publication).

An optional paid challenge is admitted only before that absolute deadline and ends at `min(openedAt+600, publishBy)`; it cannot extend the promise. A first targeted timely response receives one Q deposit. Standalone publication earns no Q, other timely satisfied challenges refund, and late publication earns no timely-response reward. There is no post-publication personal server-retention duty. Exact settlement is in [challenge](accountability.html#challenge) and [multiple claims](accountability.html#multiple).

Each position reserves 10 TAIKO and can be slashed only once across offenses. A bucket has 60 positions, a 60-second issuance window and evidence closing 3,600 seconds after that window. Key rotation does not reset old liability. A separate sealed-context publication covenant uses its own position; owner-authorized conflicting blocks have a deliberately bounded attribution predicate. See [registry lifecycle](roles.html#registry), [sealed publication](accountability.html#sealed-publication), [canonical conflict](accountability.html#canonical-conflict) and [accounting](accountability.html#accounting). These observable duties do not prove historical P2P intent or guarantee that a soft branch wins.

## Canonical rent, funding and recovery

Every successful head acceptance pays the same identity-independent Dutch rent:

`q = ceil(0.05 ETH × max(900 − age, 0) / 900)`, with a zero floor at 900 seconds.

The separate `rentReferenceTime` starts at activation and resets on **every successful acceptance**. Staging, jobs, failed calls and ordinary reads cannot reset it. All rent enters a permanent nonwithdrawable sink; excess value credits the actual Inbox caller. There is no bid reservation or exclusive winner. [Core rent](index.html#rent) controls admission, and [role rent economics](roles.html#rent) gives exact arithmetic and the conditional repeated-capture cost argument. Its positive bound requires a ready, willing, funded competitor and inclusion before the zero floor; it is not a market-diversity or unlimited-MEV guarantee.

An unchanged head eventually has zero rent, but old origins or stages may have expired: a replacement may need fresh inputs, restaging and proving. Normal Ethereum costs remain. Positive-rent frame submissions use individually funded sender accounts; the shared sender/nonce form is restricted to zero SENDER-frame value. The [frame rules](index.html#frames) and ordinary payable fallback preserve atomic acceptance. Voluntary [proof jobs](roles.html#jobs) grant no submission veto; historical receipts determine success, innocent cancellation or default.

## Forced FIFO and the exact migration boundary

A Head freezes the queue snapshot used by its child. Each ordinary child processes the required prefix of up to four mature requests before discretionary traffic, including proved rejection outcomes. Later arrivals cannot overtake an existing index. Pending fees remain liabilities until processing splits them equally between beneficiary credit and the permanent sink. Exact bounds and conditional progress are in [forced inclusion](index.html#forced), [forced-byte encoding](codec.html#forced) and [FIFO argument](arguments.html#l2).

The [bootstrap definition](migration.html#bootstrap) constructs a unique H0 from the authenticated final legacy fields and a domain-separated bootstrap commitment. Segment number, consumed cursor, initial force cut/time and origin pair use the explicit zero sentinel. This is a one-time boundary, not a caller-selected snapshot. The first segment uses a real origin at or after activation, proves ACTIVE through `beginEtna`, consumes no forced requests and installs the first normal snapshot. Pre-activation queue records and fee liabilities remain preserved; subsequent children follow ordinary FIFO. The same section defines exact hashing, phase gates, a first-successor example and the bounded calldata bootstrap composition.

Bridge, SignalService and all existing ERC20/ERC721/ERC1155 Vault addresses remain. Their exact checkpoint provenance and storage-compatible changes are controlled by [checkpoint interfaces](migration.html#checkpoint), [upgrade inventory](migration.html#inventory), [operational authority removal](migration.html#authority) and [migration](migration.html#migration). The DAO governs upgrades only; routine operation and recovery have no DAO action.

## Assumptions and review status

Use [dependencies](index.html#dependencies) for the L1 feature boundary, [assumptions](arguments.html#assumptions) for cryptography, DA, funding, proving, inclusion and archive premises, and [limitations](arguments.html#limits) for their practical scope. [Preflight](migration.html#preflight) separates launch verification from a design argument. This map makes no independent readiness claim; consult the current [verdict](arguments.html#verdict) and [requirement dispositions](arguments.html#requirements).
