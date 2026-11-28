----------------------- MODULE EtnaAnchorProofRecovery -----------------------
EXTENDS Integers, Sequences, FiniteSets, TLC
CONSTANTS Scenario, Fault
VARIABLES s, receipt, cursor
vars == <<s, receipt, cursor>>
None == "none"
Units == {"bondA","bondB","bondC","bondD"}
T(n) == 1700000000 + 12*n
Max(a,b) == IF a >= b THEN a ELSE b
Elems(q) == {q[i] : i \in DOMAIN q}
Last(q) == q[Len(q)]
At(hist,k) == CHOOSE r \in Elems(hist) : r.number = k
Rec(rs,h) == CHOOSE r \in rs : r.height = h
Origin(os,g) == CHOOSE r \in os : r.g = g
Job(js,id) == CHOOSE j \in js : j.id = id
Cut(b) == [height |-> b.height, el |-> b.el, comet |-> b.comet, fi |-> b.fi]
Decision(m,f,members) ==
    IF m = "3Q" /\ Cardinality(members) >= 3 THEN "Stake" ELSE f
Assignment(h,k) == [height |-> h, committee |-> k]
Fixed(g,h,n,f) == [g |-> g, height |-> h, number |-> n, time |-> T(n), f |-> f]
StartState == [seats |-> Units, members |-> {}, principalD |-> 1, exitD |-> 0,
               snapshotHeight |-> 0]
StartRecord ==
    [height |-> 10,parent |-> 10,g |-> 0,fi |-> 0,comet |-> "ZERO",state |-> StartState,
     el |-> CASE Scenario = "Micro" -> "mE10" [] Scenario = "Twin" -> "forkE10" [] OTHER -> "E10",
     root |-> "startRoot"]
BaseStore == [g |-> 0,c |-> 10,lastEL |-> StartRecord.el,head |-> 0,tail |-> 0,m |-> "3Q",f |-> "F",
              nonce |-> 0,records |-> {StartRecord},origins |-> {Fixed(0,10,100,"F")},signals |-> {}]
Store(r) == [k \in DOMAIN BaseStore |-> r[k]]
\* Symbolic canonical-header identity. The parent commits all prior writes;
\* only the newly determined storage at the live c and origin needs re-opening.
Row(pr, n, arg, result, v) ==
    LET rec == Rec(v.records,v.c)
        tok == <<n,arg,result,v.g,v.c,v.lastEL,v.head,v.tail,v.m,v.f,v.nonce,rec.parent,
                 rec.el,rec.comet,rec.root,Origin(v.origins,v.g).number>>
    IN v @@ [number |-> n, id |-> Append(pr,tok), parent |-> pr,
             offer |-> arg,outcome |-> result]
InitialHistory ==
    LET o == Row(<<>>,100,"origin","written",BaseStore)
        a == Row(o.id,200,"finalize","written",BaseStore)
        bv == [BaseStore EXCEPT !.m = "Disabled", !.tail = IF Scenario \in {"Main","POnly"} THEN 1 ELSE 0]
        b == Row(a.id,320,"policy","written",bv)
        r == Row(b.id,450,"reference","written",bv)
    IN <<o,a,b,r>>
StartNode(base,o,own) ==
    [g |-> o.g,origin |-> o,base |-> base,chain |-> <<>>,tip |-> base.height,state |-> base.state,
     own |-> own,pin |-> own,targetEL |-> base.el,target |-> base.height,stage |-> "Matched",matched |-> base.height,trust |-> TRUE,
     candidate |-> None,phase |-> "Empty",
     pending |-> {Assignment(o.height+1,o.f), Assignment(o.height+2,o.f)}]
Ancestor(n,h) == IF h = n.origin.height THEN n.base ELSE n.chain[h-n.origin.height]
TipBlock(n) == Ancestor(n,n.tip)
Assigned(n,h) == (CHOOSE p \in n.pending : p.height = h).committee

\* These are external certified payload identities and proposal inputs, not
\* expected protocol results. Hashing, execution and QC authenticity are
\* opaque contracts. Different signed inputs get distinct hash symbols.
InputBlock(tag) ==
    CASE tag = "h11" -> <<200,"E11","K11","S11",100,-1>>
      [] tag = "h12" -> <<320,"E12","K12","S12",360,-1>>
      [] tag = "h13" -> <<320,"E13","K13","S13",400,0>>
      [] tag = "bad14" -> <<320,"badE14","badK14","badS14",650,-1>>
      [] tag = "h14" -> <<600,"E14","K14","S14",650,1>>
      [] tag = "h15" -> <<600,"E15old","K15old","S15old",750,-1>>
      [] tag = "n15" -> <<141100,"E15new","K15new","S15new",141000,-1>>
      [] tag = "n16" -> <<141100,"E16new","K16new","S16new",141120,-1>>
      [] tag = "n17" -> <<141100,"E17new","K17new","S17new",141150,-1>>
      [] tag = "v13" -> <<141100,"vE13","vK13","vRoot13",400,0>>
      [] tag = "v14" -> <<141100,"vE14","vK14","vRoot14",141170,1>>
      [] tag = "m11" -> <<200,"mE11","mK11","mRoot11",100,-1>>
      [] tag = "m12" -> <<320,"mE12","mK12","mRoot12",360,-1>>
      [] tag = "a11" -> <<200,"forkE11","forkK11a","forkRoot11",100,-1>>
      [] tag = "b11" -> <<200,"forkE11","forkK11b","forkRoot11",100,-1>>
      [] tag = "b12" -> <<320,"forkE12b","forkK12b","forkRoot12b",360,-1>>

Build(n,hist,tag) ==
    LET d == InputBlock(tag)
        h == n.tip+1
        a == At(hist,d[1])
        first == n.tip = n.origin.height
        p == TipBlock(n)
        carry == IF first THEN TRUE ELSE a.number # p.anchor
        ps == n.state
        st == [ps EXCEPT !.members = ps.seats, !.snapshotHeight = h,
                  !.seats = IF tag = "h15" THEN ps.seats \ {"bondD"} ELSE ps.seats,
                  !.exitD = IF tag = "h15" THEN h ELSE ps.exitD]
        \* Recovered origin EL timestamp is the preserved checkpoint timestamp
        \* (strictly below R in this fixed source family).
        parentTime == IF first THEN IF n.g = 0 THEN T(90) ELSE T(600) ELSE p.time
        cur == IF Fault = "LatestOriginF" /\ n.g > 0 /\ h <= n.origin.height+2
               THEN a.f ELSE Assigned(n,h)
    IN [tag |-> tag,g |-> n.g,height |-> h,anchor |-> a.number,anchorID |-> a.id,
        witness |-> IF carry THEN "carry" ELSE "inherit",
        parentEL |-> p.el,parentComet |-> IF first THEN "EMPTY" ELSE p.comet,
        lastCommit |-> IF first THEN "EMPTY" ELSE p.comet,
        el |-> d[2],comet |-> d[3],root |-> d[4],fi |-> p.fi + IF d[6] >= 0 THEN 1 ELSE 0,
        tx0 |-> d[6],tx |-> IF tag = "h15" THEN "ownerRequestExitD" ELSE "none",
        bft |-> T(d[5]),time |-> Max(parentTime+1,Max(T(d[5]),T(a.number))),
        current |-> cur,next |-> Assigned(n,h+1),decision |-> Decision(a.m,a.f,st.members),
        state |-> st]
