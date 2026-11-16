#!/usr/bin/env python3
"""Export actual unchanged checkpoint-identity action enabledness and retained cuts."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
BASE = ROOT.parent / "EtnaSettlement.tla"
MODEL = ROOT.parent / "EtnaCheckpointIdentity.tla"
PARSER_SOURCE = ROOT / "export_recovery.py"
_spec = importlib.util.spec_from_file_location("etna_identity_parser", PARSER_SOURCE)
_parser = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_parser)
ValueParser = _parser.ValueParser
FIELDS = ("EL", "Comet", "FI", "Val")
LENGTHS = {"Compatible": 4, "Frontier": 4, "Origin": 3, "Recovery": 7, "Divergent": 4}
REQUIRED = {field + "/" + case for field in FIELDS for case in LENGTHS}
TLC_SHA = "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
WRAPPER = r'''----------------------- MODULE EtnaIdentityExport -----------------------
EXTENDS EtnaCheckpointIdentity, Sequences
CONSTANT CaseNames
VARIABLES caseName, step, emitting, accepted, op, requestProof, requestIdentity, beforeObservation
Observe == [checkpoint |-> c, generation |-> generation, nonce |-> recoveryNonce,
 start |-> startHeight, records |-> [h \in 0..MaxHeight |->
 [present |-> landings[h].present, generation |-> landings[h].generation,
 parent |-> landings[h].parent, cut |-> recordCuts[h]]], audit |-> identityAudit]
History == IF caseName \in {"Frontier", "Divergent"} THEN "B" ELSE "A"
Script == CASE caseName="Origin" -> <<2,4>>
 [] caseName="Recovery" -> <<2,1,5,6,3,7>> [] OTHER -> <<1,2,3>>
ProofFor(o) == IF o=3 THEN pendingProof ELSE
 [present |-> TRUE, generation |-> generation, parent |-> c,
 terminal |-> IF o=2 THEN 1 ELSE 3]
IdentityFor(o) == IF o=3 THEN queuedIdentity ELSE
 BuildIdentity(IF o=1 THEN History ELSE "A", IF o=1 THEN History ELSE "A", o=4)
Apply(o) == CASE o=1 -> PrepareIdentityProof(3,History,History,FALSE)
 [] o=2 -> IdentityLandFresh(1,"A","A",FALSE)
 [] o=3 -> IdentityLand(pendingProof,queuedIdentity)
 [] o=4 -> IdentityLand(ProofFor(o),IdentityFor(o))
 [] o=5 -> Authorize(1) /\ UNCHANGED identityVars
 [] o=6 -> IdentityRecover
 [] o=7 -> IdentityLandFresh(3,"A","A",FALSE)
exportVars == <<allVars,caseName,step,emitting,accepted,op,requestProof,requestIdentity,beforeObservation>>
ExportInit == /\ IdentityInit /\ caseName \in CaseNames /\ step=0 /\ emitting=TRUE
 /\ accepted=TRUE /\ op=0 /\ requestProof=pendingProof /\ requestIdentity=queuedIdentity
 /\ beforeObservation=Observe
Execute == /\ ~emitting /\ step<Len(Script)
 /\ LET o==Script[step+1] enabled==ENABLED Apply(o)
 IN /\ IF enabled THEN Apply(o) ELSE UNCHANGED allVars
    /\ accepted'=enabled /\ op'=o /\ requestProof'=ProofFor(o) /\ requestIdentity'=IdentityFor(o)
 /\ beforeObservation'=Observe /\ step'=step+1 /\ emitting'=TRUE /\ UNCHANGED caseName
Emit == /\ emitting
 /\ PrintT(<<"ETNA_IDENTITY",caseName,step,[op |-> op, accepted |-> accepted,
 proof |-> requestProof, identity |-> requestIdentity,
 cuts |-> [x \in 0..MaxHeight |-> SuppliedCut(requestProof,requestIdentity,x)],
 terminal |-> ExecutedCut(requestProof,requestIdentity,requestProof.terminal),
 before |-> beforeObservation, after |-> Observe]>>)
 /\ emitting'=FALSE
 /\ UNCHANGED <<allVars,caseName,step,accepted,op,requestProof,requestIdentity,beforeObservation>>
ExportSpec == ExportInit /\ [][Execute \/ Emit]_exportVars
=============================================================================
'''


def digest(value):
    return hashlib.sha256(value).hexdigest()


def content_digest(value):
    return digest(json.dumps({k: v for k, v in value.items() if k != "content_sha256"},
                             sort_keys=True, separators=(",", ":")).encode())


def config(field, fork):
    names = '{"Divergent"}' if fork == 2 else '{"Compatible","Frontier","Origin","Recovery"}'
    return """SPECIFICATION ExportSpec
