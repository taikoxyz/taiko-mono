------------------ MODULE EtnaTimestampRecoveryProduct ------------------
EXTENDS EtnaTimestampSchedule, FiniteSets, TLC
CONSTANTS Scenario, MaxL1, MaxHeight, MaxProduces, MaxWrites
VARIABLES s,bad,last,seen
vars == <<s,bad,last,seen>>
\* Number and timestamp are separate fields, even in this small L1 chain.
N(i) == 31+i
T(i) == 100+i
M == 2
U == 2
Heights == 0..MaxHeight
Indexes == 0..MaxL1
Slots == 1..2
Origin(i,g,h) == [generation |-> g,height |-> h,number |-> N(i),timestamp |-> T(i),index |-> i]
View(i,g,c,q) == [number |-> N(i),timestamp |-> T(i),generation |-> g,checkpoint |-> c,schedule |-> q]
Pair(x) == <<x,x>>
Max3(a,b,c) == IF a>=b /\ a>=c THEN a ELSE IF b>=c THEN b ELSE c
InitialView == View(0,0,0,ZeroSchedule)
Genesis == [height |-> 0,generation |-> 0,parentTime |-> 99,bft |-> 100,time |-> 99,
            anchor |-> InitialView,rule |-> 0,first |-> FALSE]
EL(b) == <<b.generation,b.height,b.time,b.bft,b.anchor.number,b.rule>>
Cut(b) == <<b.height,EL(b),IF b.height=0 THEN <<>> ELSE <<9,EL(b)>>,b.height>>
CurrentOrigin == s.origins[s.generation+1]
Parent == s.blocks[s.head+1]
V(i) == s.views[i+1]
Rec(h) == s.records[h+1]
Write(r) == [r EXCEPT !.views[r.index+1]=View(r.index,r.generation,r.c,r.schedule)]
Init ==
 /\ T(MaxL1)+M<CancelTime
 /\ s=[schedule |-> ZeroSchedule,generation |-> 0,c |-> 0,nonce |-> 0,head |-> 0,
       fi |-> 0,activeSnapshot |-> N(0),index |-> 1,finalized |-> 0,ready |-> TRUE,
       origins |-> <<Origin(0,0,0),<<>>>>,auth |-> <<>>,software |-> {0},
       blocks |-> [i \in 1..(MaxHeight+1) |-> IF i=1 THEN Genesis ELSE <<>>],
       records |-> [i \in 1..(MaxHeight+1) |-> IF i=1 THEN <<0,0,Cut(Genesis),N(0)>> ELSE <<>>],
       views |-> [i \in 1..(MaxL1+1) |-> IF i<=2 THEN View(i-1,0,0,ZeroSchedule) ELSE <<>>],
       jobs |-> Pair(<<>>),proofs |-> Pair(Pair(<<>>)),published |-> Pair(<<>>),
       produces |-> 0,writes |-> 0,initialized |-> TRUE,startWritten |-> TRUE]
 /\ bad=FALSE /\ last= <<0,<<>>,FALSE,<<>>>>
 /\ seen=[terminal |-> 0,stopRefused |-> FALSE,recovered |-> FALSE,fresh |-> 0,stale |-> FALSE,
          noStop |-> FALSE,distinctClocks |-> FALSE]

Candidate(a,b) ==
 LET v==V(a) t==Max3(Parent.time+1,b,v.timestamp)
 IN [height |-> s.head+1,generation |-> s.generation,parentTime |-> Parent.time,bft |-> b,time |-> t,
     anchor |-> v,rule |-> Selected(v.schedule,t),first |-> s.head=CurrentOrigin.height]
