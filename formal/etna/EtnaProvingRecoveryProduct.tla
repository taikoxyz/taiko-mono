--------------------- MODULE EtnaProvingRecoveryProduct ---------------------
EXTENDS Naturals, Integers, Sequences, FiniteSets, TLC
CONSTANTS Depth, MaxTime, MaxProduces, Capacity, Scenario
VARIABLES s, bad, milestone
vars == <<s,bad,milestone>>
S == 6
H == S..(S+Depth)
Times == 0..MaxTime
Slots == 1..2
Backends == 1..2
U == IF Scenario="Fixed" THEN 4 ELSE 2
Window == 4
Budget == 4
At(h) == h-S+1
\* Direct finite representatives of 32-byte words. The genesis Comet hash is zero.
Cut(g,h) == <<h,100*g+h,IF h=S THEN 0 ELSE 200+100*g+h,h-S>>
Blob(cut) == cut[2]
Rec(g,parent,cut,t) == <<g,parent,cut,t>>
Anchor(g,h,t,cut) == <<g,h,t,cut>>
FirstCut == Cut(0,S)
FirstAnchor == Anchor(0,S,0,FirstCut)
FirstRecord == Rec(0,S,FirstCut,0)
Pair(x) == <<x,x>>
List(i,j,f(_)) == [k \in 1..(j-i+1) |-> f(i+k-1)]
Canon(h) == s.canonical[At(h)]
Record(h) == s.records[At(h)]
Context(cut,t,dep) == <<1,167000,4369,8738,333,400+cut[2],500+t,dep>>
\* A structural abstraction of ENC-A-35. The concrete replay hashes exactly
\* these words with legacy Keccak, including the nested blobs/range bindings.
Bound(g,t,dep,cuts,data) == LET a==Head(cuts) b==cuts[Len(cuts)] q==Context(b,t,dep)
   IN <<1,q[1],q[2],q[3],q[4],g,a[1],a[2],a[3],q[5],b[1],b[2],b[3],q[6],
        t,q[7],data,a[4],b[4],q[8],<<2,g,a[1],b[1],SubSeq(cuts,2,Len(cuts)-1)>>>>
Job(g,t,dep,cuts,data) ==
 [generation |-> g,reference |-> t,dependency |-> dep,cuts |-> cuts,data |-> data,
  statement |-> Bound(g,t,dep,cuts,data)]
Captured(p,h,t) == LET cuts == List(p,h,Canon)
                        data == [i \in 1..(h-p) |-> Blob(Canon(p+i))]
                    IN Job(s.generation,t,s.dependency,cuts,data)
Parent(x) == x.cuts[1][1]
Terminal(x) == x.cuts[Len(x.cuts)][1]
CommonInit ==
  [head |-> S, generation |-> 0, now |-> 0, included |-> S, fiHead |-> 0,activeSnapshot |-> 0,
   finalized |-> S, finalizedBlock |-> 0, start |-> S, dependency |-> 0,
   parentAnchor |-> FirstAnchor, anchors |-> {FirstAnchor}, producedCount |-> 0,
   canonical |-> [i \in 1..(Depth+1) |-> IF i=1 THEN FirstCut ELSE <<>>],
   records |-> [i \in 1..(Depth+1) |-> IF i=1 THEN FirstRecord ELSE <<>>],
   applied |-> [i \in 1..(Depth+1) |-> 0],
   jobs |-> Pair(<<>>), proofs |-> Pair(Pair(<<>>)), published |-> Pair(<<>>),
   available |-> Pair(FALSE), privateHistory |-> FALSE]
Init == /\ s=CommonInit /\ bad=FALSE /\ milestone=0

Produce(a) ==
 /\ s.producedCount<MaxProduces /\ s.head<S+Depth /\ a \in s.anchors
 /\ a[3]>=s.dependency /\ (s.head=s.start \/ a[3]>=s.parentAnchor[3])
 /\ a[1]=s.generation /\ a[3]<=s.now /\ s.now-a[3]<=Window /\ s.head+1-a[2]<=U
 /\ s'=[s EXCEPT !.head=@+1, !.producedCount=@+1, !.parentAnchor=a,
                  !.canonical[At(s.head+1)]=Cut(s.generation,s.head+1)]