CHECK_DEADLOCK FALSE
CONSTANTS
MaxHeight=3
MaxGeneration=1
MaxNonce=2
MaxTime=1
CheckCheckpoint=TRUE
CheckNonce=TRUE
CheckDeadline=TRUE
CheckProofGeneration=TRUE
CheckOriginBinding=TRUE
BoundaryMode=\"Full\"
CheckCutBinding=TRUE
KeepLandingIdentity=TRUE
KeepRecoveryIdentity=TRUE
IdentityDifference=\"%s\"
ForkHeight=%d
CaseNames=%s
INVARIANTS TypeOK IdentityTypeOK
""" % (field, fork, names)


def provenance(inputs):
    return {"base_sha256": digest(inputs[BASE]), "model_sha256": digest(inputs[MODEL]),
            "parser_source_sha256": digest(inputs[PARSER_SOURCE]),
            "wrapper_sha256": digest(WRAPPER.encode()), "tlc_sha256": TLC_SHA,
            "configs_sha256": {f+"/"+str(k): digest(config(f,k).encode()) for f in FIELDS for k in [1,2]}}


def parse_receipts(log, field, fork):
    if "Model checking completed. No error has been found." not in log or "0 states left on queue." not in log:
        raise ValueError("TLC did not exhaust")
    rows = {}
    for match in re.finditer(r'<<\s*"ETNA_IDENTITY"\s*,', log):
        row = ValueParser(log[match.start():]).value()
        if len(row) != 4 or row[0] != "ETNA_IDENTITY":
            raise ValueError("wrong receipt envelope")
        _, case, step, attempt = row
        if (case,step) in rows:
            raise ValueError("duplicate receipt")
        rows[case,step] = attempt
    names = ["Divergent"] if fork == 2 else ["Compatible","Frontier","Origin","Recovery"]
    cases = []
    for name in names:
        steps = []
        for step in range(LENGTHS[name]):
            if (name,step) not in rows:
                raise ValueError("missing receipt")
            steps.append(rows.pop((name,step)))
        cases.append(dict(id=field+"/"+name, field=field, kind=name, fork=fork, steps=steps))
    if rows:
        raise ValueError("unexpected receipts")
    return cases


def validate(data):
    if data.get("schema") != "etna-identity-replay-1" or data.get("grid") != 6:
        raise ValueError("wrong schema/grid")
    if data.get("content_sha256") != content_digest(data):
        raise ValueError("changed expectations")
    if data.get("provenance") != provenance({p: p.read_bytes() for p in [BASE,MODEL,PARSER_SOURCE]}):
        raise ValueError("wrong source/tool provenance")
    cases=data.get("cases",[])
    if len(cases)!=20 or {c["id"] for c in cases}!=REQUIRED:
        raise ValueError("missing/duplicate cases")
    for case in cases:
        if case["id"] != case["field"]+"/"+case["kind"] or len(case["steps"]) != LENGTHS[case["kind"]]:
            raise ValueError("wrong identity or skipped steps")
        if case["fork"] != (2 if case["kind"]=="Divergent" else 1):
            raise ValueError("wrong fork context")
        for step in case["steps"]:
            if set(step["cuts"]) != {"0","1","2","3"}:
                raise ValueError("missing supplied cuts")
            for side in ["before","after"]:
                if set(step[side]["records"]) != {"0","1","2","3"}:
                    raise ValueError("missing retained records")


def generate(java, jar):
    inputs={p:p.read_bytes() for p in [BASE,MODEL,PARSER_SOURCE]}
    if digest(Path(jar).read_bytes())!=TLC_SHA:
        raise ValueError("wrong TLC binary")
    cases=[]
    with tempfile.TemporaryDirectory(prefix="etna-identity-replay-") as directory:
        work=Path(directory)
        for source in [BASE,MODEL]:
            (work/source.name).write_bytes(inputs[source])
        (work/"EtnaIdentityExport.tla").write_text(WRAPPER)
        for field in FIELDS:
            for fork in [1,2]:
                (work/"Export.cfg").write_text(config(field,fork))
                result=subprocess.run([str(Path(java).resolve()),"-Xmx256m","-XX:+UseParallelGC","-cp",
                    str(Path(jar).resolve()),"tlc2.TLC","-workers","1","-seed","1","-config","Export.cfg",
                    "-metadir","states-"+field+str(fork),"EtnaIdentityExport"],cwd=work,
                    capture_output=True,text=True,timeout=45,env={"PATH":"/usr/bin:/bin","LANG":"C.UTF-8"})
                if result.returncode:
                    raise ValueError("TLC failed: "+result.stdout[-4000:]+result.stderr[-1000:])
                if any(p.read_bytes()!=value for p,value in inputs.items()) or digest(Path(jar).read_bytes())!=TLC_SHA:
                    raise ValueError("TLC inputs changed")
                cases.extend(parse_receipts(result.stdout,field,fork))
    data=dict(schema="etna-identity-replay-1",grid=6,provenance=provenance(inputs),cases=cases,
        boundaries=["Proof verifier is statement-bound mock", "Fresh execution genesis is model-only",
                    "Concrete ABI guard supplements are not exported symbolic cases"])
    data["content_sha256"]=content_digest(data)
    validate(data)
    return data


def compare_fixture(actual,current):
    validate(actual)
    validate(current)
    if actual!=current:
        raise ValueError("fixture differs from actual model execution")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java",required=True)
    parser.add_argument("--jar",required=True)
    parser.add_argument("--output",type=Path,default=ROOT/"identity_cases.json")
    parser.add_argument("--check",action="store_true")
    args=parser.parse_args()
    data=generate(args.java,args.jar)
    if args.check:
        compare_fixture(data,json.loads(args.output.read_text()))
    else:
        args.output.write_text(json.dumps(data,sort_keys=True,indent=2)+"\n")
    print("20 actual identity scenarios / 88 action observations")


if __name__=="__main__":
    main()