ProduceAllowed(a,b,known) ==
 LET x==Candidate(a,b) v==V(a)
 IN /\ s.ready /\ s.produces<MaxProduces /\ s.head<MaxHeight /\ a<=s.finalized
    /\ a>=CurrentOrigin.index /\ v.generation=s.generation
    /\ IF s.head=CurrentOrigin.height THEN b=CurrentOrigin.timestamp ELSE
          a>=Parent.anchor.number-31 /\ b>=Parent.bft
    /\ x.time-v.timestamp<=M /\ s.head+1<=v.checkpoint+U
    /\ ~ParentStopped(v.schedule,Parent.time) /\ x.rule \in known /\ known=s.software
ProduceAfter(a,b) == [s EXCEPT !.head=@+1,!.produces=@+1,!.blocks[s.head+2]=Candidate(a,b)]
Range(p,h) == SubSeq(s.blocks,p+2,h+1)
Cuts(p,h) == [i \in 1..(h-p+1) |-> Cut(s.blocks[p+i])]
Bound(g,p,h,ref,snap,cuts,data) ==
 LET lo==cuts[1] hi==cuts[Len(cuts)]
 IN <<1,1,167000,4369,8738,g,p,lo[2],lo[3],333,h,hi[2],hi[3],444,ref,500+ref,
      data,lo[4],hi[4],snap,<<2,g,p,h,SubSeq(cuts,2,Len(cuts)-1)>>>>
Captured(p,h,ref) ==
 LET cuts==Cuts(p,h) data==Range(p,h) snap==CurrentOrigin.number
 IN [generation |-> s.generation,p |-> p,h |-> h,reference |-> N(ref),snapshot |-> snap,
     cuts |-> cuts,data |-> data,statement |-> Bound(s.generation,p,h,N(ref),snap,cuts,data)]
CaptureAllowed(j,p,h,ref) ==
 /\ j=s.generation+1 /\ s.jobs[j]= <<>> /\ CurrentOrigin.height<=p /\ p<=s.c /\ s.c<h /\ h<=s.head
 /\ Rec(p)#<<>> /\ (Rec(p)[1]=s.generation \/ p=CurrentOrigin.height)
 /\ ref<=s.index /\ ref>=CurrentOrigin.index /\ Rec(p)[4]<=N(ref)
 /\ \A i \in 1..(h-p):Range(p,h)[i].generation=s.generation /\ Range(p,h)[i].anchor.number<=N(ref)
CaptureAfter(j,p,h,ref) == [s EXCEPT !.jobs[j]=Captured(p,h,ref)]
ImageCovers(x,image) == \A i \in 1..Len(x.data):x.data[i].rule \in image
CompleteAllowed(j,b,image) == s.jobs[j]#<<>> /\ ImageCovers(s.jobs[j],image)
CompleteAfter(j,b,image) == [s EXCEPT !.proofs[j][b]= <<s.jobs[j].statement,image>>]
Ready(j) ==
 IF s.jobs[j]= <<>> THEN FALSE ELSE
 LET x==s.jobs[j] cur==Rec(s.c) origin==Rec(x.p)
 IN /\ x.generation=s.generation /\ CurrentOrigin.height<=x.p /\ x.p<=s.c /\ s.c<x.h
    /\ origin#<<>> /\ (origin[1]=s.generation \/ x.p=CurrentOrigin.height)
    /\ origin[3]=x.cuts[1] /\ cur[3][4]=s.fi
    /\ IF x.p=s.c THEN cur[3]=x.cuts[1] ELSE x.cuts[s.c-x.p+1]=cur[3]
    /\ x.reference<N(s.index) /\ N(s.index)-x.reference<=5 /\ x.h-x.p<=6
    /\ s.published[j]=x.data
    /\ \A b \in 1..2:s.proofs[j][b]#<<>> /\ s.proofs[j][b][1]=x.statement /\ ImageCovers(x,s.proofs[j][b][2])
LandAfter(j) ==
 LET x==s.jobs[j] hi==x.cuts[Len(x.cuts)]
 IN Write([s EXCEPT !.c=x.h,!.fi=hi[4],!.activeSnapshot=x.snapshot,
             !.records[x.h+1]= <<s.generation,s.c,hi,N(s.index)>>])
