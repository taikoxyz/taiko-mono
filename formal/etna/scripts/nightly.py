#!/usr/bin/env python3
"""Execute extra seeds, longer native crashes and all domain mutants, never old JSON."""
import argparse
import json
import os
from pathlib import Path
import subprocess
from prepare_pair import ROOT,REPO
from run_conformance import execute


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--domain',choices=['fi','committee','landing','traces'],required=True)
    p.add_argument('--protocol',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args(); a.output.mkdir(parents=True,exist_ok=False)
    records=[]
    obligations={
        'due-strict':'FI-01','unfinished-consumes':'FI-06','error-as-empty':'FI-06',
        'hot-consumption-removed':'FI-08','cold-consumption-removed':'FI-08',
        'activation-early':'COM-03','activation-late':'COM-03','quorum-inclusive':'COM-04',
        'candidate-anchor':'COM-02','drop-pending-insertion':'COM-06',
        'committee-size-cap-relaxed':'COM-rust_committee_size_refines',
        'positive-cap-inclusive':'COM-rust_positive_cap_refines',
        'first-height-range-bypass':'COM-validate_first_ranges',
        'first-anchor-range-bypass':'COM-validate_first_ranges',
        'anchor-overflow-admitted':'COM-rust_anchor_progress_refines',
        'urgency-overflow-true':'COM-rust_force_epoch_refines',
    }
    expected_mutants={'fi':5,'committee':11}
    if a.domain in {'fi','committee'}:
        execute(['python3',str(ROOT/'scripts'/f'{a.domain}_mutations.py'),'--group','all','--output',str(a.output/'mutations')],a.output/'mutations.log',env=os.environ | {'RUSTUP_TOOLCHAIN':'1.95'})
        data=json.loads((a.output/'mutations/all.json').read_text())
        for mutation in data['mutations']:
            name=mutation['mutation']
            logs=list((a.output/'mutations'/name).glob('*.log'))
            if (a.output/'mutations'/(name+'.log')).exists():
                logs.append(a.output/'mutations'/(name+'.log'))
            reasons=[line for log in logs for line in log.read_text().splitlines()
                     if any(marker in line for marker in ['corpus mismatch','error:','panicked','FAILED'])]
            if not reasons: raise ValueError('mutant lacks actual failure diagnostics: '+name)
            records.append(mutation | {'obligation':obligations[name],'actual_failure_reasons':reasons[:30]})
        if len(records)!=expected_mutants[a.domain]: raise ValueError('incomplete domain mutation execution')
        # Restore and compile/audit canonical modules again after mutant oleans.
        execute(['python3',str(ROOT/'scripts/audit_proofs.py')],a.output/'restored-audit.log')
    elif a.domain=='landing':
        execute(['python3',str(ROOT/'scripts/landing_mutations.py'),'--protocol',str(a.protocol),'--output',str(a.output/'mutations')],a.output/'mutations.log')
        execute(['python3',str(ROOT/'scripts/claim_mutations.py'),'--protocol',str(a.protocol),'--output',str(a.output/'claim-mutations')],a.output/'claim-mutations.log')
    else:
        for seed,epochs in [(20261016,12),(20261017,24),(20261018,48)]:
            execute(['python3',str(ROOT/'scripts/run_conformance.py'),'--scope','paired','--seed',str(seed),
                     '--protocol',str(a.protocol),'--output',str(a.output/f'seed-{seed}')],a.output/f'conformance-{seed}.log')
            execute(['cargo','+1.95','test','--locked','-p','abci','--lib',
                     'app::tests::finalize::switch_replay_survives_crashes_before_and_after_commit',
                     '--','--exact','--nocapture'],a.output/f'trace-{epochs}.log',
                     cwd=REPO/'packages/taiko-client-rs',env=os.environ|{'ETNA_TRACE_EPOCHS':str(epochs)})
            log=(a.output/f'trace-{epochs}.log').read_text()
            marker=f'ETNA_TRACE epochs={epochs} heights={epochs*4+2} switches={epochs} crashes={epochs*2}'
            if marker not in log or '1 passed' not in log: raise ValueError('extended native trace did not execute')
    (a.output/'nightly.json').write_text(json.dumps({'domain':a.domain,'fresh_execution':True,'success':True,'mutations':records})+'\n')

if __name__=='__main__': main()
