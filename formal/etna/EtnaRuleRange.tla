-------------------------- MODULE EtnaRuleRange --------------------------
EXTENDS Naturals, Sequences, FiniteSets
VARIABLES s, receipt

\* Version2: current timestamp-only schedule, ordinary generation0, M1296/U4.
\* Labels represent authenticated headers/storage and valid EL/committee/FI
\* execution. Each family's adjacent-image whole-range aggregation is a
\* separate availability premise. No native proof or three-fork ELF is claimed.
\* Initial committee premise: a valid nonempty authenticated registry checkpoint
\* at24, with positive activation delays already elapsed, selects committee0.
\* Inbox initialization/start is25. Registry/selection execution is not modelled.
Empty == <<>>
Zero == <<0,0,0,0>>
First == <<0,1,3600,0>>
Second == <<1,2,5184,0>>
Clock == <<191,192,288,298,299,300,324,432,433,434>>
Anchors == {190,192,288,300,432,433}
Max(a,b) == IF a > b THEN a ELSE b
Time(n) == 12*n
OriginL1 == 25
GenesisCutoff == 24
EpochLength == 16
FirstOrdinarySwitch == EpochLength-1
Cut(h) == <<h,100+h,IF h=0 THEN 0 ELSE 200+h,0>>
Rule(q,t) == IF t >= q[3] THEN q[2] ELSE q[1]
View(n,c,q) == [number |-> n,time |-> Time(n),hash |-> 500+n,root |-> 900+n,
                 checkpoint |-> Cut(c),schedule |-> q]
Block(h,p,b,t,n,pn,carry,r) ==
    [generation |-> 0,cut |-> Cut(h),stateRoot |-> 400+h,
     parentTime |-> p,bftTime |-> b,elTime |-> t,anchor |-> n,
     parentAnchor |-> pn,carry |-> carry,anchorRoot |-> 900+n,anchorHash |-> 500+n,
     rule |-> r,first |-> h=1,origin |-> OriginL1,originTime |-> Time(OriginL1),
     lastBlockID |-> IF h=1 THEN 0 ELSE 199+h]
Prefix == <<Block(1,0,300,2280,190,25,TRUE,0),
            Block(2,2280,2281,2281,190,190,FALSE,0),
            Block(3,2281,2301,2301,190,190,FALSE,0),
            Block(4,2301,2302,2302,190,190,FALSE,0)>>
Parents == <<Block(5,2302,3597,3597,192,190,TRUE,0),
             Block(6,3597,3597,3598,192,192,FALSE,0)>>
Blocks == <<Block(7,3598,3599,3599,288,192,TRUE,0),
            Block(8,3599,3600,3600,288,288,FALSE,1),
            Block(9,3600,3600,3601,300,288,TRUE,1),
            Block(10,3601,5184,5184,432,300,TRUE,2)>>
Adjacent == <<<<0,1>>,<<1,2>>>>
Endpoints == <<<<0>>,<<2>>>>
Landing(h,n,ref) == [generation |-> 0,cut |-> Cut(h),number |-> n,
    reference |-> ref,referenceHash |-> 500+ref,stateRoot |-> 400+h,activeSnapshot |-> GenesisCutoff]
Initial == [generation |-> 0,c |-> 4,head |-> 4,fiHead |-> 0,activeSnapshot |-> GenesisCutoff,
    l1 |-> 191,finalized |-> 190,initialized |-> TRUE,owner |-> TRUE,
    schedule |-> Zero,history |-> <<<<OriginL1,Zero>>>>,software |-> <<0>>,
    canonical |-> Prefix,records |-> <<Landing(4,191,190)>>,
    views |-> <<View(190,0,Zero)>>,pending |-> Empty,job |-> Empty,
    proofs |-> Empty,published |-> Empty,aggregateAvailable |-> <<TRUE,TRUE>>,
    zkFamilies |-> <<2>>]
Init == s=Initial /\ receipt=Empty

SeqSet(seq) == {seq[i]:i \in 1..Len(seq)}
Last(seq) == seq[Len(seq)]
ViewAt(x,n) == x.views[CHOOSE i \in 1..Len(x.views):x.views[i].number=n]
HistorySchedule(x,n) ==
    LET candidates == {i \in 1..Len(x.history):x.history[i][1] <= n}
        latest == CHOOSE i \in candidates:\A j \in candidates:i >= j
    IN x.history[latest][2]