ApplyBlock(n,b) ==
    [n EXCEPT !.tip = b.height, !.chain = Append(@,b), !.state = b.state,
       !.pending = {p \in @ : p.height > b.height} \cup {Assignment(b.height+2,b.decision)},
       !.candidate = None, !.phase = "Empty"]
AcceptLocalBlock(n,b) ==
    LET updated == ApplyBlock(n,b)
    IN IF n.stage \in {"Pending","EL"} /\ b.height=n.target /\ b.el#n.targetEL
       THEN [updated EXCEPT !.stage="Mismatch",!.trust=FALSE] ELSE updated
EmptyCandidate(n) == [n EXCEPT !.candidate = None, !.phase = "Empty"]
\* The independent fixture declares these absent/due/executable queue entries.
\* Entry 0 is already sealed by B and entry 1 by C. Optional pre-deadline
\* consumption is permitted. All offered consumed bytes pass both budgets.
EnqueueTime(i) == IF i = 0 THEN T(310) ELSE T(550)
FiValid(p,b,a) ==
    IF b.tx0 < 0 THEN p.fi = a.tail \/ T(a.number) < EnqueueTime(p.fi)+86400
    ELSE b.tx0 = p.fi /\ p.fi < a.tail /\ b.fi = p.fi+1
\* CONS-3.4-6 uses the checkpoint proven by the candidate anchor.
\* LatestC is the explicit sensitivity control.
PressureC(actual,anchor) ==
    IF Fault = "LatestC" THEN actual.c ELSE anchor.c
BlockCheck(x,b) ==
    LET n == x.node
        a == At(x.history,b.anchor)
        p == TipBlock(n)
        first == n.tip = n.origin.height
        advancing == IF first THEN TRUE ELSE b.anchor # p.anchor
    IN /\ b.height = n.tip+1 /\ b.parentEL = p.el /\ b.g = n.g /\ a.g = n.g
       /\ b.anchorID = a.id /\ b.anchor <= n.own /\ b.anchor >= n.origin.number
       /\ IF first THEN b.parentComet = "EMPTY" ELSE b.parentComet = p.comet /\ b.anchor >= p.anchor
       /\ b.witness = IF advancing THEN "carry" ELSE "inherit"
       /\ IF advancing THEN
              IF a.c <= n.tip /\ a.c >= n.origin.height
              THEN a.lastEL = Ancestor(n,a.c).el ELSE FALSE
          ELSE TRUE
       /\ b.time >= T(a.number) /\ b.time-T(a.number) <= 86400
       /\ b.height <= PressureC(x.l1,a)+3
       /\ FiValid(p,b,a)

\* Captured guest interface. The p header's isolated policy read is separate
\* from the ordinary ancestry required for EVERY newly covered anchor.
JobArgs(id) ==
    CASE id = "s" -> <<10,11,450,"mBs","mSzk","mSsecond">>
      [] id = "l" -> <<10,12,450,"mBl","mLzk","mLsecond">>
      [] id = "P" -> <<10,12,450,"BP","Pzk","Psecond">>
      [] id = "short" -> <<12,13,700,"BS","Szk","Ssecond">>
      [] id = "long" -> <<12,14,700,"BL","Lzk","Lsecond">>
      [] id = "suffix" -> <<13,14,860,"BT","Tzk","Tsecond">>
      [] id = "new" -> <<14,15,141200,"BN","Nzk","Nsecond">>
      [] id = "v" -> <<12,14,141200,"vBlob","vZK","vSecond">>
      [] id = "alpha" -> <<10,11,450,"aBlob","aZK","aSecond">>
      [] id = "beta" -> <<10,12,450,"bBlob","bZK","bSecond">>
Stmt(g,p,h,st,en,root,rid,ref,blobs,cuts) ==
    <<"etnaLand","L1","L2","Inbox",g,p,st.el,st.comet,"Config",h,en.el,en.comet,
      root,ref,rid,<<"blobDigest",blobs>>,st.fi,en.fi,<<"cutDigest",g,p,h,cuts>> >>
Capture(n,hist,id) ==
    LET z == JobArgs(id)
        p == z[1]
        h == z[2]
        ref == At(hist,z[3])
        o == n.origin
        st == Cut(Ancestor(n,p))
        bs == [i \in 1..(h-p) |-> Ancestor(n,p+i)]
        en == Cut(Last(bs))
        cuts == [i \in 1..(h-p-1) |-> Cut(bs[i])]
        blobs == <<z[4]>>
        root == Last(bs).root
        pair == <<z[5],z[6]>>
        words == Stmt(n.g,p,h,st,en,root,ref.id,ref.number,blobs,cuts)
    IN [id |-> id,g |-> n.g,origin |-> o,p |-> p,h |-> h,ref |-> ref.number,refID |-> ref.id,
        start |-> st,blocks |-> bs,data |-> [i \in DOMAIN bs |-> bs[i].tag],cuts |-> cuts,
        terminal |-> en,root |-> root,blobs |-> blobs,pair |-> pair,
        statement |-> words, attest |-> << <<z[5],words>>,<<z[6],words>> >>,
        ordinaryRoots |-> {b.anchor : b \in Elems(bs)} \cup {ref.number},
        readAt |-> [role \in {"origin","record","config","queue"} |-> ref.number],
        certs |-> [i \in DOMAIN bs |-> [g |-> n.g,comet |-> bs[i].comet,
                                         committee |-> bs[i].current,power |-> 4]],
        complete |-> TRUE,parentBlock |-> IF p = o.height THEN None ELSE Ancestor(n,p),
        pOnly |-> p > o.height]
