#!/usr/bin/env python3
"""Run the six actual Solidity mutants; authenticate narrow exceptions and restore artifacts."""
import argparse
import json
import os
from pathlib import Path
import subprocess
from landing_conformance import ROOT, PIN, pinned_inputs, staged, solidity, load, exact_ids, digest
from landing_mutant_specs import MUTANTS, expected_bytes, semantic_kill


def baseline(protocol, output):
    rows = solidity(protocol, load(ROOT/'corpus/landing.jsonl'), output)
    exact_ids(rows, 'actual baseline', exact_ids(load(ROOT/'corpus/landing.jsonl'), 'corpus'))
    if len(rows) != 65 or sum('actualPreimage' in r for r in rows) != 36:
        raise ValueError('baseline did not execute all 65 cases / 36 preimages')
    from check_coverage import build_paired_artifacts, check_contract_artifacts
    build_paired_artifacts(protocol)
    check_contract_artifacts(protocol, json.loads((ROOT/'coverage.json').read_text())['contract_artifacts'])


def execute(protocol, output):
    protocol = protocol.resolve()
    output.mkdir(parents=True, exist_ok=False)
    pinned_inputs(protocol)
    baseline(protocol, output/'baseline.jsonl')
    records=[]
    try:
        for name, (relative, _, _, _, marker, obligation) in MUTANTS.items():
            target = protocol/relative
            original = target.read_bytes()
            pinned_inputs(protocol)
            record = {'mutation':name,'obligation':obligation,'expected_failure':marker}
            records.append(record)
            try:
                target.write_bytes(expected_bytes(name, original))
                pinned_inputs(protocol, name)
                with staged(protocol, load(ROOT/'corpus/landing.jsonl'), name) as corpus:
                    command=['forge','test','--no-cache','--extra-output','storageLayout','--match-path',
                        'test/layer1/etna/EtnaInboxLeanConformance.t.sol',
                        '--match-test','test_land_LeanCorpus','-vvv']
                    env=os.environ | {'FOUNDRY_PROFILE':'layer1','ETNA_LANDING_CORPUS':str(corpus)}
                    result=subprocess.run(command,cwd=protocol,env=env,text=True,capture_output=True)
                    log=result.stdout+result.stderr
                    (output/(name+'.log')).write_text(log)
                    record.update(command=command,exit=result.returncode,source_sha256=digest(target),
                                  log_sha256=digest(output/(name+'.log')))
                    record['outcome']='semantic-kill' if semantic_kill(name,result.returncode,log) else 'survivor-or-infrastructure-failure'
                    if record['outcome'] != 'semantic-kill':
                        raise RuntimeError('mutant did not reach required semantic assertion: '+name)
            finally:
                target.write_bytes(original)
                pinned_inputs(protocol)
                record['source_restored']=target.read_bytes()==original
    finally:
        # A failed mutant must not leave its compiled executable in the canonical cache.
        pinned_inputs(protocol)
        artifacts_restored=False
        try:
            baseline(protocol, output/'restored.jsonl')
            artifacts_restored=True
        finally:
            (output/'mutations.json').write_text(json.dumps({'protocol':PIN,'mutations':records,'canonical_artifacts_restored':artifacts_restored},indent=2)+'\n')
    return records

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--protocol',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True,help='fresh directory, never overwrite prior attempts')
    a=p.parse_args()
    print(json.dumps(execute(a.protocol,a.output),indent=2))
