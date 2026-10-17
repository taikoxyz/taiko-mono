#!/usr/bin/env python3
"""Run the actual L2FeeVault mutants; authenticate narrow exceptions and restore artifacts."""
import argparse
import json
from pathlib import Path
from claim_conformance import compare, solidity
from claim_mutant_specs import MUTANTS, expected_bytes, semantic_kill
from landing_conformance import ROOT, PIN, pinned_inputs, load, exact_ids, digest

CORPUS = ROOT/'corpus/claim.jsonl'


def baseline(protocol, output):
    corpus = load(CORPUS)
    code, _, rows = solidity(protocol, corpus, output)
    if code:
        raise RuntimeError('baseline actual harness failed; see '+str(output.with_suffix('.log')))
    exact_ids(rows, 'actual baseline', exact_ids(corpus, 'corpus'))
    if compare(corpus, rows)['failures']:
        raise ValueError('baseline differs from Lean')
    from check_coverage import check_contract_artifacts
    check_contract_artifacts(protocol, json.loads((ROOT/'coverage.json').read_text())['contract_artifacts'])


def execute(protocol, output):
    protocol = protocol.resolve()
    output.mkdir(parents=True, exist_ok=False)
    pinned_inputs(protocol)
    baseline(protocol, output/'baseline.jsonl')
    corpus = load(CORPUS)
    records = []
    try:
        for name, (relative, _, _, _, kind, marker, obligation) in MUTANTS.items():
            target = protocol/relative
            original = target.read_bytes()
            pinned_inputs(protocol)
            record = {'mutation':name,'obligation':obligation,'kill':kind,'expected_failure':marker}
            records.append(record)
            try:
                target.write_bytes(expected_bytes(name, original))
                pinned_inputs(protocol, name)
                code, log, rows = solidity(protocol, corpus, output/(name+'.jsonl'), name)
                failures = None
                if kind == 'lean':
                    failures = compare(corpus, rows)['failures']
                    record['lean_failures'] = failures
                record.update(exit=code, source_sha256=digest(target),
                              log_sha256=digest(output/(name+'.log')))
                record['outcome'] = ('semantic-kill' if semantic_kill(name, code, log, failures)
                                     else 'survivor-or-infrastructure-failure')
                if record['outcome'] != 'semantic-kill':
                    raise RuntimeError('mutant did not reach required semantic failure: '+name)
            finally:
                target.write_bytes(original)
                pinned_inputs(protocol)
                record['source_restored'] = target.read_bytes() == original
    finally:
        # A mutant must not leave its compiled executable in the canonical artifact tree.
        pinned_inputs(protocol)
        artifacts_restored = False
        try:
            baseline(protocol, output/'restored.jsonl')
            artifacts_restored = True
        finally:
            (output/'mutations.json').write_text(json.dumps({'protocol':PIN,'mutations':records,
                'canonical_artifacts_restored':artifacts_restored},indent=2)+'\n')
    return records

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--protocol',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True,help='fresh directory, never overwrite prior attempts')
    a=p.parse_args()
    print(json.dumps(execute(a.protocol,a.output),indent=2))