Ordinary(a,r,o) == a >= o.number /\ a <= r /\ r-a <= 131072
CertifiedRange(j,hist) ==
    LET bs == j.blocks
        ref == At(hist,j.ref)
        o == j.origin
        parent == j.parentBlock
    IN /\ ref.id = j.refID /\ ref.g = j.g /\ o \in ref.origins
       /\ \E r \in ref.records : Cut(r) = j.start /\ (r.g = j.g \/ r.height = o.height)
       /\ \A i \in DOMAIN bs :
            LET b == bs[i]
                a == At(hist,b.anchor)
            IN /\ b.g = j.g /\ b.height = j.p+i /\ Ordinary(b.anchor,j.ref,o)
               /\ b.anchorID = a.id /\ b.height <= a.c+3 /\ a.g = j.g
               /\ b.parentEL = (IF i = 1 THEN j.start.el ELSE bs[i-1].el)
               /\ b.parentComet = (IF b.height = o.height+1 THEN "EMPTY"
                                   ELSE IF i = 1 THEN j.start.comet ELSE bs[i-1].comet)
               /\ LET select(prev) == LET pa == At(hist,prev.anchor)
                                      IN Decision(pa.m,pa.f,prev.state.members)
                      current == IF b.height<=o.height+2 THEN o.f ELSE
                                   IF i=1 THEN parent.next ELSE
                                   IF i=2 THEN select(parent) ELSE select(bs[i-2])
                      next == IF b.height+1<=o.height+2 THEN o.f ELSE
                                IF i=1 THEN select(parent) ELSE select(bs[i-1])
                  IN b.current=current /\ b.next=next
               /\ b.decision = Decision(a.m,a.f,b.state.members)
       /\ IF j.p = o.height THEN TRUE ELSE
            LET pa == At(hist,parent.anchor)
            IN /\ parent.el = j.start.el /\ parent.comet = j.start.comet /\ parent.anchorID = pa.id
               /\ parent.anchor >= o.number /\ parent.current \in {"F","G","Stake"}
               /\ IF bs[1].witness = "inherit" THEN bs[1].anchorID = parent.anchorID ELSE TRUE

RemoteSeed(n,hist,first,second) ==
    LET one == ApplyBlock(n,Build(n,hist,first))
    IN IF second = None THEN one ELSE ApplyBlock(one,Build(one,hist,second))
InitialJobs(n,hist) ==
    CASE Scenario = "Micro" ->
           LET remote == RemoteSeed(n,hist,"m11","m12")
           IN {Capture(remote,hist,"s"),Capture(remote,hist,"l")}
      [] Scenario = "Twin" ->
           {Capture(RemoteSeed(n,hist,"a11",None),hist,"alpha"),
            Capture(RemoteSeed(n,hist,"b11","b12"),hist,"beta")}
      [] OTHER -> {}
Initial(script) ==
    LET hist == InitialHistory
        n == StartNode(StartRecord,Origin(BaseStore.origins,0),200)
    IN [script |-> script,l1 |-> Last(hist),history |-> hist,node |-> n,
        jobs |-> InitialJobs(n,hist),auth |-> None,authCaptured |-> FALSE]

\* Each input consumes a driver offer. All writers below return a successor
\* and a diagnostic result. Neither component is synthesized by the observer.
I(k,arg,at) == [kind |-> k,arg |-> arg,at |-> at]
Local(k,arg) == I(k,arg,0)
Unit(k) == Local(k,None)
Out(x,name) == [post |-> x,result |-> name]
NodeOut(x,n,name) == Out([x EXCEPT !.node = n],name)
Publish(x,num,arg,result,v) ==
    LET r == Row(x.l1.id,num,arg,result,v)
    IN Out([x EXCEPT !.l1 = r,!.history = Append(@,r)],result)
Prepare(x,tag) ==
    LET n == x.node
        d == InputBlock(tag)
        first == n.tip = n.origin.height
        inherited == IF first THEN FALSE ELSE TipBlock(n).anchor = d[1]
    IN IF n.phase # "Empty" \/ (~inherited /\ d[1] # n.own)
       THEN Out(x,"unavailable")
       ELSE NodeOut(x,[n EXCEPT !.candidate = Build(n,x.history,tag),!.phase = "Prepared"],"prepared")
Admit(x) ==
    LET n == x.node
    IN IF n.phase # "Prepared" THEN Out(x,"unavailable") ELSE
         IF ~BlockCheck(x,n.candidate)
         THEN NodeOut(x,EmptyCandidate(n),
                  IF n.candidate.height > At(x.history,n.candidate.anchor).c+3
                  THEN "pressure" ELSE "invalid")
         ELSE NodeOut(x,[n EXCEPT !.phase = "Admitted"],"admitted")
Sign(x) ==
    LET n == x.node
    IN IF n.phase = "Admitted" /\ n.trust
       THEN NodeOut(x,[n EXCEPT !.phase = "Signed"],"signed") ELSE Out(x,"held")
Commit(x) ==
    LET n == x.node
    IN IF n.phase # "Signed" THEN Out(x,"unavailable") ELSE
         IF BlockCheck(x,n.candidate)
         THEN NodeOut(x,AcceptLocalBlock(n,n.candidate),"committed") ELSE Out(x,"invalid")