RecoverAllowed(a,owner) ==
 /\ a#<<>> /\ owner /\ s.initialized /\ s.startWritten
 /\ a[1]=s.generation /\ a[2]=s.c /\ a[3]=s.nonce /\ T(s.index)<=a[4]
 /\ s.generation<FieldLimit /\ s.nonce<NonceLimit /\ RecoveryAllowed(s.schedule,a[5])
RecoverAfter(a) ==
 LET g==s.generation+1 c==s.c
 IN Write([s EXCEPT !.schedule=RecoveryAfter(s.schedule,a[5]),!.generation=g,!.nonce=@+1,
          !.head=c,!.ready=FALSE,!.origins[g+1]=Origin(s.index,g,c),
          !.blocks=[i \in 1..(MaxHeight+1) |-> IF i<=c+1 THEN s.blocks[i] ELSE <<>>]])

\* Actual functions: keys1..13 are rules,stop,authorize,invalidate,recover,
\* L1 advance,finalize,observe,software,produce,capture,complete,publish,land.
Can(k,a) == CASE
 k=1 -> s.writes<MaxWrites /\ RulesAllowed(s.schedule,a[1],a[2],T(s.index),M,a[3],s.initialized)
 [] k=2 -> s.writes<MaxWrites /\ StopAllowed(s.schedule,a[1],T(s.index),M,a[2],s.initialized)
 [] k=3 -> TRUE
 [] k=4 -> a[2] /\ s.initialized /\ a[1]=s.nonce /\ s.nonce<NonceLimit
 [] k=5 -> RecoverAllowed(a[1],a[2])
 [] k=6 -> s.index<MaxL1
 [] k=7 -> a[1]>=s.finalized /\ a[1]<s.index
 [] k=8 -> s.finalized>=CurrentOrigin.index /\ V(s.finalized).generation=s.generation
 [] k=9 -> TRUE
 [] k=10 -> ProduceAllowed(a[1],a[2],a[3])
 [] k=11 -> CaptureAllowed(a[1],a[2],a[3],a[4])
 [] k=12 -> CompleteAllowed(a[1],a[2],a[3])
 [] k=13 -> s.jobs[a[1]]#<<>>
 [] k=14 -> Ready(a[1])
After(k,a) == CASE
 k=1 -> Write([s EXCEPT !.schedule=RulesAfter(s.schedule,a[1],a[2],T(s.index)),!.writes=@+1])
 [] k=2 -> Write([s EXCEPT !.schedule=StopAfter(s.schedule,a[1]),!.writes=@+1])
 [] k=3 -> [s EXCEPT !.auth= <<s.generation,s.c,s.nonce,a[2],a[1]>>]
 [] k=4 -> Write([s EXCEPT !.nonce=@+1])
 [] k=5 -> RecoverAfter(a[1])
 [] k=6 -> Write([s EXCEPT !.index=@+1])
 [] k=7 -> [s EXCEPT !.finalized=a[1]]
 [] k=8 -> [s EXCEPT !.ready=TRUE]
 [] k=9 -> [s EXCEPT !.software=a[1]]
 [] k=10 -> ProduceAfter(a[1],a[2])
 [] k=11 -> CaptureAfter(a[1],a[2],a[3],a[4])
 [] k=12 -> CompleteAfter(a[1],a[2],a[3])
 [] k=13 -> [s EXCEPT !.published[a[1]]=s.jobs[a[1]].data]
 [] k=14 -> LandAfter(a[1])
Event(k,a,ok) ==
 IF k=10 THEN LET x==Candidate(a[1],a[2]) IN <<x.rule,IF x.rule \notin a[3] THEN 2 ELSE IF ParentStopped(x.anchor.schedule,x.parentTime) THEN 3 ELSE 1,x.bft,x.time>>
 ELSE IF ok /\ k \in {1,2,5} THEN SlotFields(After(k,a).schedule) ELSE 0

