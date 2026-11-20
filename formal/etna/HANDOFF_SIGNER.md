# Queued-proof handoff / actual signer actions

`EtnaHandoffSigner` extends the reviewed `EtnaStopProofHandoff` and uses a
namespaced `INSTANCE EtnaSignerCrash`. Every signer variable is distinct from
the handoff variables. In particular, the old handoff session's `trusted` and
`appReply` remain revoked after recovery; they are never aliases for the new
signer session. Original engines and configs remain unchanged. Normative mapping
uses SPEC commit `d18357214fab30ea512ae9858a11699806d72ba1`.

## Selected product and interface premises

The three finite profiles select the supported Future positive-stop program.
Actual support installation at public index2 makes the immutable held generation0
candidate return `Outcome = "Accept"` before recovery. The Due program's held
candidate cannot supply this work; it is deliberately outside these selected
profiles. `OldReply` and `FreshReply` call the inherited actual `Outcome` and bind
the candidate generation to the requested session domain. No acceptance engine
or signer guard is copied.

Authenticated L1 recovery evidence and each selected domain's authenticated
session credentials remain explicit environment inputs. The model calls actual
`AuthenticateTrust`, starting from the actual signer's untrusted Init, and actual
`Connect` before requests. It does not implement L1 client authentication,
FilePV bytes, concrete signatures, key ownership, consensus voting or signed
block admission. Two domains0..1 and two abstract per-domain HRS ranks1..2 are
used; rank is not a concrete height/round/step serialization. One serialized
signer and process crashes are assumed, not power-loss durability.

The inherited generation0 proof is opaque and independent of the held candidate.
Its validity and retained landing reference remain fixed availability premises,
not M07-produced proof, physical retention or real ZK evidence.

## Executed sequence

Each profile executes the original public Stop/Rules calls, actual hold,
support installation, proof queue and pre-recovery landing observation.
The signer then authenticates domain0, connects and requests `(0,2,A)`.
`Computed` leaves this pending without persistence; `Persisted` persists it;
`Exposed` persists and exposes it, then requests the same record again through
the actual durable-reuse path. Public Recover is held behind this real prework.

`SignerHandoff` invokes unchanged `StopProofNext`, filtering out uncoupled local
floor changes. After accepted Recover and the actual old-proof attempt,
`SignerLearnRecovery` joins the inherited `AuthenticateRecovery` with the
signer's actual action in one transition. Both learned floors move together;
the durable signer floor is independently observed. Expected floor values are
assertions, not action guards. A later signer recovery refresh reuses the same
accepted recovery evidence before establishing fresh domain1 trust.

After recovery knowledge, an actual exposure attempt is refused. Actual Crash
and Restart follow, then attempts to authenticate the old domain, connect,
request the same old record, persist and expose it. Each attempt computes
`ENABLED` for the actual action and executes it iff enabled, otherwise framing
signer state. Expected denial appears only in independent audits/witnesses.
This retry is necessary: recovery itself clears pending work, so merely attempting
exposure immediately afterward would hide a missing durable generation fence.

The Exposed profile delivers its already-enqueued old signature after recovery.
Such delivery is permitted and is not new signing. Its stale retry would re-expose
the identical signature under an omitted floor, so the sequence records each
actual exposure event even when returned/network sets do not change.

Fresh authenticated domain1 then requests, persists and exposes `(1,1,A)` and
`(1,2,B)` using the actual fresh candidate's application outcome. A second actual
Crash/Restart preserves both domains' HRS records. After new trust/connect,
`(1,1,B)` is attempted; rollback/conflict must be refused. Raw receipts preserve
the before/after durable, request, phase, floor, returned, network and delivered
observations. They are observational state, not another signer implementation.

## Audits, witnesses and controls

Three normal profiles retain all G04 normal audits and add signer typing/bridge,
raw exposure-floor and raw exposure-HRS audits. Normal results require complete
queue exhaustion. Three terminal witnesses require the full G04 terminal, actual
prework, accepted public recovery, coupled knowledge, refused old attempts,
restored durable state, both successful fresh writes/returns and the final
refused rollback. The Exposed witness additionally requires actual durable reuse
and delayed old delivery. `SignerTerminalNotReached` is intentionally violated:
this is finite existential reachability, not an eventual-progress theorem.

Focused floor and HRS audit configs intentionally omit unrelated bridge audits
so an actual bad exposure is the named result. The floor source control removes
only the durable-floor write inside actual `EtnaSignerCrash.AuthenticateRecovery`;
the stale retry then exposes domain0 after knowledge1, including an idempotent
repeat in the Exposed profile. The HRS source control removes only crash HRS
preservation; the final actual rollback/conflicting exposure violates the raw
HRS audit. These are distinct selected-product obligations, not closure of the
broader signer/L1-trust/composition inventory.

Disabling required actual Request, Persist, Expose, AuthenticateRecovery, Crash
or Restart must instead lose the required complete terminal witness while the
normal profile safely exhausts. Such reachability-loss controls do not count as
safety kills or inflate the assessed fault denominator. Parse errors, setup
failures, timeouts and wrong named violations never qualify. The existing shared
sensitivity supervisor remains authoritative for source-fault/restoration runs.

## Limits

These scripted traces cover selected legal prework and restart boundaries, not
all signer interleavings, all schedules or liveness. They retain G04's historical
candidate/proof assumptions and abstract authenticated-input premises. No native
signer, real node, key, network protocol or transaction is exercised, and no
unassessed whole-module category is closed by this subset.
