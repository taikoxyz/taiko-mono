-------------------------- MODULE EtnaSignerCrash --------------------------
EXTENDS Naturals, TLC
\* Process-crash model, not power-loss durability or HRS implementation refinement.
CONSTANTS MaxSlot, Payloads, SignatureSalts, PersistBeforeExpose, PreserveHRSOnCrash,
          PreserveGenerationFence, ReconnectAfterTrust, RejectConflicts, EchoRequest
Domains == 0..1
Slots == 1..MaxSlot
ASSUME /\ MaxSlot \in 1..2 /\ {"A", "B"} \subseteq Payloads
       /\ Payloads \subseteq {"A", "B", "Nil"}
       /\ 0 \in SignatureSalts /\ SignatureSalts \subseteq 0..1
       /\ {PersistBeforeExpose, PreserveHRSOnCrash, PreserveGenerationFence,
             ReconnectAfterTrust, RejectConflicts, EchoRequest} \subseteq BOOLEAN
EmptyRecord(d) == [domain |-> d, slot |-> 0, payload |-> "None", signature |-> <<>>]
Record(d, s, p, salt) ==
    [domain |-> d, slot |-> s, payload |-> p, signature |-> <<d, s, p, salt>>]
Records == {Record(d, s, p, salt) : d \in Domains, s \in Slots,
             p \in Payloads, salt \in SignatureSalts}
EmptyRequest == [domain |-> 0, slot |-> 0, payload |-> "None"]
RequestType == [domain : Domains, slot : 0..MaxSlot, payload : Payloads \cup {"None"}]
AllRecords == Records \cup {EmptyRecord(d) : d \in Domains}
VARIABLES running, trusted, connected, certain, activeDomain, knownFloor,
          durableFloor, everFloor, durable, phase, pending, reuse, restarted,
          actualRequest, crashRecord, writes, returned, network, delivered, faults, event
vars == <<running, trusted, connected, certain, activeDomain, knownFloor,
          durableFloor, everFloor, durable, phase, pending, reuse, restarted,
          actualRequest, crashRecord, writes, returned, network, delivered, faults, event>>
Init ==
    /\ running = TRUE /\ trusted = FALSE /\ connected = FALSE /\ certain = TRUE
    /\ activeDomain = 0 /\ knownFloor = 0 /\ durableFloor = 0 /\ everFloor = 0
    /\ durable = [d \in Domains |-> EmptyRecord(d)]
    /\ phase = "Idle" /\ pending = EmptyRecord(0) /\ reuse = FALSE /\ restarted = FALSE
    /\ actualRequest = EmptyRequest /\ crashRecord = EmptyRecord(0)
    /\ writes = {} /\ returned = {} /\ network = {} /\ delivered = {}
    /\ faults = [durability |-> FALSE, uncertain |-> FALSE, trust |-> FALSE, oldDomain |-> FALSE, request |-> FALSE]
    /\ event = "None"

\* M02 trust/authentication is an interface premise. One serialized key owner.
AuthenticateTrust(d) ==
    /\ running /\ certain /\ phase = "Idle" /\ d >= knownFloor
    /\ (d = 0 \/ knownFloor = 1)
    /\ activeDomain' = d /\ trusted' = TRUE /\ event' = "Trust"
    /\ UNCHANGED <<running, connected, certain, knownFloor, durableFloor, everFloor,
          durable, phase, pending, reuse, restarted, writes, returned, network, delivered, faults>>
    /\ UNCHANGED actualRequest
    /\ UNCHANGED crashRecord
Connect ==
    /\ running /\ phase = "Idle" /\ (~ReconnectAfterTrust \/ trusted)
    /\ connected' = TRUE /\ event' = "Connect"
    /\ UNCHANGED <<running, trusted, certain, activeDomain, knownFloor, durableFloor,
          everFloor, durable, phase, pending, reuse, restarted, writes, returned, network, delivered, faults>>
    /\ UNCHANGED actualRequest
    /\ UNCHANGED crashRecord

\* Completed recovery authentication establishes a persistent generation floor.
\* This chosen realization is an additional interface contract, NOT FilePV HRS.
\* It may interleave with computed/persisted old work; that work cannot escape.
AuthenticateRecovery ==
    /\ running /\ certain
    /\ knownFloor' = 1 /\ everFloor' = 1
    /\ durableFloor' = IF PreserveGenerationFence THEN 1 ELSE durableFloor
    /\ trusted' = FALSE /\ connected' = FALSE
    /\ phase' = "Idle" /\ pending' = EmptyRecord(0) /\ reuse' = FALSE
    /\ event' = "RecoveryAuth"
    /\ UNCHANGED <<running, certain, activeDomain, durable, restarted,
                    writes, returned, network, delivered, faults>>
    /\ actualRequest' = EmptyRequest
    /\ UNCHANGED crashRecord

