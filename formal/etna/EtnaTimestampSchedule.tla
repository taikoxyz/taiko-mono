---------------------- MODULE EtnaTimestampSchedule ----------------------
EXTENDS Naturals, Integers, Sequences
\* Current SPEC 2e6763e21, START-10.1. No height-grid schedule exists.
FieldLimit == 999
CancelTime == 999
NonceLimit == 9
ZeroSchedule == [active |-> 0,next |-> 0,time |-> 0,stop |-> 0]
ScheduleTyped(q) == /\ DOMAIN q={"active","next","time","stop"}
                   /\ \A f \in DOMAIN q:q[f] \in 0..FieldLimit
SlotFields(q) == <<q.active,q.next,q.time,q.stop>>
RulesAllowed(q,r,t,now,m,owner,initialized) ==
 /\ owner /\ initialized /\ r \in 0..FieldLimit /\ t \in 0..FieldLimit
 /\ now+m<CancelTime /\ (now>=q.time \/ now+m<q.time)
 /\ r \in {q.next,q.next+1} /\ t>=now+m
RulesAfter(q,r,t,now) == [q EXCEPT !.active=IF now>=q.time THEN q.next ELSE @,
                                  !.next=r,!.time=t]
StopAllowed(q,t,now,m,owner,initialized) ==
 /\ owner /\ initialized /\ t \in 0..FieldLimit /\ now+m<CancelTime
 /\ (q.stop=0 \/ now+m<q.stop) /\ (t=0 \/ t>=now+m)
StopAfter(q,t) == [q EXCEPT !.stop=t]
Selected(q,t) == IF t>=q.time THEN q.next ELSE q.active
ParentStopped(q,parentTime) == q.stop#0 /\ parentTime>=q.stop
RecoveryAllowed(q,r) == r=0 \/ (r=q.next+1 /\ r<=FieldLimit)
RecoveryAfter(q,r) ==
 IF r=0 THEN [q EXCEPT !.stop=0]
 ELSE [active |-> r,next |-> r,time |-> 0,stop |-> 0]
=============================================================================