SlotOffer(j) == Scenario \in {"Overlap","TwoOld"} \/ j=s.generation+1
Capture(j,p,h,t) ==
 /\ SlotOffer(j) /\ s.jobs[j]= <<>> /\ t=s.now
 /\ p \in s.start..s.included /\ h \in (s.included+1)..s.head
 /\ Record(p)#<<>> /\ (Record(p)[1]=s.generation \/ p=s.start)
 /\ s'=[s EXCEPT !.jobs[j]=Captured(p,h,t)]
History(v) == s'=[s EXCEPT !.privateHistory=v]
Availability(b,v) == s'=[s EXCEPT !.available[b]=v]
Complete(j,b,k) ==
 /\ s.jobs[j]#<<>> /\ s.jobs[k]#<<>> /\ s.privateHistory /\ s.available[b]
 /\ s.jobs[k].reference-s.jobs[k].dependency<=Budget
 /\ s'=[s EXCEPT !.proofs[j][b]=s.jobs[k].statement]
Suffix(x) == SubSeq(x.data,s.included-Parent(x)+1,Len(x.data))
Publish(j,full) ==
 /\ s.jobs[j]#<<>>
 /\ s'=[s EXCEPT !.published[j]=IF full THEN s.jobs[j].data ELSE Suffix(s.jobs[j])]
ReadyAt(r,x,proofs,published) ==
 /\ x#<<>>
 /\ LET p==Parent(x) h==Terminal(x) c==r.included
        origin==r.records[At(p)] cur==r.records[At(c)] last==x.cuts[Len(x.cuts)]
    IN /\ x.generation=r.generation
       /\ r.start<=p /\ p<=c /\ c<h
       /\ origin#<<>> /\ (origin[1]=r.generation \/ p=r.start)
       /\ origin[3]=x.cuts[1] /\ cur[3][4]=r.fiHead
       /\ IF p=c THEN cur[3]=x.cuts[1] ELSE x.statement[21][5][c-p]=cur[3]
       /\ 0<=last[4]-r.fiHead /\ last[4]-r.fiHead<=h-c
       /\ x.reference<r.now /\ r.now-x.reference<=Window
       /\ x.reference-x.dependency<=Budget
       /\ proofs=Pair(x.statement) /\ published=x.data /\ h-p<=Capacity
Ready(j) == ReadyAt(s,s.jobs[j],s.proofs[j],s.published[j])
Landed(r,x) ==
 LET h==Terminal(x) cut==x.cuts[Len(x.cuts)]
 IN [r EXCEPT !.included=h, !.fiHead=cut[4],!.activeSnapshot=x.statement[20],
        !.records[At(h)]=Rec(r.generation,r.included,cut,r.now),
        !.applied=[i \in DOMAIN r.applied |-> r.applied[i]+
               (IF r.included<S+i-1 /\ S+i-1<=h THEN 1 ELSE 0)]]
Land(j) == /\ Ready(j) /\ s'=Landed(s,s.jobs[j])
Tick == /\ s.now<MaxTime /\ s'=[s EXCEPT !.now=@+1]
Finalize(b) ==
 /\ b \in (s.finalizedBlock+1)..(s.now-1)
 /\ LET eligible=={h \in H:Record(h)#<<>> /\ Record(h)[4]<=b}
        h==CHOOSE n \in eligible : \A m \in eligible:n>=m
    IN s'=[s EXCEPT !.finalized=h, !.finalizedBlock=b]
PublishAnchor ==
  s'=[s EXCEPT !.anchors=@ \cup {Anchor(s.generation,s.finalized,s.finalizedBlock,Record(s.finalized)[3])}]
\* A completed, trusted recovery/bootstrap macro: execution R and observation R+1.
Recover ==
 /\ s.generation=0 /\ s.now+2<=MaxTime
 /\ LET a==Anchor(1,s.included,s.now+1,Record(s.included)[3])
    IN s'=[s EXCEPT !.generation=1, !.head=s.included, !.start=s.included,
       !.now=@+2, !.dependency=s.now+1, !.finalized=s.included,
       !.finalizedBlock=s.now+1, !.parentAnchor=a, !.anchors=@ \cup {a}]