\* Rank 1..MaxSlot abstracts lexicographic H/R/S; payload Nil uses this same path.
Request(d, s, p, salt, appReply) ==
    /\ running /\ certain /\ trusted /\ connected /\ appReply /\ phase = "Idle"
    /\ d = activeDomain /\ d >= knownFloor /\ s >= durable[d].slot
    /\ (s > durable[d].slot \/ p = durable[d].payload \/ ~RejectConflicts)
    /\ reuse' = (s = durable[d].slot /\ p = durable[d].payload)
    /\ actualRequest' = [domain |-> d, slot |-> s, payload |-> p]
    /\ pending' = IF reuse' THEN durable[d]
                    ELSE Record(d, s, IF EchoRequest THEN p ELSE IF p = "A" THEN "B" ELSE "A", salt)
    /\ phase' = IF reuse' THEN "Persisted" ELSE "Computed"
    /\ event' = IF reuse' THEN "RetryRecorded" ELSE "Computed"
    /\ UNCHANGED <<running, trusted, connected, certain, activeDomain, knownFloor,
          durableFloor, everFloor, durable, restarted, writes, returned, network, delivered, faults>>
    /\ UNCHANGED crashRecord
Persist ==
    /\ running /\ certain /\ phase = "Computed"
    /\ durable' = [durable EXCEPT ![pending.domain] = pending]
    /\ writes' = writes \cup {durable'[pending.domain]}
    /\ phase' = "Persisted" /\ event' = "Persisted"
    /\ UNCHANGED <<running, trusted, connected, certain, activeDomain, knownFloor,
          durableFloor, everFloor, pending, reuse, restarted, returned, network, delivered, faults>>
    /\ UNCHANGED actualRequest
    /\ UNCHANGED crashRecord

\* Exposure is signature return/network enqueue, checked against CURRENT trust/floor.
Expose(appReply) ==
    /\ running /\ certain /\ trusted /\ connected /\ appReply
    /\ phase \in {"Computed", "Persisted"}
    /\ (~PersistBeforeExpose \/ phase = "Persisted")
    /\ pending.domain = activeDomain /\ pending.domain >= knownFloor
    /\ returned' = returned \cup {pending} /\ network' = network \cup {pending}
    /\ faults' = [faults EXCEPT
          !.durability = @ \/ durable[pending.domain] # pending,
          !.uncertain = @ \/ ~certain, !.trust = @ \/ ~trusted,
          !.oldDomain = @ \/ pending.domain < everFloor,
          !.request = @ \/ pending.domain # actualRequest.domain \/
                            pending.slot # actualRequest.slot \/ pending.payload # actualRequest.payload]
    /\ phase' = "Idle"
    /\ event' = IF reuse /\ restarted /\ pending = crashRecord /\ crashRecord.slot > 0
                  THEN "ReplayAfterRestart" ELSE "Expose"
    /\ UNCHANGED <<running, trusted, connected, certain, activeDomain, knownFloor,
          durableFloor, everFloor, durable, pending, reuse, restarted, writes, delivered>>
    /\ UNCHANGED actualRequest
    /\ UNCHANGED crashRecord
Deliver(record) ==
    /\ record \in network
    /\ delivered' = delivered \cup {record} /\ event' = "Delivered"
    /\ UNCHANGED <<running, trusted, connected, certain, activeDomain, knownFloor,
          durableFloor, everFloor, durable, phase, pending, reuse, restarted,
          writes, returned, network, faults>>
    /\ UNCHANGED actualRequest
    /\ UNCHANGED crashRecord

Crash ==
    /\ running
    /\ event' = IF phase = "Computed" THEN "BeforeWriteCrash"
                  ELSE IF phase = "Persisted" /\ pending \notin returned
                    THEN "AfterWriteCrash" ELSE "Crash"
    /\ running' = FALSE /\ trusted' = FALSE /\ connected' = FALSE
    /\ phase' = "Idle" /\ pending' = EmptyRecord(0) /\ reuse' = FALSE /\ knownFloor' = 0
    /\ durable' = IF PreserveHRSOnCrash THEN durable ELSE [d \in Domains |-> EmptyRecord(d)]
    /\ UNCHANGED <<certain, activeDomain, durableFloor, everFloor, restarted,
                    writes, returned, network, delivered, faults>>
    /\ actualRequest' = EmptyRequest
    /\ crashRecord' = IF phase = "Persisted" THEN durable[pending.domain] ELSE EmptyRecord(0)