\* Independently written literal admission: no calls to Can or operational
\* schedule/production/recovery admission functions.
LiteralTime(p,b,a) == IF p+1>=b /\ p+1>=a THEN p+1 ELSE IF b>=a THEN b ELSE a
ExpectedCan(k,a) == CASE
 k=1 -> /\ s.writes<MaxWrites /\ a[3] /\ s.initialized
         /\ a[1] \in 0..(999) /\ a[2] \in 0..(999)
         /\ (T(s.index)>=s.schedule.time \/ T(s.index)+2<s.schedule.time)
         /\ a[1] \in {s.schedule.next,s.schedule.next+1} /\ a[2]>=T(s.index)+2
 [] k=2 -> /\ s.writes<MaxWrites /\ a[2] /\ s.initialized /\ a[1] \in 0..(999)
          /\ (s.schedule.stop=0 \/ T(s.index)+2<s.schedule.stop) /\ (a[1]=0 \/ a[1]>=T(s.index)+2)
 [] k=3 -> TRUE
 [] k=4 -> a[2] /\ s.initialized /\ a[1]=s.nonce /\ s.nonce<9
 [] k=5 -> IF a[1]= <<>> THEN FALSE ELSE
          /\ a[2] /\ s.initialized /\ s.startWritten
          /\ a[1][1]=s.generation /\ a[1][2]=s.c /\ a[1][3]=s.nonce /\ T(s.index)<=a[1][4]
          /\ s.generation<999 /\ s.nonce<9
          /\ (a[1][5]=0 \/ (a[1][5]=s.schedule.next+1 /\ a[1][5]<=999))
 [] k=6 -> s.index<MaxL1
 [] k=7 -> s.finalized<=a[1] /\ a[1]<s.index
 [] k=8 -> s.finalized>=s.origins[s.generation+1].index /\ s.views[s.finalized+1].generation=s.generation
 [] k=9 -> TRUE
 [] k=10 -> LET v==s.views[a[1]+1] p==s.blocks[s.head+1]
                o==s.origins[s.generation+1] t==LiteralTime(p.time,a[2],v.timestamp)
                rule==IF t>=v.schedule.time THEN v.schedule.next ELSE v.schedule.active
            IN /\ s.ready /\ s.produces<MaxProduces /\ s.head<MaxHeight /\ a[1]<=s.finalized
               /\ a[1]>=o.index /\ v.generation=s.generation
               /\ IF s.head=o.height THEN a[2]=o.timestamp ELSE a[1]+31>=p.anchor.number /\ a[2]>=p.bft
               /\ t-v.timestamp<=2 /\ s.head+1<=v.checkpoint+2
               /\ (v.schedule.stop=0 \/ p.time<v.schedule.stop) /\ rule \in a[3] /\ a[3]=s.software
 [] k=11 -> /\ a[1]=s.generation+1 /\ s.jobs[a[1]]= <<>>
           /\ s.origins[s.generation+1].height<=a[2] /\ a[2]<=s.c /\ s.c<a[3] /\ a[3]<=s.head
           /\ s.records[a[2]+1]#<<>>
           /\ (s.records[a[2]+1][1]=s.generation \/ a[2]=s.origins[s.generation+1].height)
           /\ a[4]<=s.index /\ a[4]>=s.origins[s.generation+1].index /\ s.records[a[2]+1][4]<=31+a[4]
           /\ \A h \in (a[2]+1)..a[3]:s.blocks[h+1].generation=s.generation /\ s.blocks[h+1].anchor.number<=31+a[4]
 [] k=12 -> IF s.jobs[a[1]]= <<>> THEN FALSE ELSE \A i \in 1..Len(s.jobs[a[1]].data):s.jobs[a[1]].data[i].rule \in a[3]
 [] k=13 -> s.jobs[a[1]]#<<>>
 [] k=14 -> IF s.jobs[a[1]]= <<>> THEN FALSE ELSE
           LET x==s.jobs[a[1]] p==x.p h==x.h c==s.c origin==s.records[p+1] cur==s.records[c+1]
           IN /\ x.generation=s.generation /\ s.origins[s.generation+1].height<=p /\ p<=c /\ c<h
              /\ origin#<<>> /\ (origin[1]=s.generation \/ p=s.origins[s.generation+1].height)
              /\ origin[3]=x.cuts[1] /\ cur[3][4]=s.fi /\ x.cuts[c-p+1]=cur[3]
              /\ x.reference<31+s.index /\ 31+s.index-x.reference<=5 /\ h-p<=6
              /\ s.published[a[1]]=x.data
              /\ \A b \in 1..2:s.proofs[a[1]][b]#<<>> /\ s.proofs[a[1]][b][1]=x.statement
                   /\ \A i \in 1..Len(x.data):x.data[i].rule \in s.proofs[a[1]][b][2]