\* Independent admission and complete frame. Dispatch below offers actual actions
\* without consulting these equations. Missing enabled actions produce a fault
\* state; unexpected acceptance and any incorrect frame are checked on successors.
LiteralCapture(p,h,t) ==
 LET cuts == [n \in 1..(1+h-p) |-> s.canonical[p-S+n]]
     blobs == [n \in 1..(h-p) |-> s.canonical[p-S+n+1][2]]
     lo == s.canonical[p-S+1] hi == s.canonical[h-S+1]
     inside == [n \in 1..(h-p-1) |-> s.canonical[p-S+n+1]]
 IN [generation |-> s.generation,reference |-> t,dependency |-> s.dependency,
     cuts |-> cuts,data |-> blobs,
     statement |-> <<1,1,167000,4369,8738,s.generation,p,lo[2],lo[3],333,h,
       hi[2],hi[3],400+hi[2],t,500+t,blobs,lo[4],hi[4],s.dependency,<<2,s.generation,p,h,inside>>>>]
LiteralLand(j) ==
 IF s.jobs[j]= <<>> THEN FALSE ELSE
 LET x==s.jobs[j] p==x.cuts[1][1] n==Len(x.data) h==p+n c==s.included
     origin==s.records[p-S+1] current==s.records[c-S+1] endCut==x.cuts[n+1]
 IN /\ s.generation=x.generation /\ p>=s.start /\ c>=p /\ h>c
    /\ origin#<<>> /\ current#<<>>
    /\ (p=s.start \/ origin[1]=s.generation) /\ origin[3]=x.cuts[1]
    /\ current[3]=x.cuts[c-p+1] /\ current[3][4]=s.fiHead
    /\ s.fiHead<=endCut[4] /\ endCut[4]<=s.fiHead+h-c
    /\ s.now>x.reference /\ x.reference+4>=s.now /\ x.reference<=x.dependency+4
    /\ n<=Capacity /\ s.published[j]=x.data
    /\ \A b \in 1..2:s.proofs[j][b]=x.statement
Admit(k,a) ==
 CASE k="Produce" -> /\ s.producedCount+1<=MaxProduces /\ s.head+1<=S+Depth
                     /\ a \in s.anchors /\ a[1]=s.generation
                     /\ s.dependency<=a[3] /\ (s.start=s.head \/ s.parentAnchor[3]<=a[3])
                     /\ a[3]<=s.now /\ a[3]+4>=s.now /\ s.head+1<=a[2]+2
 [] k="Capture" -> LET j==a[1] p==a[2] h==a[3] IN
                  /\ (Scenario \in {"Overlap","TwoOld"} \/ j-1=s.generation) /\ s.jobs[j]= <<>>
                  /\ a[4]=s.now /\ s.start<=p /\ p<=s.included
                  /\ s.included<h /\ h<=s.head /\ s.records[p-S+1]#<<>>
                  /\ (p=s.start \/ s.records[p-S+1][1]=s.generation)
 [] k="History" -> TRUE
 [] k="Availability" -> TRUE
 [] k="Complete" -> /\ s.jobs[a[1]]#<<>> /\ s.jobs[a[3]]#<<>>
                    /\ s.privateHistory /\ s.available[a[2]]
                    /\ s.jobs[a[3]].reference<=s.jobs[a[3]].dependency+4
 [] k="Publish" -> s.jobs[a[1]]#<<>>
 [] k="Land" -> LiteralLand(a)
 [] k="Tick" -> s.now+1<=MaxTime
 [] k="Finalize" -> s.finalizedBlock<a /\ a<s.now
 [] k="Anchor" -> TRUE
 [] k="Recover" -> s.generation=0 /\ MaxTime-s.now>=2