HistoryCheckpoint(x,n) ==
    LET candidates == {i \in 1..Len(x.records):x.records[i].number <= n}
    IN IF candidates={} THEN 0 ELSE
        x.records[CHOOSE i \in candidates:\A j \in candidates:i >= j].cut[1]
ViewsThrough(x,n) ==
    LET ns == SelectSeq(<<190,192,288,300,432,433>>,LAMBDA a:a <= n)
    IN [i \in 1..Len(ns) |-> View(ns[i],HistoryCheckpoint(x,ns[i]),HistorySchedule(x,ns[i]))]

ValidBlock(x,b) ==
    /\ b.anchor \in {x.views[i].number:i \in 1..Len(x.views)}
    /\ LET v == ViewAt(x,b.anchor)
       IN /\ b.anchor >= b.parentAnchor /\ b.anchor >= b.origin
          /\ b.carry = (b.first \/ b.anchor # b.parentAnchor)
          /\ b.anchorRoot=v.root /\ b.anchorHash=v.hash
          /\ b.elTime=Max(Max(b.parentTime+1,b.bftTime),v.time)
          /\ b.elTime-v.time <= 1296
          /\ b.cut[1]-v.checkpoint[1] <= 4 /\ v.checkpoint[1] < b.cut[1]
          /\ b.rule=Rule(v.schedule,b.elTime)
          /\ v.schedule[4]=0 \/ b.parentTime < v.schedule[4]
CanBuild(x,b) ==
    /\ x.pending=Empty /\ b.cut[1]=x.head+1
    /\ b.parentTime=Last(x.canonical).elTime
    /\ b.parentAnchor=Last(x.canonical).anchor
    /\ b.lastBlockID=Last(x.canonical).cut[3] /\ b.generation=x.generation
    /\ b.anchor=Max(x.finalized,Last(x.canonical).anchor)
    /\ ValidBlock(x,b)

CanSchedule(x,a) ==
    /\ x.owner /\ x.initialized /\ x.finalized < x.l1
    /\ x.l1=IF a[1]=1 THEN 192 ELSE 324
    /\ Time(x.l1) >= x.schedule[3] \/ Time(x.l1)+1296 < x.schedule[3]
    /\ a[1] \in {x.schedule[2],x.schedule[2]+1}
    /\ a[2] >= Time(x.l1)+1296
    /\ <<IF Time(x.l1)>=x.schedule[3] THEN x.schedule[2] ELSE x.schedule[1],
          a[1],a[2],x.schedule[4]>> # x.schedule
Scheduled(x,a) == <<IF Time(x.l1)>=x.schedule[3] THEN x.schedule[2] ELSE x.schedule[1],
                    a[1],a[2],x.schedule[4]>>
WasRefused == receipt # Empty /\ receipt.kind=7 /\ ~receipt.accepted

RangeBlocks(x) == SubSeq(x.canonical,7,10)
RuleVector(x,bs) == [i \in 1..Len(bs) |-> Rule(ViewAt(x,bs[i].anchor).schedule,bs[i].elTime)]
RangeCuts(x) == [i \in 6..10 |-> x.canonical[i].cut]
CutSequence(x) == [i \in 1..5 |-> RangeCuts(x)[i+5]]
RangeData(x) == [i \in 1..4 |-> x.canonical[i+6].cut[2]]
Statement(x,ref) ==
    <<1,1,167000,4369,8738,0,6,x.canonical[6].cut[2],x.canonical[6].cut[3],333,
      10,x.canonical[10].cut[2],x.canonical[10].cut[3],x.canonical[10].stateRoot,
      ref,500+ref,RangeData(x),0,0,x.activeSnapshot,
      <<2,0,6,10,SubSeq(CutSequence(x),2,4)>>>>
Captured(x,ref) == [generation |-> 0,reference |-> ref,referenceHash |-> 500+ref,
    dependency |-> x.activeSnapshot,cuts |-> CutSequence(x),data |-> RangeData(x),
    statement |-> Statement(x,ref),rules |-> RuleVector(x,RangeBlocks(x)),blocks |-> RangeBlocks(x)]

\* Each family supplies its own whole-range result. Availability of an
\* adjacent-image aggregate is separate from the images' declared capabilities.
ImageSupports(images,r) == \E i \in 1..Len(images):r \in SeqSet(images[i])
FamilyCovers(x,f,images) ==
    /\ x.aggregateAvailable[f]
    /\ \A i \in 1..Len(x.job.rules):ImageSupports(images,x.job.rules[i])
CanProve(x,a) == x.job # Empty /\ a[1] \notin {x.proofs[i][1]:i \in 1..Len(x.proofs)}
                 /\ FamilyCovers(x,a[1],a[2])
CanLand(x) ==
    /\ x.job # Empty /\ x.c < 10 /\ x.published=x.job.data
    /\ {x.proofs[i][1]:i \in 1..Len(x.proofs)}={1,2}
    /\ \E i \in 1..Len(x.proofs):x.proofs[i][1] \in SeqSet(x.zkFamilies)
    /\ \A i \in 1..Len(x.proofs):x.proofs[i][3]=x.job.statement
    /\ x.job.reference < x.l1 /\ x.l1-x.job.reference <= 256

Call(k,a) == [kind |-> k,args |-> a]
\* Free bounded calls, not a scripted stage counter. Operators may advance,
\* finalize, prepare, refuse/retry, prove either family or publish in any offered
\* order. Missing required writes/clock/view support leads to safe dead ends.
Offers(x) ==
    (IF x.l1 < 434 THEN {Call(1,<<Clock[(CHOOSE i \in 1..Len(Clock):Clock[i]=x.l1)+1]>>)} ELSE {})
    \cup {Call(2,<<n>>):n \in {a \in Anchors:x.finalized < a /\ a < x.l1}}
    \cup (IF x.l1=192 THEN {Call(3,<<1,3600>>)} ELSE
            IF x.l1=324 THEN {Call(3,<<2,5184>>)} ELSE {})
    \cup (IF x.l1=298 /\ x.head \in {4,5} THEN {Call(4,<<Parents[x.head-3]>>)} ELSE {})
    \cup (IF x.l1=299 /\ x.head=6 /\ x.c=4 THEN {Call(5,<<6,298>>)} ELSE {})
    \cup (IF x.head \in 6..9 /\ x.pending=Empty THEN {Call(6,<<Blocks[x.head-5]>>)} ELSE {})
    \cup (IF x.pending # Empty THEN {Call(7,Empty)} ELSE {})
    \cup (IF x.software= <<0>> /\ x.pending # Empty THEN {Call(8,<<1>>)} ELSE {})
    \cup (IF x.software= <<0,1>> /\ x.head>=9 THEN {Call(8,<<2>>)} ELSE {})
    \cup (IF x.head=10 /\ x.job=Empty THEN {Call(9,<<6,10,433>>)} ELSE {})
    \cup (IF x.job # Empty THEN {Call(10,<<f,p>>):f \in {1,2},p \in {Adjacent,Endpoints}} ELSE {})
    \cup (IF x.job # Empty /\ x.published=Empty
            THEN {Call(11,<<d>>):d \in {<<107,108,109,110>>,<<109,110>>}} ELSE {})
    \cup (IF x.job # Empty /\ x.c<10 THEN {Call(12,<<x.job>>)} ELSE {})

Allowed(x,k,a) == CASE
       k=1 -> TRUE
    [] k=2 -> TRUE
    [] k=3 -> CanSchedule(x,a)
    [] k=4 -> x.l1=298 /\ CanBuild(x,a[1])
    [] k=5 -> x.l1=299 /\ x.head=6 /\ x.c=4
    [] k=6 -> x.c=6 /\ CanBuild(x,a[1])
    [] k=7 -> x.pending # Empty /\ x.pending.rule \in SeqSet(x.software)
    [] k=8 -> (a[1]=1 /\ x.software= <<0>> /\ x.pending # Empty /\ x.pending.cut[1]=8 /\ WasRefused)
                \/ (a[1]=2 /\ x.software= <<0,1>> /\ x.head>=9)
    [] k=9 -> x.head=10 /\ x.c=6 /\ x.job=Empty /\ x.finalized>=433
    [] k=10 -> CanProve(x,a)
    [] k=11 -> x.job # Empty /\ x.published=Empty /\ a[1]=x.job.data
    [] OTHER -> CanLand(x)
After(x,k,a) == CASE
       k=1 -> [x EXCEPT !.l1=a[1]]
    [] k=2 -> [x EXCEPT !.finalized=a[1],!.views=ViewsThrough(x,a[1])]
    [] k=3 -> [x EXCEPT !.schedule=Scheduled(x,a),!.history=Append(@,<<x.l1,Scheduled(x,a)>>)]
    [] k=4 -> [x EXCEPT !.head=a[1].cut[1],!.canonical=Append(@,a[1])]
    [] k=5 -> [x EXCEPT !.c=6,!.records=Append(@,Landing(6,299,298))]
    [] k=6 -> [x EXCEPT !.pending=a[1]]
    [] k=7 -> [x EXCEPT !.head=x.pending.cut[1],!.canonical=Append(@,x.pending),!.pending=Empty]
    [] k=8 -> [x EXCEPT !.software=Append(@,a[1])]
    [] k=9 -> [x EXCEPT !.job=Captured(x,a[3])]
    [] k=10 -> [x EXCEPT !.proofs=Append(@,<<a[1],a[2],x.job.statement>>)]
    [] k=11 -> [x EXCEPT !.published=a[1]]
    [] OTHER -> [x EXCEPT !.c=10,!.records=Append(@,Landing(10,x.l1,433))]
Step(call) ==
    LET k==call.kind a==call.args ok==Allowed(s,k,a)
    IN /\ s'=IF ok THEN After(s,k,a) ELSE s
       /\ receipt'=[kind |-> k,args |-> a,accepted |-> ok]
Next == \E call \in Offers(s):Step(call)

Bounds == /\ s.generation=0 /\ s.c \in {4,6,10} /\ s.head \in 4..10
          /\ s.c<=s.head /\ s.head-s.c<=4 /\ Len(s.canonical)=s.head
          /\ s.finalized<s.l1 /\ s.l1 \in SeqSet(Clock)
          /\ s.software \in {<<0>>,<<0,1>>,<<0,1,2>>}
ProtocolInitialCompatibility ==
    /\ 0 < GenesisCutoff /\ GenesisCutoff < OriginL1
    /\ EpochLength >= 3 /\ 10 < FirstOrdinarySwitch
    /\ s.generation=0 /\ s.activeSnapshot=GenesisCutoff
    /\ s.history[1]= <<OriginL1,Zero>>
    /\ s.canonical[1].first /\ s.canonical[1].bftTime=Time(OriginL1)
    /\ s.canonical[1].parentAnchor=OriginL1
    /\ \A i \in 1..Len(s.canonical):
          s.canonical[i].origin=OriginL1 /\ s.canonical[i].originTime=Time(OriginL1)
    /\ \A i \in 1..Len(s.records):s.records[i].activeSnapshot=GenesisCutoff
    /\ \A i \in 1..Len(s.views):
          s.views[i].checkpoint[1]=0 => s.views[i].checkpoint[3]=0
    /\ (s.job # Empty => s.job.dependency=GenesisCutoff /\ s.job.statement[20]=GenesisCutoff)
HistoricalRulesBound ==
    /\ \A i \in 1..Len(s.views):s.views[i].schedule=HistorySchedule(s,s.views[i].number)
    /\ \A i \in 1..Len(s.canonical):
          s.canonical[i].rule=Rule(HistorySchedule(s,s.canonical[i].anchor),s.canonical[i].elTime)
    /\ s.job # Empty =>
          \A i \in 1..Len(s.job.blocks):
            s.job.rules[i]=Rule(HistorySchedule(s,s.job.blocks[i].anchor),s.job.blocks[i].elTime)
BackendRulesBound == s.job # Empty /\ Len(s.proofs)=2 =>
    \A i \in 1..Len(s.proofs):
       /\ s.aggregateAvailable[s.proofs[i][1]]
       /\ \A j \in 1..Len(s.job.blocks):ImageSupports(s.proofs[i][2],
             Rule(HistorySchedule(s,s.job.blocks[j].anchor),s.job.blocks[j].elTime))
RangeBound == s.job # Empty =>
    /\ Len(s.job.blocks)=4 /\ Len(s.job.cuts)=5 /\ Len(s.job.data)=4
    /\ Len(s.job.statement)=21 /\ Len(s.job.statement[21][5])=3
    /\ \A i \in 1..4:s.job.blocks[i].anchor<=s.job.reference
    /\ s.job.referenceHash=500+s.job.reference
    /\ s.job=Captured(s,s.job.reference)
Settled == s.c=10 =>
    /\ s.head=10 /\ s.job # Empty /\ s.published=s.job.data
    /\ Len(s.proofs)=2 /\ Last(s.records).number>s.job.reference
On(k,ok) == receipt # Empty /\ receipt.kind=k /\ receipt.accepted=ok
NoSmoke == ~(s.head=7 /\ On(7,TRUE))
NoPause == ~(s.pending # Empty /\ s.pending.cut[1]=8 /\ s.software= <<0>> /\ On(7,FALSE))
NoProgress == ~(s.c=10 /\ s.head=10 /\ s.job.rules= <<0,1,1,2>> /\ On(12,TRUE))
=============================================================================