LiteralCapture(p,h,ref) ==
 LET data==[i \in 1..(h-p) |-> s.blocks[p+i+1]]
     cuts==[i \in 1..(h-p+1) |-> LET b==s.blocks[p+i]
          IN <<b.height,<<b.generation,b.height,b.time,b.bft,b.anchor.number,b.rule>>,
                IF b.height=0 THEN <<>> ELSE <<9,<<b.generation,b.height,b.time,b.bft,b.anchor.number,b.rule>>>>,b.height>>]
     snap==s.origins[s.generation+1].number lo==cuts[1] hi==cuts[h-p+1]
     st== <<1,1,167000,4369,8738,s.generation,p,lo[2],lo[3],333,h,hi[2],hi[3],444,31+ref,531+ref,
          data,lo[4],hi[4],snap,<<2,s.generation,p,h,SubSeq(cuts,2,h-p)>>>>
 IN [generation |-> s.generation,p |-> p,h |-> h,reference |-> 31+ref,snapshot |-> snap,cuts |-> cuts,data |-> data,statement |-> st]
LiteralWrite(r) == [r EXCEPT !.views[r.index+1]=[number |-> 31+r.index,timestamp |-> 100+r.index,generation |-> r.generation,checkpoint |-> r.c,schedule |-> r.schedule]]
ExpectedAfter(k,a) == CASE
 k=1 -> LiteralWrite([s EXCEPT !.schedule=[active |-> IF T(s.index)>=s.schedule.time THEN s.schedule.next ELSE s.schedule.active,
                next |-> a[1],time |-> a[2],stop |-> s.schedule.stop],!.writes=@+1])
 [] k=2 -> LiteralWrite([s EXCEPT !.schedule.stop=a[1],!.writes=@+1])
 [] k=3 -> [s EXCEPT !.auth= <<s.generation,s.c,s.nonce,a[2],a[1]>>]
 [] k=4 -> LiteralWrite([s EXCEPT !.nonce=@+1])
 [] k=5 -> LET q==IF a[1][5]=0 THEN [s.schedule EXCEPT !.stop=0]
                 ELSE [active |-> a[1][5],next |-> a[1][5],time |-> 0,stop |-> 0]
            g==s.generation+1
           IN LiteralWrite([s EXCEPT !.schedule=q,!.generation=g,!.nonce=@+1,!.head=s.c,!.ready=FALSE,
               !.origins[g+1]=[generation |-> g,height |-> s.c,number |-> 31+s.index,timestamp |-> 100+s.index,index |-> s.index],
               !.blocks=[i \in 1..(MaxHeight+1) |-> IF i<=s.c+1 THEN s.blocks[i] ELSE <<>>]])
 [] k=6 -> LiteralWrite([s EXCEPT !.index=@+1])
 [] k=7 -> [s EXCEPT !.finalized=a[1]]
 [] k=8 -> [s EXCEPT !.ready=TRUE]
 [] k=9 -> [s EXCEPT !.software=a[1]]
 [] k=10 -> LET p==s.blocks[s.head+1] v==s.views[a[1]+1] t==LiteralTime(p.time,a[2],v.timestamp)
           IN [s EXCEPT !.head=@+1,!.produces=@+1,!.blocks[s.head+2]=[height |-> s.head+1,generation |-> s.generation,
                  parentTime |-> p.time,bft |-> a[2],time |-> t,anchor |-> v,
                  rule |-> IF t>=v.schedule.time THEN v.schedule.next ELSE v.schedule.active,
                  first |-> s.head=s.origins[s.generation+1].height]]
 [] k=11 -> [s EXCEPT !.jobs[a[1]]=LiteralCapture(a[2],a[3],a[4])]
 [] k=12 -> [s EXCEPT !.proofs[a[1]][a[2]]= <<s.jobs[a[1]].statement,a[3]>>]
 [] k=13 -> [s EXCEPT !.published[a[1]]=s.jobs[a[1]].data]
 [] k=14 -> LET x==s.jobs[a[1]] z==x.cuts[Len(x.cuts)]
           IN LiteralWrite([s EXCEPT !.c=x.h,!.fi=z[4],!.activeSnapshot=x.statement[20],
                          !.records[x.h+1]= <<s.generation,s.c,z,31+s.index>>])