Expected(k,a) ==
 CASE k="Produce" -> LET h==s.head+1 g==s.generation
                     IN [s EXCEPT !.head=h, !.producedCount=s.producedCount+1,
                        !.parentAnchor=a, !.canonical[h-S+1]= <<h,100*g+h,200+100*g+h,h-S>>]
 [] k="Capture" -> [s EXCEPT !.jobs[a[1]]=LiteralCapture(a[2],a[3],a[4])]
 [] k="History" -> [s EXCEPT !.privateHistory=a]
 [] k="Availability" -> [s EXCEPT !.available[a[1]]=a[2]]
 [] k="Complete" -> [s EXCEPT !.proofs[a[1]][a[2]]=s.jobs[a[3]].statement]
 [] k="Publish" -> LET x==s.jobs[a[1]] p==x.cuts[1][1] h==p+Len(x.data)
                   IN [s EXCEPT !.published[a[1]]=IF a[2] THEN x.data
                      ELSE [n \in 1..(h-s.included) |-> x.data[n+s.included-p]]]
 [] k="Land" -> LET x==s.jobs[a] z==x.cuts[Len(x.data)+1] h==z[1]
                IN [s EXCEPT !.included=h, !.fiHead=z[4],!.activeSnapshot=x.dependency,
                      !.records[1+h-S]= <<s.generation,s.included,z,s.now>>,
                      !.applied=[i \in 1..(Depth+1) |-> IF i>1+s.included-S /\ i<=1+h-S
                                   THEN s.applied[i]+1 ELSE s.applied[i]]]
 [] k="Tick" -> [s EXCEPT !.now=s.now+1]
 [] k="Finalize" -> LET heights == {n \in H : s.records[1+n-S]#<<>> /\ s.records[1+n-S][4]<=a}
                        top == CHOOSE n \in heights : ~\E m \in heights:m>n
                    IN [s EXCEPT !.finalized=top,!.finalizedBlock=a]
 [] k="Anchor" -> [s EXCEPT !.anchors=s.anchors \cup
                    {<<s.generation,s.finalized,s.finalizedBlock,s.records[1+s.finalized-S][3]>>}]
 [] k="Recover" -> LET a0== <<1,s.included,s.now+1,s.records[1+s.included-S][3]>>
                   IN [s EXCEPT !.now=s.now+2,!.generation=1,!.dependency=s.now+1,
                       !.head=s.included,!.start=s.included,!.finalized=s.included,
                       !.finalizedBlock=s.now+1,!.parentAnchor=a0,!.anchors=s.anchors \cup {a0}]

Actual(k,a) ==
 CASE k="Produce" -> Produce(a)
 [] k="Capture" -> Capture(a[1],a[2],a[3],a[4])
 [] k="History" -> History(a)
 [] k="Availability" -> Availability(a[1],a[2])
 [] k="Complete" -> Complete(a[1],a[2],a[3])
 [] k="Publish" -> Publish(a[1],a[2])
 [] k="Land" -> Land(a)
 [] k="Tick" -> Tick
 [] k="Finalize" -> Finalize(a)
 [] k="Anchor" -> PublishAnchor
 [] k="Recover" -> Recover

\* Only the witness facts which would otherwise disappear in a later state.
Milestone(k,a) ==
 IF k="Recover" /\ s.head>=S+2 /\ s.jobs[1]#<<>>
 THEN IF s.included=S /\ s.jobs[1].cuts[Len(s.jobs[1].cuts)][1]=S+2
         /\ s.published[1]=s.jobs[1].data /\ s.proofs[1]= <<s.jobs[1].statement,s.jobs[1].statement>>
      THEN 1 ELSE IF s.included=S+1 THEN 2 ELSE milestone
 ELSE IF Scenario="Overlap" /\ k="Publish" THEN
     IF ~a[2] /\ s.jobs[a[1]]#<<>> /\ s.included=S+1
         /\ s.jobs[a[1]].cuts[1][1]=S /\ Len(s.jobs[a[1]].data)=2
         /\ s.proofs[a[1]]= <<s.jobs[a[1]].statement,s.jobs[a[1]].statement>>
     THEN 3 ELSE milestone
 ELSE milestone

Call(k,a) ==
 \/ /\ Actual(k,a)
    /\ bad'= IF Admit(k,a) THEN bad \/ s'#Expected(k,a) ELSE TRUE
    /\ milestone'=Milestone(k,a)
 \/ /\ Admit(k,a) /\ ~ENABLED Actual(k,a)
    /\ bad'=TRUE /\ UNCHANGED <<s,milestone>>

\* Fixed FREE offer alphabets for existential search only. Each accepted step
\* still uses the same Call/Actual as the complete graph. Arguments here are
\* enumerated constants, with no oracle or expected state driving a schedule.
IsC0 == Scenario="WitnessC0"
IsC1 == Scenario="WitnessC1"
IsOld == Scenario="WitnessOld"
IsPair == Scenario="Overlap"
Narrow == IsC0 \/ IsC1 \/ IsOld \/ IsPair
CaptureArgs ==
 IF IsC0 \/ IsOld THEN {<<1,6,8,0>>,<<2,6,8,2>>}
 ELSE IF IsC1 THEN {<<1,6,7,0>>,<<2,7,8,3>>}
 ELSE IF IsPair THEN {<<1,6,8,0>>,<<2,6,7,0>>}
 ELSE {<<j,p,h,s.now>> : j \in Slots,p \in H,h \in H}
FinalTimes == IF IsC0 THEN {3} ELSE IF Narrow THEN {} ELSE Times
EligibleAnchor(a) ==
 ~Narrow \/ a=FirstAnchor \/ a= <<1,6,1,<<6,6,0,0>>>> \/
      a= <<1,7,2,<<7,7,207,1>>>> \/ a= <<1,8,3,<<8,108,308,2>>>>
Next ==
 \/ \E a \in s.anchors:EligibleAnchor(a) /\ Call("Produce",a)
 \/ \E a \in CaptureArgs:Call("Capture",a)
 \/ \E v \in BOOLEAN:Call("History",v)
 \/ \E b \in Backends,v \in BOOLEAN:Call("Availability",<<b,v>>)
 \/ \E j \in Slots,b \in Backends,k \in Slots:(~Narrow \/ j=k) /\ Call("Complete",<<j,b,k>>)
 \/ \E j \in Slots,v \in BOOLEAN:(~Narrow \/ IsPair \/ v) /\ Call("Publish",<<j,v>>)
 \/ \E j \in Slots:Call("Land",j)
 \/ Call("Tick",0) \/ (\E b \in FinalTimes:Call("Finalize",b))
 \/ ((~Narrow \/ IsC0) /\ Call("Anchor",0))
 \/ (~IsPair /\ Call("Recover",0))

Spec == Init /\ [][Next]_vars
LiteralInit ==
 /\ s=[head |-> 6,generation |-> 0,now |-> 0,included |-> 6,fiHead |-> 0,activeSnapshot |-> 0,finalized |-> 6,
       finalizedBlock |-> 0,start |-> 6,dependency |-> 0,
       parentAnchor |-> <<0,6,0,<<6,6,0,0>>>>,anchors |-> {<<0,6,0,<<6,6,0,0>>>>},
       producedCount |-> 0,canonical |-> [i \in 1..(Depth+1) |-> IF i=1 THEN <<6,6,0,0>> ELSE <<>>],
       records |-> [i \in 1..(Depth+1) |-> IF i=1 THEN <<0,6,<<6,6,0,0>>,0>> ELSE <<>>],
       applied |-> [i \in 1..(Depth+1) |-> 0],jobs |-> <<<<>>,<<>>>>,
       proofs |-> <<<<<<>>,<<>>>>,<<<<>>,<<>>>>>>,published |-> <<<<>>,<<>>>>,
       available |-> <<FALSE,FALSE>>, privateHistory |-> FALSE]
 /\ ~bad /\ milestone=0
\* State predicates and a separate initial-state validation in each profile.
Frames == ~bad
Prefix == /\ s.fiHead=s.records[At(s.included)][3][4]
          /\ \A h \in H:s.applied[At(h)]=(IF S<h /\ h<=s.included THEN 1 ELSE 0)
InitExact == Init => LiteralInit
FreshLand == s.generation=1 /\ s.jobs[2]#<<>> /\ s.included>=S+2
             /\ Record(s.included)[1]=1 /\ s.jobs[2].generation=1
NoFreshC0 == ~(milestone=1 /\ FreshLand /\ s.start=S /\ s.finalized=S+2 /\
               s.parentAnchor[1]=1 /\ s.parentAnchor[2]=S+2 /\ s.head=S+3)
NoFreshC1 == ~(milestone=2 /\ FreshLand /\ s.start=S+1 /\ Record(S+1)[1]=0)
NoFreshLand == ~FreshLand
NoOverlap == ~(milestone=3 /\ s.included=S+2 /\ Record(S+2)[2]=S+1)
NoLateCapture == ~(s.jobs[1]#<<>> /\ s.jobs[1].reference>0 /\ s.jobs[1].generation=0)
NoSingle == ~(s.included=S+1 /\ Record(S+1)[2]=S)
NoOldAuthority == ~(milestone=1 /\ s.generation=1 /\ s.jobs[1]#<<>> /\ s.jobs[1].generation=0
                    /\ s.privateHistory /\ s.available= <<TRUE,TRUE>>
                    /\ s.included>s.start /\ Record(s.included)[3][2]<100)

\* The long candidate exists at t=0 with four-block headroom. Each shortest
\* competitor uses a reference at its retained parent inclusion. Every
\* successful shortest competitor uses the unchanged ordinary landing guard
\* and writer. The long transaction, its reference and resources stay fixed.
FixedCut(h) == <<h,h,200+h,h-S>>
FixedCuts == [i \in 1..5 |-> IF i=1 THEN FirstCut ELSE FixedCut(S+i-1)]
FixedTx(p,h,ref) == Job(0,ref,0,SubSeq(FixedCuts,At(p),At(h)),[i \in 1..(h-p) |-> p+i])
Long == FixedTx(S,S+4,0)
FixedInit ==
 /\ Depth=4 /\ U>=4 /\ MaxTime>=4
 /\ s=[CommonInit EXCEPT !.head=S+4,!.canonical=FixedCuts,!.now=1,
                          !.jobs[1]=Long,!.proofs[1]=Pair(Long.statement),!.published[1]=Long.data,
                          !.available=Pair(TRUE),!.privateHistory=TRUE]
 /\ bad=FALSE /\ milestone= <<0,<<>>,<<>>,<<>>>>
\* Independent literal attempt. Read the parent inclusion from the prior
\* record; an immutable long offer keeps its original range and reference.
FixedExpected(short) ==
 LET p==IF short THEN s.included ELSE 6
     h==IF short THEN s.included+1 ELSE 10
     t==IF short THEN s.records[1+p-6][4] ELSE 0
     cuts==[i \in 1..(h-p+1) |-> LET n==p+i-1 IN <<n,n,IF n=6 THEN 0 ELSE 200+n,n-6>>]
     data==[i \in 1..(h-p) |-> p+i]
     inside==[i \in 1..(h-p-1) |-> <<p+i,p+i,200+p+i,p+i-6>>]
     st== <<1,1,167000,4369,8738,0,p,p,IF p=6 THEN 0 ELSE 200+p,333,h,h,200+h,
           400+h,t,500+t,data,p-6,h-6,0,<<2,0,p,h,inside>>>>
     job==[generation |-> 0,reference |-> t,dependency |-> 0,cuts |-> cuts,
           data |-> data,statement |-> st]
 IN <<IF short THEN 1 ELSE 2,job,<<st,st>>,data>>
FixedOffer(short) ==
   /\ s.included<S+4
   /\ LET x==IF short THEN FixedTx(s.included,s.included+1,Record(s.included)[4]) ELSE s.jobs[1]
          proofs==IF short THEN Pair(x.statement) ELSE s.proofs[1]
          data==IF short THEN x.data ELSE s.published[1]
          h==IF short THEN s.included+1 ELSE S+4
          z== <<h,h,200+h,h-S>>
      IN /\ Record(Parent(x))[4]<=x.reference /\ ReadyAt(s,x,proofs,data)
         /\ s'=[Landed(s,x) EXCEPT !.now=IF short /\ h<S+4 THEN s.now+1 ELSE s.now]
         /\ bad'=(bad \/ <<IF short THEN 1 ELSE 2,x,proofs,data>>#FixedExpected(short) \/ s'#[s EXCEPT !.included=h,!.fiHead=h-S,!.activeSnapshot=0,
                   !.now=IF short /\ h<S+4 THEN s.now+1 ELSE s.now,
                   !.records[h-S+1]= <<0,s.included,z,s.now>>,
                   !.applied=[i \in 1..5 |-> IF 1<i /\ i<=h-S+1 THEN 1 ELSE 0]]
                  \/ (short /\ (S+4-s'.included)>=S+4-s.included))
         /\ milestone'= <<IF short THEN 1 ELSE 2,x,proofs,data>>
FixedNext == \E short \in BOOLEAN:FixedOffer(short)
FixedSpec == FixedInit /\ [][FixedNext]_vars
FixedAdmission ==
 /\ (ENABLED (FixedNext /\ milestone'=FixedExpected(TRUE) /\ s'.included=s.included+1))=(s.included<S+4)
 /\ (ENABLED (FixedNext /\ milestone'=FixedExpected(FALSE) /\ s'.included=S+4))=(s.included<S+4)
 /\ s.now=IF s.included=S+4 THEN s.records[5][4] ELSE 1+s.included-S
 /\ (IF s.included<S+4 THEN Record(s.included)[4]<s.now ELSE TRUE)
 /\ s.now-Long.reference<=4
 /\ (ENABLED (FixedNext /\ s'.included=S+4))=(s.included<S+4)
 /\ (ENABLED (FixedNext /\ s'.included=s.included+1))=(s.included<S+4)
 /\ (ENABLED FixedOffer(FALSE))=(s.included<S+4)
 /\ (ENABLED FixedOffer(TRUE))=(s.included<S+4)
 /\ Ready(1)=(s.included<S+4)
 /\ IF s.included<S+4
     THEN LET x==FixedTx(s.included,s.included+1,Record(s.included)[4]) IN ReadyAt(s,x,<<x.statement,x.statement>>,x.data)
     ELSE TRUE
 /\ s.jobs[1]=Long /\ s.published[1]=Long.data /\ s.proofs[1]= <<Long.statement,Long.statement>>
NoLastShort == ~(s.included=S+4 /\ s.records[5][2]=9 /\ milestone[1]=1)
NoLastLong == ~(s.included=S+4 /\ s.records[5][2]=9 /\ milestone[1]=2)
NoInteriorLong == ~(s.included=S+4 /\ s.records[5][2] \in {7,8})
NoFrontier7 == s.included#7
NoFrontier8 == s.included#8
NoFrontier9 == s.included#9

CutTyped(x) == /\ DOMAIN x=1..4 /\ x[1] \in H /\ x[2] \in 1..(110+Depth)
               /\ x[3] \in 0..(310+Depth) /\ x[4] \in 0..Depth
AnchorTyped(x) == /\ DOMAIN x=1..4 /\ x[1] \in 0..1 /\ x[2] \in H
                  /\ x[3] \in Times /\ CutTyped(x[4]) /\ x[2]=x[4][1]
JobTyped(x) ==
 IF x= <<>> THEN TRUE ELSE
 LET n==Len(x.data) z==x.cuts[n+1] a==x.cuts[1] st==x.statement
 IN /\ DOMAIN x={"generation","reference","dependency","cuts","data","statement"}
    /\ x.generation \in 0..1 /\ x.reference \in Times /\ x.dependency \in Times
    /\ n \in 1..Depth /\ DOMAIN x.cuts=1..(n+1)
    /\ \A i \in 1..(n+1):CutTyped(x.cuts[i]) /\ x.cuts[i][1]=a[1]+i-1
    /\ \A i \in 1..n:x.data[i]=x.cuts[i+1][2]
    /\ st= <<1,1,167000,4369,8738,x.generation,a[1],a[2],a[3],333,z[1],z[2],z[3],
          400+z[2],x.reference,500+x.reference,x.data,a[4],z[4],x.dependency,
          <<2,x.generation,a[1],z[1],[i \in 1..(n-1) |-> x.cuts[i+1]]>>>>
Typed ==
 /\ s.generation \in 0..1 /\ s.head \in H /\ s.included \in H /\ s.start \in H
 /\ s.now \in Times /\ s.dependency \in Times /\ s.finalized \in H /\ s.finalizedBlock \in Times
 /\ s.fiHead \in 0..Depth /\ s.producedCount \in 0..MaxProduces
 /\ s.privateHistory \in BOOLEAN /\ s.available \in [1..2 -> BOOLEAN]
 /\ DOMAIN s.canonical=1..(1+Depth) /\ DOMAIN s.records=1..(1+Depth)
 /\ s.applied \in [1..(1+Depth) -> 0..1]
 /\ DOMAIN s.jobs=1..2 /\ DOMAIN s.published=1..2 /\ DOMAIN s.proofs=1..2
 /\ \A j \in 1..2 : DOMAIN s.proofs[j]=1..2
 /\ s.activeSnapshot \in Times /\ AnchorTyped(s.parentAnchor)
 /\ \A a \in s.anchors:AnchorTyped(a)
 /\ \A i \in 1..(1+Depth):
      /\ (s.canonical[i]= <<>> \/ CutTyped(s.canonical[i]))
      /\ (s.records[i]= <<>> \/ (DOMAIN s.records[i]=1..4 /\ s.records[i][1] \in 0..1
          /\ s.records[i][2] \in H /\ CutTyped(s.records[i][3]) /\ s.records[i][4] \in Times))
 /\ \A j \in Slots: JobTyped(s.jobs[j]) /\ Len(s.published[j])<=Depth
      /\ (\A b \in Backends: s.proofs[j][b]= <<>> \/ (\E k \in Slots:s.jobs[k]#<<>> /\ s.proofs[j][b]=s.jobs[k].statement))
 /\ bad \in BOOLEAN
 /\ IF Scenario="Fixed" THEN DOMAIN milestone=1..4 /\ milestone[1] \in 0..2
     ELSE milestone \in 0..3
=============================================================================