\* A finalized head and its 270/271 opening arrive before the separate 285
\* read. A local contradiction is actionable as soon as EL is available.
\* Interface probes may supply a contradictory opening, never a canonical
\* alternate L1 storage history or a certificate.
Learn(x,k,variant) ==
    LET n == x.node
        a == At(x.history,k)
        previous == At(x.history,n.own)
        el == IF variant="wrongEL" THEN "otherFinalizedEL" ELSE a.lastEL
        same == a.g=previous.g /\ a.c=n.target
        localConflict == IF a.g=n.g /\ a.c>=n.origin.height /\ a.c<=n.tip
                         THEN Ancestor(n,a.c).el # el ELSE FALSE
        stage == IF a.g # n.g THEN "Generation" ELSE
                 IF n.stage="Mismatch" \/ localConflict \/ (same /\ el#n.targetEL) THEN "Mismatch" ELSE
                 IF same THEN n.stage ELSE "Pending"
        trust == CASE stage="Matched" -> n.trust
                   [] stage \in {"Pending","EL"} -> Fault="DropPending"
                   [] OTHER -> FALSE
    IN NodeOut(x,[n EXCEPT !.own=k,!.target=a.c,!.targetEL=el,
                     !.pin=IF same THEN n.pin ELSE k,!.stage=stage,!.trust=trust],"learned")
CompareEL(x) ==
    LET n == x.node
    IN IF n.stage # "Pending" \/ n.tip < n.target THEN Out(x,"unavailable") ELSE
         LET ok == Ancestor(n,n.target).el = n.targetEL
         IN NodeOut(x,[n EXCEPT !.stage=IF ok THEN "EL" ELSE "Mismatch",!.trust=FALSE],
                    IF ok THEN "elMatched" ELSE "mismatch")
CompareComet(x,variant) ==
    LET n == x.node
    IN IF n.stage # "EL" THEN Out(x,"unavailable") ELSE
         LET pinned == At(x.history,n.pin)
             r == Rec(pinned.records,n.target)
             readEL == IF variant="wrongEL" THEN "otherRecordEL" ELSE r.el
             readComet == IF variant="wrongComet" THEN "otherRecordComet" ELSE r.comet
             local == Ancestor(n,n.target)
             ok == pinned.g=n.g /\ At(x.history,n.own).g=n.g
                   /\ readEL=n.targetEL /\ readEL=local.el /\ readComet=local.comet
         IN NodeOut(x,[n EXCEPT !.stage=IF ok THEN "Matched" ELSE "Mismatch",
                         !.matched=IF ok THEN n.target ELSE @,!.trust=ok],
                    IF ok THEN "matched" ELSE "mismatch")
Replay(x,tag) ==
    LET n == x.node
        b == IF tag = "m11" THEN Job(x.jobs,"l").blocks[1] ELSE Job(x.jobs,"l").blocks[2]
    IN IF b.height = n.tip+1 /\ BlockCheck(x,b)
       THEN NodeOut(x,AcceptLocalBlock(n,b),"replayed") ELSE Out(x,"unavailable")

\* Calldata, public input, opaque dual-backend statement attestations and
\* guest inputs are separately bound. Faulty external packets are offered
\* to the identical capture/validation operator as canonical packets.
PacketOK(j,hist) ==
    LET bs == j.blocks
        width == j.h-j.p
        r == At(hist,j.ref)
    IN /\ width \in 1..2 /\ Len(bs)=width /\ Len(j.cuts)=width-1
       /\ j.data = [i \in DOMAIN bs |-> bs[i].tag]
       /\ j.cuts = [i \in 1..(width-1) |-> Cut(bs[i])]
       /\ j.terminal=Cut(Last(bs)) /\ j.root=Last(bs).root
       /\ j.statement=Stmt(j.g,j.p,j.h,j.start,j.terminal,j.root,r.id,j.ref,j.blobs,j.cuts)
       /\ j.attest= << <<j.pair[1],j.statement>>,<<j.pair[2],j.statement>> >>
       /\ \A role \in DOMAIN j.readAt :
             j.readAt[role]=r.number /\ j.readAt[role] \in j.ordinaryRoots /\ Ordinary(j.readAt[role],j.ref,j.origin)
       /\ \A i \in DOMAIN bs :
            LET b == bs[i]
                a == At(hist,b.anchor)
                parent == IF i>1 THEN bs[i-1] ELSE j.parentBlock
                first == b.height=j.origin.height+1
                prev == IF i>1 THEN Cut(bs[i-1]) ELSE j.start
                moved == IF first THEN TRUE ELSE parent.anchor # b.anchor
                needsQC == IF i=width THEN TRUE ELSE b.current # bs[i+1].current
            IN /\ b.anchor \in j.ordinaryRoots
               /\ IF needsQC THEN
                      j.certs[i].g=b.g /\ j.certs[i].comet=b.comet
                      /\ j.certs[i].committee=b.current /\ 3*j.certs[i].power > 2*4
                  ELSE TRUE
               /\ b.witness = IF moved THEN "carry" ELSE "inherit"
               /\ b.time>=T(a.number) /\ b.time-T(a.number)<=86400
               /\ IF b.tx0<0 THEN b.fi=prev.fi
                     /\ (prev.fi>=a.tail \/ T(a.number)<EnqueueTime(prev.fi)+86400)
                  ELSE b.tx0=prev.fi /\ b.fi=prev.fi+1 /\ prev.fi<a.tail
       /\ CertifiedRange(j,hist)

BaseJob(arg) ==
    CASE arg \in {"trimLong","omitCut","noInheritedRoot","recordAtB"} -> "long"
      [] arg="wrongOriginNext" -> "P"
      [] arg \in {"pConfig","pRecord","pQueue","pWrongPolicy","wrongTerminalNext"} -> "v"
      [] OTHER -> arg
Wire(j,arg) ==
    CASE arg="trimLong" -> [j EXCEPT !.data = Tail(@)]
      [] arg="omitCut" -> [j EXCEPT !.cuts = <<>>]
      [] arg="noInheritedRoot" -> [j EXCEPT !.ordinaryRoots = @ \ {j.parentBlock.anchor}]
      [] arg="recordAtB" -> [j EXCEPT !.readAt["record"] = 320]
      [] arg="wrongTerminalNext" -> [j EXCEPT !.blocks[Len(j.blocks)].next = "F"]
      [] arg="wrongOriginNext" -> [j EXCEPT !.blocks[1].next = "Stake"]
      [] arg="pConfig" -> [j EXCEPT !.readAt["config"] = j.parentBlock.anchor]
      [] arg="pRecord" -> [j EXCEPT !.readAt["record"] = j.parentBlock.anchor]
      [] arg="pQueue" -> [j EXCEPT !.readAt["queue"] = j.parentBlock.anchor]
      [] arg="pWrongPolicy" -> [j EXCEPT !.parentBlock.anchorID = j.blocks[1].anchorID]
      [] OTHER -> j

MakeJob(x,arg) ==
    LET id == BaseJob(arg)
        z == JobArgs(id)
    IN IF x.node.tip < z[2] \/ z[1] < x.node.origin.height
          \/ ~(\E a \in Elems(x.history) : a.number = z[3])
       THEN Out(x,"unavailable")
       ELSE LET j == Wire(Capture(x.node,x.history,id),arg)
            IN IF PacketOK(j,x.history) THEN Out([x EXCEPT !.jobs = @ \cup {j}],"captured")
               ELSE Out(x,"invalid")
\* Actual L1 looks up the recorded origin, live c and live FI on each offer.
\* Guest verification has no local-node or live-checkpoint precondition.
CutMatches(r,leaf) ==
    IF Fault = "ElOnlyCut" THEN r.el = leaf.el ELSE Cut(r) = leaf
LandResult(x,j,num) ==
    LET v == x.l1
        o == Origin(v.origins,v.g)
    IN IF j.h <= v.c THEN "alreadySettled"
       ELSE IF j.g # v.g \/ j.origin # o \/ j.p < o.height \/ j.p > v.c
               \/ j.h-j.p > 2 \/ j.ref >= num \/ num-j.ref > 8191
               \/ ~(\E r \in v.records : r.height=j.p /\ (r.g=v.g \/ r.height=o.height)
                                             /\ Cut(r)=j.start)
            THEN "invalid"
       ELSE LET actual == Rec(v.records,v.c)
            IN IF actual.fi # v.head THEN "invalid"
               ELSE IF v.c>j.p /\ ~CutMatches(actual,j.cuts[v.c-j.p]) THEN "cutMismatch"
               ELSE IF ~j.complete \/ j.terminal.fi < v.head \/ j.terminal.fi > v.tail
                          \/ j.terminal.fi-v.head > j.h-v.c
                    THEN "invalid" ELSE "accepted"
LandStore(v,j) ==
    LET b == Last(j.blocks)
        r == [height |-> j.h,parent |-> v.c,g |-> v.g,el |-> b.el,comet |-> b.comet,
              fi |-> b.fi,root |-> j.root,state |-> b.state]
        sig == [height |-> j.h,el |-> b.el,root |-> j.root]
    IN [Store(v) EXCEPT !.c = j.h, !.lastEL = b.el, !.head = b.fi, !.records = @ \cup {r}, !.signals = @ \cup {sig}]
Slot(x,id,num) ==
    IF id = "idle" THEN Publish(x,num,id,"idle",Store(x.l1))
    ELSE IF ~(\E j \in x.jobs : j.id=id) THEN Publish(x,num,id,"unavailable",Store(x.l1))
    ELSE LET j == Job(x.jobs,id)
             result == LandResult(x,j,num)
         IN Publish(x,num,id,result,IF result="accepted" THEN LandStore(x.l1,j) ELSE Store(x.l1))

Change(x,arg,num) ==
    LET v == Store(x.l1)
        changed == CASE arg="enqueue1" -> [v EXCEPT !.tail = @+1]
                     [] arg="restoreM" -> [v EXCEPT !.m = "3Q"]
                     [] arg="rotate" -> [v EXCEPT !.f = "G"]
                     [] OTHER -> v
    IN Publish(x,num,arg,"written",changed)
Auth(v) == [g |-> v.g,c |-> v.c,nonce |-> v.nonce,until |-> 1720000000]
Recover(x,mode,num) ==
    LET v == x.l1
        \* For the fresh input the DAO independently audited the prefix and
        \* found last-provable 14 after the outage. The stale input is the
        \* original contract diagnostic captured before two further landings.
        a == IF mode="fresh" THEN [g |-> 0,c |-> 14,nonce |-> 0,until |-> 1720000000] ELSE x.auth
    IN IF mode="stale" /\ ~x.authCaptured THEN Publish(x,num,mode,"unavailable",Store(v)) ELSE
         IF a.g # v.g \/ a.c # v.c \/ a.nonce # v.nonce \/ T(num)>a.until
         THEN Publish(x,num,mode,"stale",Store(v))
         ELSE LET o == Fixed(v.g+1,v.c,num,v.f)
                  nv == [Store(v) EXCEPT !.g = @+1, !.nonce = @+1, !.origins = @ \cup {o}]
              IN Publish(x,num,mode,"recovered",nv)
\* The external archive/restored EL opening is independently supplied. Here
\* the one audited recovery checkpoint has four retained seats at L14. The
\* symbolic EL/header, state-root and snapshot authentication contracts cover
\* their real encodings. Only 285 EL/Comet/FI, 270/271, SignalService and
\* the fixed origin are on-chain reads. record.state and .root are ghosts.
ArchiveInput(kind) ==
    LET ledger == [seats |-> Units,members |-> Units,principalD |-> 1,exitD |-> 0,snapshotHeight |-> 14]
    IN [height |-> 14,el |-> IF kind="wrongArchiveEL" THEN "E15old" ELSE "E14",
        root |-> IF kind="wrongArchiveRoot" THEN "S15old" ELSE "S14",state |-> ledger,
        stateAuth |-> kind#"noStateAuth",originAuth |-> kind#"noOriginAuth",
        genesisAuth |-> kind#"noGenesisAuth",sessionAuth |-> kind#"noSessionAuth"]
Rebuild(x,kind) ==
    LET n == x.node
        a == At(x.history,n.own)
        o == Origin(a.origins,a.g)
        archive == ArchiveInput(kind)
    IN IF n.stage # "Generation" \/ a.g<=n.g \/ a.c#o.height THEN Out(x,"unavailable")
       ELSE LET saved == Rec(a.records,o.height)
                bridge == [height |-> archive.height,el |-> archive.el,root |-> archive.root]
                ok == archive.stateAuth /\ archive.originAuth /\ archive.genesisAuth /\ archive.sessionAuth
                      /\ archive.height=o.height /\ archive.el=a.lastEL /\ archive.el=saved.el
                      /\ bridge \in a.signals
                base == [saved EXCEPT !.el=archive.el,!.root=archive.root,!.state=archive.state]
            IN IF ok THEN NodeOut(x,StartNode(base,o,a.number),"rebuilt") ELSE Out(x,"unauthenticated")
Dispatch(x,e) ==
    CASE e.kind="Prepare" -> Prepare(x,e.arg)
      [] e.kind="Admit" -> Admit(x)
      [] e.kind="Sign" -> Sign(x)
      [] e.kind="Commit" -> Commit(x)
      [] e.kind="Replay" -> Replay(x,e.arg)
      [] e.kind="Learn" -> Learn(x,e.at,e.arg)
      [] e.kind="EL" -> CompareEL(x)
      [] e.kind="Comet" -> CompareComet(x,e.arg)
      [] e.kind="Gate" -> Out(x,IF x.node.trust THEN "open" ELSE "held")
      [] e.kind="FailedRead" -> Out(x,"unavailable")
      [] e.kind="Capture" -> MakeJob(x,e.arg)
      [] e.kind="Slot" -> Slot(x,e.arg,e.at)
      [] e.kind="Advance" -> Change(x,e.arg,e.at)
      [] e.kind="Auth" -> Out([x EXCEPT !.auth = Auth(x.l1),!.authCaptured = TRUE],"captured")
      [] e.kind="Recover" -> Recover(x,e.arg,e.at)
      [] e.kind="Rebuild" -> Rebuild(x,e.arg)

\* The scripts contain inputs, including refused inputs; no milestone selects
\* the next action. In Micro the genuine remote jobs exist before local replay.
BlockOffers(tag) == <<Local("Prepare",tag),Unit("Admit"),Unit("Sign"),Unit("Commit")>>
LearnAt(k) == I("Learn",None,k)
MatchAt(k) == <<LearnAt(k),Unit("Gate"),Unit("EL"),Unit("FailedRead"),Unit("Comet")>>
Prefix ==
    <<Local("Prepare","h11"),LearnAt(320),Unit("Admit"),Unit("Sign"),Unit("Commit")>>
    \o BlockOffers("h12") \o <<Local("Capture","P"),I("Advance","enqueue1",550),I("Slot","P",600),
                               Unit("Auth")>> \o MatchAt(600)
BeforeOrders ==
    Prefix \o BlockOffers("h13") \o <<Local("Prepare","bad14"),Unit("Admit")>>
    \o BlockOffers("h14") \o <<I("Advance","reference",700),Local("Capture","short"),Local("Capture","long")>>
ShortOrder ==
    <<I("Slot","short",820)>> \o MatchAt(820) \o <<I("Slot","long",930)>> \o MatchAt(930)
DirectOrder ==
    <<I("Slot","long",820)>> \o MatchAt(820)
    \o <<I("Slot","short",930),I("Slot","long",960)>>
AfterOrders ==
    <<I("Recover","stale",1000)>> \o BlockOffers("h15")
    \o <<I("Advance","outage",140000),I("Recover","fresh",141000),LearnAt(141000),
          Unit("Gate"),Unit("Rebuild"),I("Advance","rotate",141100),LearnAt(141100)>>
    \o BlockOffers("n15") \o BlockOffers("n16") \o BlockOffers("n17")
    \o <<I("Advance","reference",141200),Local("Capture","new"),I("Slot","new",141300),
          I("Slot","P",141310),I("Slot","short",141320),I("Slot","long",141330)>>
Script(k) ==
    CASE k="ShortFirst" -> BeforeOrders \o ShortOrder \o AfterOrders
      [] k="DirectLong" -> BeforeOrders \o DirectOrder \o AfterOrders
      [] k="POnly" -> Prefix \o <<I("Advance","restoreM",141100),LearnAt(141100)>>
                        \o BlockOffers("v13") \o BlockOffers("v14")
                        \o <<I("Advance","reference",141200),Local("Capture","v"),I("Slot","v",141300)>>
      [] k="Twin" -> <<I("Slot","alpha",500),I("Slot","beta",600)>>
Scripts == CASE Scenario="Main" -> {"ShortFirst","DirectLong"} [] OTHER -> {Scenario}
Init ==
    \E k \in Scripts :
        LET x == Initial(k)
        IN /\ s = x /\ cursor = 0
           /\ receipt = [event |-> "Init",input |-> Unit("Init"),outcome |-> "init",before |-> x]
Take(e,c) ==
    LET r == Dispatch(s,e)
    IN /\ s' = r.post /\ cursor' = c
       /\ receipt' = [event |-> e.kind,input |-> e,outcome |-> r.result,before |-> s]
MicroOffers(x) ==
    LET n == x.node
        num == x.l1.number
        slot == IF num=450 THEN 500 ELSE 600
        \* Fresh H11 starts with A. An already prepared proposal can survive
        \* later finalized B. Replay obtains independent certificates.
        props == CASE n.phase # "Empty" -> {}
                   [] n.tip=10 /\ n.own=200 -> {Local("Prepare","m11")}
                   [] n.tip=11 /\ n.own=320 -> {Local("Prepare","m12")}
                   [] OTHER -> {}
        phase == CASE n.phase="Prepared" -> {Unit("Admit")}
                   [] n.phase="Admitted" -> {Unit("Sign")}
                   [] n.phase="Signed" -> {Unit("Commit")}
                   [] OTHER -> {}
        replay == CASE n.tip=10 -> {Local("Replay","m11")}
                    [] n.tip=11 /\ n.own>=320 -> {Local("Replay","m12")}
                    [] OTHER -> {}
        comparisons == CASE n.stage="Pending" -> {Unit("EL"),Unit("Gate"),Unit("FailedRead")}
                         [] n.stage="EL" -> {Unit("Comet"),Unit("Gate"),Unit("FailedRead")}
                         [] OTHER -> {}
        available == {a \in Elems(x.history) : a.number > n.own /\ a.number \in {320,500,600}}
    IN props \cup phase \cup replay \cup comparisons
       \cup {LearnAt(a.number) : a \in available}
       \cup IF num < 600 THEN {I("Slot",q,slot) : q \in {"idle","s","l"}} ELSE {}
Next ==
    IF Scenario="Micro" THEN \E e \in MicroOffers(s) : Take(e,0)
    ELSE LET seq == Script(s.script)
         IN /\ cursor < Len(seq) /\ Take(seq[cursor+1],cursor+1)
Spec == Init /\ [][Next]_vars

\* State predicates are observations only. They inspect the input/prestate
\* and actual successor, with the source rules reopened independently.
Prior == receipt.before
Ev == receipt.event
Arg == receipt.input.arg
Result == receipt.outcome
ActualLanding == Ev="Slot" /\ Result="accepted"
Heights(rs) == {r.height : r \in rs}
TypeOK ==
    /\ Scenario \in {"Micro","Main","Twin","POnly"}
    /\ Fault \in {"None","LatestC","ElOnlyCut","LatestOriginF","DropPending"}
    /\ s.script \in Scripts /\ cursor \in Nat /\ (Scenario="Micro" => cursor=0)
    /\ s.l1=Last(s.history) /\ s.l1.c \in 10..17 /\ s.l1.g \in 0..1
    /\ s.l1.head \in 0..s.l1.tail /\ s.l1.tail \in 0..2 /\ s.l1.nonce=s.l1.g
    /\ s.l1.c \in Heights(s.l1.records)
    /\ Cardinality(Heights(s.l1.records))=Cardinality(s.l1.records)
    /\ Cardinality({j.id : j \in s.jobs})=Cardinality(s.jobs)
    /\ s.node.tip=s.node.origin.height+Len(s.node.chain)
    /\ s.node.state=TipBlock(s.node).state /\ s.node.g=s.node.origin.g
    /\ s.node.stage \in {"Matched","Pending","EL","Mismatch","Generation"}
    /\ s.node.trust \in BOOLEAN /\ s.node.phase \in {"Empty","Prepared","Admitted","Signed"}
    /\ IF s.node.phase="Empty" THEN s.node.candidate=None ELSE s.node.candidate.height=s.node.tip+1
    /\ s.node.matched<=s.node.tip /\ s.node.pin<=s.node.own /\ s.node.own<=s.l1.number

Fence(b) ==
    LET a == At(s.history,b.anchor)
    IN /\ b.anchorID=a.id /\ b.height<=a.c+3 /\ a.g=b.g
       /\ b.time>=T(b.anchor) /\ b.time-T(b.anchor)<=86400
AnchorFenceSafe ==
    /\ IF s.node.phase \in {"Admitted","Signed"} THEN Fence(s.node.candidate) ELSE TRUE
    /\ IF s.node.tip>s.node.origin.height THEN Fence(Last(s.node.chain)) ELSE TRUE

ActualCutSafe ==
    IF ~ActualLanding THEN TRUE ELSE
      LET v == Prior.l1
          j == Job(Prior.jobs,Arg)
          r == Rec(v.records,v.c)
      IN /\ j.p<=v.c /\ v.c<j.h /\ j.g=v.g /\ r.fi=v.head
         /\ j.start=Cut(Rec(v.records,j.p))
         /\ IF j.p=v.c THEN TRUE ELSE
              LET leaf == j.cuts[v.c-j.p]
              IN /\ leaf.height=v.c /\ leaf.fi=v.head /\ leaf.el=r.el /\ leaf.comet=r.comet

LandingStateSafe ==
    IF ~ActualLanding THEN TRUE ELSE
      LET old == Prior.l1
          v == s.l1
          j == Job(Prior.jobs,Arg)
          b == Last(j.blocks)
          saved == Rec(v.records,j.h)
          sig == [height |-> j.h,el |-> b.el,root |-> b.root]
          parents == {r \in v.records : r.height#j.h}
      IN /\ s.node=Prior.node /\ s.jobs=Prior.jobs /\ j.h= v.c /\ v.head=j.terminal.fi
         /\ old.head<=v.head /\ v.head<=old.tail /\ v.head-old.head<=j.h-old.c
         /\ v.head-old.head = Last(j.blocks).fi-Cut(Rec(old.records,old.c)).fi
         /\ saved.parent=old.c /\ saved.g=old.g /\ Cut(saved)=j.terminal
         /\ v.lastEL=b.el /\ saved.root=b.root /\ saved.state=b.state /\ parents=old.records
         /\ v.signals=old.signals \cup {sig}
         /\ v.origins=old.origins /\ v.nonce=old.nonce /\ v.tail=old.tail
         /\ v.g=old.g /\ v.m=old.m /\ v.f=old.f

StoredProof(j) ==
    LET bs == j.blocks
        w == j.statement
        ref == At(s.history,j.ref)
    IN /\ j.complete /\ j.origin.g=j.g /\ j.refID=ref.id
       /\ Len(bs)=j.h-j.p /\ Len(j.data)=Len(bs) /\ Len(j.cuts)=Len(bs)-1
       /\ j.start.height=j.p /\ j.terminal=Cut(Last(bs)) /\ j.root=Last(bs).root
       /\ Len(w)=19 /\ w[5]=j.g /\ w[6]=j.p /\ w[7]=j.start.el /\ w[8]=j.start.comet
       /\ w[10]=j.h /\ w[11]=j.terminal.el /\ w[12]=j.terminal.comet /\ w[13]=j.root
       /\ w[14]=j.ref /\ w[15]=ref.id /\ w[16]= <<"blobDigest",j.blobs>>
       /\ w[17]=j.start.fi /\ w[18]=j.terminal.fi /\ w[19]= <<"cutDigest",j.g,j.p,j.h,j.cuts>>
       /\ j.attest[1]= <<j.pair[1],w>> /\ j.attest[2]= <<j.pair[2],w>>
       /\ \A role \in {"record","origin","config","queue"} :
               j.readAt[role]=j.ref /\ j.readAt[role] \in j.ordinaryRoots /\ j.ref-j.readAt[role] \in 0..131072
               /\ j.readAt[role]>=j.origin.number
       /\ \A i \in DOMAIN bs :
            LET b == bs[i]
            IN /\ b.height=j.p+i /\ j.data[i]=b.tag /\ b.g=j.g
               /\ b.anchor \in j.ordinaryRoots /\ j.ref-b.anchor \in 0..131072
               /\ b.anchor>=j.origin.number /\ At(s.history,b.anchor).id=b.anchorID
               /\ LET decided(q) == LET a == At(s.history,q.anchor)
                                    IN IF a.m="Disabled" \/ Cardinality(q.state.members)<3 THEN a.f ELSE "Stake"
                      h == b.height
                      origin == j.origin
                  IN /\ IF h<=origin.height+2 THEN b.current=origin.f
                        ELSE IF i=1 THEN b.current=j.parentBlock.next
                        ELSE IF i=2 THEN b.current=decided(j.parentBlock)
                        ELSE b.current=decided(bs[i-2])
                     /\ IF h+1<=origin.height+2 THEN b.next=origin.f
                        ELSE IF i=1 THEN b.next=decided(j.parentBlock)
                        ELSE b.next=decided(bs[i-1])
               /\ IF i<Len(bs) THEN j.cuts[i]=Cut(b) ELSE TRUE
       /\ IF j.p>j.origin.height THEN
              LET p == j.parentBlock
                  a == At(s.history,p.anchor)
              IN /\ p.anchorID=a.id /\ Cut(p)=j.start /\ j.pOnly
                 /\ bs[1].next=(IF a.m="Disabled" \/ Cardinality(p.state.members)<3 THEN a.f ELSE "Stake")
                 /\ bs[1].current=(IF j.p+1<=j.origin.height+2 THEN j.origin.f ELSE p.next)
          ELSE ~j.pOnly /\ j.parentBlock=None
ProofBindingSafe ==
    /\ Prior.jobs \subseteq s.jobs
    /\ IF Ev="Init" THEN \A j \in s.jobs : StoredProof(j)
       ELSE \A j \in s.jobs \ Prior.jobs : StoredProof(j)

CommitteeAnchorSafe ==
    IF Ev \notin {"Commit","Replay"} \/ Result \notin {"committed","replayed"} THEN TRUE ELSE
        LET b == Last(s.node.chain)
            a == At(s.history,b.anchor)
            n == Prior.node
            expected == IF a.m="3Q" /\ Cardinality(n.state.seats)>=3 THEN "Stake" ELSE a.f
        IN /\ b.state.members=n.state.seats /\ b.state.snapshotHeight=b.height
           /\ b.decision=expected /\ Assignment(b.height+2,expected) \in s.node.pending
           /\ b.next=Assigned(n,b.height+1)
           /\ IF b.height>n.origin.height+2
              THEN b.current=Ancestor(n,b.height-2).decision ELSE TRUE
SignerTrustSafe ==
    LET n == s.node
        old == Prior.node
        own == At(s.history,n.own)
        pin == At(s.history,n.pin)
    IN /\ n.target=own.c /\ pin.c=n.target /\ pin.g=own.g
       /\ (n.trust => n.stage="Matched" /\ n.matched=n.target /\ n.g=own.g /\ n.tip>=n.target
            /\ n.targetEL=own.lastEL /\ Ancestor(n,n.target).el=n.targetEL
            /\ IF n.target=n.origin.height THEN n.base.el=own.lastEL
               ELSE LET r == Rec(pin.records,n.target)
                        b == Ancestor(n,n.target)
                    IN r.el=b.el /\ r.comet=b.comet)
       /\ IF Ev="Learn" /\ own.g=At(Prior.history,old.own).g /\ n.target=old.target THEN
              /\ n.pin=old.pin
              /\ IF old.stage="EL" /\ n.targetEL=old.targetEL THEN n.stage="EL" ELSE TRUE
          ELSE TRUE
       /\ IF own.g=n.g /\ n.target<=n.tip /\ n.target>=n.origin.height THEN
              IF Ancestor(n,n.target).el # n.targetEL THEN n.stage="Mismatch" /\ ~n.trust ELSE TRUE
          ELSE TRUE
       /\ IF Ev="Comet" /\ old.stage="EL" /\ Arg \in {"wrongEL","wrongComet"}
          THEN n.stage="Mismatch" /\ ~n.trust ELSE TRUE
       /\ ((Ev="Sign" /\ Result="signed") => Prior.node.trust /\ Prior.node.stage="Matched")
OriginFallbackSafe ==
    LET n == s.node
    IN IF n.phase="Signed" THEN
         LET b == n.candidate
         IN IF b.height<=n.origin.height+2 THEN b.current=n.origin.f ELSE TRUE
       ELSE IF Ev \in {"Commit","Replay"} /\ Result \in {"committed","replayed"}
            THEN IF n.tip<=n.origin.height+2 THEN Last(n.chain).current=n.origin.f ELSE TRUE
            ELSE TRUE
RecoveryStateSafe ==
    CASE Ev="Recover" /\ Result="recovered" ->
        LET v == s.l1
            old == Prior.l1
            o == Origin(v.origins,v.g)
        IN /\ v.c=old.c /\ v.lastEL=old.lastEL /\ v.head=old.head /\ v.tail=old.tail /\ v.records=old.records
           /\ v.signals=old.signals /\ v.g=old.g+1 /\ v.nonce=old.nonce+1
           /\ o.height=old.c /\ o.number=v.number /\ o.time=T(v.number) /\ o.f=old.f
           /\ v.origins=old.origins \cup {o} /\ v.m=old.m /\ v.f=old.f /\ s.node=Prior.node
      [] Ev="Rebuild" /\ Result="rebuilt" ->
        LET n == s.node
            a == At(s.history,Prior.node.own)
            o == Origin(a.origins,a.g)
            rec == Rec(a.records,o.height)
        IN /\ n.g=a.g /\ n.origin=o /\ Cut(n.base)=Cut(rec) /\ n.state=rec.state
           /\ n.base.el=a.lastEL /\ [height |-> n.tip,el |-> n.base.el,root |-> n.base.root] \in a.signals
           /\ n.base.root=rec.root /\ n.base.state=n.state
           /\ Arg \notin {"wrongArchiveEL","wrongArchiveRoot","noStateAuth","noOriginAuth","noGenesisAuth","noSessionAuth"}
           /\ n.chain= <<>> /\ n.tip=o.height /\ n.phase="Empty" /\ n.candidate=None
           /\ n.trust /\ n.target=a.c /\ n.matched=a.c
           /\ n.pending={Assignment(o.height+1,o.f),Assignment(o.height+2,o.f)}
      [] OTHER -> TRUE

FrameSafe ==
    LET x == Prior
        v == s.l1
    IN /\ s.script=x.script
       /\ IF Ev \in {"Advance","Recover","Slot"} THEN
              /\ v.number=receipt.input.at /\ v.number>x.l1.number /\ v.parent=x.l1.id
              /\ v.offer=Arg /\ v.outcome=Result /\ s.history=Append(x.history,v)
              /\ s.node=x.node /\ s.jobs=x.jobs /\ s.auth=x.auth
              /\ IF (Ev="Slot" /\ Result#"accepted") \/ (Ev="Recover" /\ Result#"recovered")
                 THEN Store(v)=Store(x.l1) ELSE TRUE
          ELSE s.l1=x.l1 /\ s.history=x.history
       /\ IF Ev#"Capture" THEN s.jobs=x.jobs ELSE s.node=x.node
       /\ IF Ev#"Auth" THEN s.auth=x.auth /\ s.authCaptured=x.authCaptured ELSE s.node=x.node
       /\ IF (Ev \in {"Gate","FailedRead"}) \/ ((Ev \notin {"Slot","Recover","Advance"}) /\
              Result \in {"held","unavailable","unauthenticated"})
          THEN s=x ELSE TRUE
       /\ IF Ev="Capture" /\ Result="invalid" THEN s=x ELSE TRUE
       /\ IF Ev="Admit" /\ Result="pressure" THEN
              s.node=[x.node EXCEPT !.candidate=None,!.phase="Empty"] ELSE TRUE

NoPressureRefusal ==
    ~(Ev="Admit" /\ Result="pressure" /\ Prior.l1.c=12 /\ Prior.node.tip=13
      /\ Prior.node.candidate.anchor=320 /\ s.node.tip=13)
NoOverlap ==
    ~(ActualLanding /\ Arg="long" /\ Prior.l1.c=13 /\ s.l1.c=14
      /\ Rec(s.l1.records,14).parent=13 /\ s.l1.head=2)
NoDirectLong ==
    ~(ActualLanding /\ Arg="long" /\ Prior.l1.c=12 /\ s.l1.c=14
      /\ Rec(s.l1.records,14).parent=12 /\ 13 \notin Heights(s.l1.records))
NoRetained ==
    ~(Ev="Admit" /\ Result="admitted" /\ s.node.own=320 /\ s.node.candidate.anchor=200
      /\ s.node.candidate.height=11 /\ s.node.candidate=Prior.node.candidate
      /\ s.node.candidate.decision="Stake")
NoPendingTrust ==
    ~(Ev="FailedRead" /\ s.node.stage="EL" /\ ~s.node.trust /\ s.node.target>s.node.matched)
NoRecovered ==
    ~(Ev="Rebuild" /\ Result="rebuilt" /\ Prior.node.tip=15 /\ Prior.node.state.exitD=15
      /\ s.node.tip=14 /\ s.node.g=1 /\ s.node.state.exitD=0 /\ "bondD" \in s.node.state.seats)
NoNewDomainLanded ==
    ~(ActualLanding /\ Arg="new" /\ Prior.l1.g=1 /\ Rec(Prior.l1.records,14).g=0
      /\ s.l1.c=15 /\ Rec(s.l1.records,15).g=1)
NoOriginFrozen ==
    ~(s.node.g=1 /\ s.node.tip=17 /\ s.node.origin.f="F" /\ s.l1.f="G"
      /\ s.node.chain[1].current="F" /\ s.node.chain[2].current="F"
      /\ s.node.chain[3].current="G")
NoAncestryBudget ==
    ~(Ev="Advance" /\ Arg="outage" /\ s.node.tip=15 /\ s.l1.c=14
      /\ s.l1.number-8191-Last(s.node.chain).anchor>131072)
NoPOnlyWitness ==
    ~(ActualLanding /\ Arg="v" /\
        LET j == Job(s.jobs,"v")
        IN /\ j.pOnly /\ j.ref-j.parentBlock.anchor>131072
           /\ j.ref-j.blocks[1].anchor<=131072 /\ j.blocks[1].witness="carry"
           /\ j.blocks[1].current="Stake" /\ j.blocks[2].current="F"
           /\ j.blocks[1].tx0=0 /\ j.blocks[2].tx0=1 /\ s.l1.head=2)
SafetyBits == <<TypeOK,AnchorFenceSafe,ActualCutSafe,LandingStateSafe,ProofBindingSafe,
                CommitteeAnchorSafe,SignerTrustSafe,OriginFallbackSafe,RecoveryStateSafe,FrameSafe>>
ObservationBits == <<NoPressureRefusal,NoOverlap,NoDirectLong,NoRetained,NoPendingTrust,NoRecovered,
                     NoNewDomainLanded,NoOriginFrozen,NoAncestryBudget,NoPOnlyWitness>>
StateView == <<s,cursor,SafetyBits,ObservationBits>>
=============================================================================