Restart ==
    /\ ~running /\ running' = TRUE /\ trusted' = FALSE /\ connected' = FALSE
    /\ knownFloor' = durableFloor /\ restarted' = TRUE /\ event' = "Restart"
    /\ UNCHANGED <<certain, activeDomain, durableFloor, everFloor, durable, phase,
                    pending, reuse, writes, returned, network, delivered, faults>>
    /\ UNCHANGED actualRequest
    /\ UNCHANGED crashRecord
MarkUncertain ==
    /\ running /\ certain /\ certain' = FALSE /\ trusted' = FALSE /\ connected' = FALSE
    /\ phase' = "Idle" /\ pending' = EmptyRecord(0) /\ reuse' = FALSE /\ event' = "Uncertain"
    /\ UNCHANGED <<running, activeDomain, knownFloor, durableFloor, everFloor,
                    durable, restarted, writes, returned, network, delivered, faults>>
    /\ actualRequest' = EmptyRequest
    /\ UNCHANGED crashRecord
Next == \/ \E d \in Domains : AuthenticateTrust(d)
        \/ Connect \/ AuthenticateRecovery
        \/ \E d \in Domains, s \in Slots, p \in Payloads, salt \in SignatureSalts,
              reply \in BOOLEAN : Request(d, s, p, salt, reply)
        \/ Persist \/ \E reply \in BOOLEAN : Expose(reply)
        \/ \E record \in network : Deliver(record)
        \/ Crash \/ Restart \/ MarkUncertain
SignerSpec == Init /\ [][Next]_vars
SignerTypeOK ==
    /\ {running, trusted, connected, certain, reuse, restarted} \subseteq BOOLEAN
    /\ {activeDomain, knownFloor, durableFloor, everFloor} \subseteq Domains
    /\ durable \in [Domains -> AllRecords] /\ pending \in AllRecords
    /\ actualRequest \in RequestType /\ crashRecord \in AllRecords
    /\ phase \in {"Idle", "Computed", "Persisted"}
    /\ writes \subseteq Records /\ returned \subseteq Records
    /\ network \subseteq returned /\ delivered \subseteq network
    /\ faults \in [durability : BOOLEAN, uncertain : BOOLEAN, trust : BOOLEAN, oldDomain : BOOLEAN, request : BOOLEAN]
    /\ event \in {"None", "Trust", "Connect", "RecoveryAuth", "RetryRecorded", "Computed",
          "Persisted", "ReplayAfterRestart", "Expose", "Delivered", "BeforeWriteCrash",
          "AfterWriteCrash", "Crash", "Restart", "Uncertain"}
PendingMatchesActualRequest == phase \in {"Computed", "Persisted"} =>
    (pending.domain = actualRequest.domain /\ pending.slot = actualRequest.slot /\
      pending.payload = actualRequest.payload)
ExposureMatchesActualRequest == ~faults.request
ExposureWasDurable == ~faults.durability /\ returned \subseteq writes
DurableHRSRetainsReturns == \A r \in returned : durable[r.domain].slot >= r.slot
ReturnedSlotUnique == \A a, b \in returned :
    (a.domain = b.domain /\ a.slot = b.slot) => a = b
DeliveredSlotUnique == \A a, b \in delivered :
    (a.domain = b.domain /\ a.slot = b.slot) => a = b
ReplayUsesRecordedSignature == (reuse /\ phase = "Persisted") => pending = durable[pending.domain]
ConnectedAfterFreshTrust == connected => (running /\ trusted)
NoUncertainExposure == ~faults.uncertain
NoUntrustedExposure == ~faults.trust
NoOldDomainExposure == ~faults.oldDomain
BeforeWriteCrashNotReached == event # "BeforeWriteCrash"
AfterWriteCrashNotReached == event # "AfterWriteCrash"
DurableReplayNotReached == event # "ReplayAfterRestart"
RestartFenceNotReached == ~(event = "Restart" /\ knownFloor = 1 /\ durableFloor = 1 /\ everFloor = 1)
UncertainStopNotReached == ~(~certain /\ ~trusted /\ ~connected)
=============================================================================