ExpectedEvent(k,a,ok) ==
 IF k=10 THEN LET p==s.blocks[s.head+1] v==s.views[a[1]+1] t==LiteralTime(p.time,a[2],v.timestamp)
                  r==IF t>=v.schedule.time THEN v.schedule.next ELSE v.schedule.active
              IN <<r,IF r \notin a[3] THEN 2 ELSE IF v.schedule.stop#0 /\ p.time>=v.schedule.stop THEN 3 ELSE 1,a[2],t>>
 ELSE IF ok /\ k \in {1,2,5} THEN LET q==ExpectedAfter(k,a).schedule IN <<q.active,q.next,q.time,q.stop>> ELSE 0

\* These are observations only. They never select a Next branch or transaction.
StopAlone(a) ==
 LET v==s.views[a[1]+1] p==s.blocks[s.head+1] o==s.origins[s.generation+1]
     t==LiteralTime(p.time,a[2],v.timestamp)
     rule==IF t>=v.schedule.time THEN v.schedule.next ELSE v.schedule.active
 IN /\ s.ready /\ s.produces<MaxProduces /\ s.head<MaxHeight /\ a[1]<=s.finalized
    /\ a[1]>=o.index /\ v.generation=s.generation
    /\ IF s.head=o.height THEN a[2]=o.timestamp ELSE a[1]+31>=p.anchor.number /\ a[2]>=p.bft
    /\ t-v.timestamp<=2 /\ s.head+1<=v.checkpoint+2 /\ rule \in a[3] /\ a[3]=s.software
    /\ v.schedule.stop#0 /\ p.time>=v.schedule.stop
OnlyCheckpointStale(a) ==
 IF a[1]= <<>> THEN FALSE ELSE
 /\ a[2] /\ s.initialized /\ s.startWritten /\ a[1][1]=s.generation
 /\ a[1][2]#s.c /\ a[1][3]=s.nonce /\ T(s.index)<=a[1][4]
 /\ s.generation<999 /\ s.nonce<9
 /\ (a[1][5]=0 \/ (a[1][5]=s.schedule.next+1 /\ a[1][5]<=999))
UpdateSeen(k,a,ok,r) ==
 [seen EXCEPT
  !.terminal=IF ok /\ k=14 /\ s.jobs[a[1]].data[Len(s.jobs[a[1]].data)].time>=s.jobs[a[1]].data[Len(s.jobs[a[1]].data)].anchor.schedule.stop
                  /\ s.jobs[a[1]].data[Len(s.jobs[a[1]].data)].anchor.schedule.stop#0 THEN r.c ELSE @,
  !.stopRefused=@ \/ (~ok /\ k=10 /\ seen.terminal=s.c /\ seen.terminal>0 /\ StopAlone(a)),
  !.recovered=@ \/ (ok /\ k=5 /\ a[1][5]>0 /\ seen.terminal=s.c /\ seen.terminal>0 /\ seen.stopRefused),
  !.fresh=IF ok /\ k=14 /\ s.generation=1 THEN r.c ELSE @,
  !.stale=@ \/ (~ok /\ k=5 /\ OnlyCheckpointStale(a)),
  !.noStop=@ \/ (ok /\ k=5 /\ s.schedule.stop=0),
  !.distinctClocks=@ \/ (ok /\ k=10 /\ s.generation=1 /\ r.blocks[r.head+1].first /\ r.blocks[r.head+1].time#r.blocks[r.head+1].bft)]
Call(k,a) ==
 LET ok==Can(k,a) r==IF ok THEN After(k,a) ELSE s e==Event(k,a,ok)
 IN /\ s'=r /\ last'= <<k,a,ok,e>> /\ seen'=UpdateSeen(k,a,ok,r)
    /\ bad'=(bad \/ ok#ExpectedCan(k,a) \/ r#(IF ExpectedCan(k,a) THEN ExpectedAfter(k,a) ELSE s) \/ e#ExpectedEvent(k,a,ok))

Structural == Scenario \in {"Structural","StructuralSafety","Stale","NoStop","Reset"}
RulesOffers == IF Structural \/ Scenario="Smoke" THEN {} ELSE {<<r,t,own>>:r \in 0..2,t \in {0,102,103,104,106,FieldLimit},own \in BOOLEAN}
StopOffers == IF Scenario \in {"NoStop","Smoke"} THEN {} ELSE IF Structural THEN {<<103,TRUE>>} ELSE {<<t,own>>:t \in {0,102,103,104,106},own \in BOOLEAN}
CaptureOffers == IF Structural THEN
                  {<<1,0,2,1>>} \cup (IF s.origins[2]= <<>> THEN {} ELSE {<<2,2,3,s.origins[2].index>>})
                ELSE {<<j,p,h,ref>>:j \in Slots,p \in Heights,h \in Heights,ref \in 0..s.index}
BaseOffers(k) == CASE
 k=1 -> RulesOffers
 [] k=2 -> StopOffers
 [] k=3 -> IF Scenario="Smoke" \/ s.generation#0 THEN {} ELSE IF Structural THEN {<<1,108>>} ELSE {<<r,t>>:r \in {0,1,2},t \in {101,104,106,108}}
 [] k=4 -> IF Structural \/ Scenario="Smoke" THEN {} ELSE {<<n,own>>:n \in 0..2,own \in BOOLEAN}
 [] k=5 -> IF s.generation=0 /\ Scenario#"Smoke" THEN IF Structural THEN {<<s.auth,TRUE>>} ELSE {<<s.auth,TRUE>>,<<s.auth,FALSE>>} ELSE {}
 [] k=6 -> {<<>>}
 [] k=7 -> IF Structural THEN {<<s.index-1>>} ELSE {<<i>>:i \in 0..s.index}
 [] k=8 -> {<<>>}
 [] k=9 -> IF Structural THEN {<<{0,1,2}>>} ELSE {<<{0}>>,<<{0,1,2}>>}
 [] k=10 -> {<<i,t,s.software>>:i \in 0..s.index,t \in (IF Structural THEN {CurrentOrigin.timestamp,101,103,104,105} ELSE 100..106)}
 [] k=11 -> CaptureOffers
 [] k=12 -> {<<j,b,image>>:j \in Slots,b \in 1..2,image \in (IF Structural THEN {{0,1,2}} ELSE {{0},{0,1,2}})}
 [] k=13 -> {<<j>>:j \in Slots}
 [] k=14 -> {<<j>>:j \in Slots}
Offers(k) == IF (Scenario="Dispatch" /\ k \notin {1,2,6}) \/ (Scenario="Reset" /\ k \notin {2,3,5}) THEN {} ELSE BaseOffers(k)
Next == \E k \in 1..14: \E a \in Offers(k):Call(k,a)
Spec == Init /\ [][Next]_vars
\* Existential companions only. No action, observer or target reads old last;
\* the full effective receipt is still printed and checked on each raw edge.
WitnessView == <<s,bad,seen>>
\* Independently fixed selected boundary inputs, never execution masks.
RequiredRules == IF Scenario \in {"Structural","StructuralSafety","Stale","NoStop","Reset","Smoke"} THEN {}
                 ELSE {<<0,FieldLimit,TRUE>>,<<1,103,TRUE>>,<<2,104,TRUE>>,<<1,FieldLimit,TRUE>>,<<1,103,FALSE>>}
RequiredStops == IF Scenario \in {"NoStop","Smoke"} THEN {}
                 ELSE IF Scenario \in {"Structural","StructuralSafety","Stale","Reset"} THEN {<<103,TRUE>>}
                 ELSE {<<0,TRUE>>,<<103,TRUE>>,<<104,FALSE>>}
DispatchOne(k,a) ==
 LET ok==ExpectedCan(k,a) r==IF ok THEN ExpectedAfter(k,a) ELSE s e==ExpectedEvent(k,a,ok)
 IN ENABLED (Next /\ last'= <<k,a,ok,e>> /\ s'=r)
ScheduleDispatch == /\ \A a \in RequiredRules:DispatchOne(1,a)
                    /\ \A a \in RequiredStops:DispatchOne(2,a)
Frames == ~bad
Typed ==
 /\ ScheduleTyped(s.schedule) /\ s.generation \in 0..1 /\ s.c \in Heights /\ s.head \in Heights
 /\ s.index \in 1..MaxL1 /\ s.finalized \in 0..(s.index-1) /\ s.nonce \in 0..4
 /\ s.fi=s.c /\ s.activeSnapshot \in N(0)..N(MaxL1) /\ s.ready \in BOOLEAN
 /\ s.produces \in 0..MaxProduces /\ s.writes \in 0..MaxWrites
 /\ s.software \in {{0},{0,1,2}} /\ s.initialized=TRUE /\ s.startWritten=TRUE
 /\ DOMAIN s.views=1..(MaxL1+1) /\ DOMAIN s.blocks=1..(MaxHeight+1)
 /\ DOMAIN s.records=1..(MaxHeight+1) /\ DOMAIN s.origins=1..2 /\ DOMAIN s.jobs=1..2
 /\ DOMAIN s.proofs=1..2 /\ DOMAIN s.published=1..2
 /\ s.origins[s.generation+1].generation=s.generation
 /\ s.views[s.index+1].generation=s.generation /\ s.views[s.index+1].schedule=s.schedule
 /\ s.views[s.index+1].checkpoint=s.c
Prefix == /\ s.c<=s.head /\ s.fi=s.c /\ s.records[s.c+1]#<<>>
          /\ s.activeSnapshot<=N(s.index)
NoStructural == ~(seen.recovered /\ seen.fresh>seen.terminal /\ seen.distinctClocks
                   /\ V(s.finalized).checkpoint>=seen.fresh /\ s.head>seen.fresh
                   /\ s.blocks[s.head+1].anchor.checkpoint>=seen.fresh)
NoStale == ~seen.stale
NoGeneralRecovery == ~seen.noStop
NoTerminal == seen.terminal=0
NoFreshLand == ~(seen.recovered /\ seen.fresh>seen.terminal /\ seen.distinctClocks)
=============================================================================
