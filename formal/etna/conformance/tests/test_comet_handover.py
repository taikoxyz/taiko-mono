"""Fail closed on incomplete native handover evidence and diagnostic substitutions."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
PACKAGE='example.org/etna-comet-handover'
PARENT='TestWeightedHandover'
NAMES=('unchanged','unequal','add-remove','replacement','overlapping')

def event(action,identity=None,output=None):
    row=dict(Action=action,Package=PACKAGE)
    if identity is not None: row['Test']=identity
    if output is not None: row['Output']=output
    return row

def events(mode='normal'):
    literal=json.loads((ROOT/'comet_handover/literals.json').read_text())
    rows=[event('start'),event('run',PARENT),event('output',PARENT,'=== RUN   '+PARENT+'\n')]
    for name in NAMES:
        identity=PARENT+'/'+name
        # Early activation also advances unchanged priorities one step early.
        fail=mode!='normal'
        receipt=dict(name=name,transitions=6,inputUnchanged=True,observations=literal['observations'][mode][name])
        rows += [event('run',identity),event('output',identity,'=== RUN   '+identity+'\n'),event('output',identity,'    handover_test.go:100: receipt='+json.dumps(receipt,separators=(',',':'))+'\n')]
        if fail: rows.append(event('output',identity,'    handover_test.go:101: handover-observation-mismatch id='+name+'\n'))
        action='fail' if fail else 'pass'
        rows += [event('output',identity,'--- '+action.upper()+': '+identity+' (0.01s)\n'),event(action,identity)]
    action='pass' if mode=='normal' else 'fail'
    rows += [event('output',PARENT,'--- '+action.upper()+': '+PARENT+' (0.10s)\n'),event(action,PARENT),event('output',output=action.upper()+'\n'),event('output',output=('ok  \t' if action=='pass' else 'FAIL\t')+PACKAGE+'\t0.100s\n'),event(action)]
    return rows

def stream(rows): return '\n'.join(json.dumps(row) for row in rows).encode()

class HandoverCollectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path=ROOT/'run_comet_handover.py'
        cls.m=None
        if path.exists():
            spec=importlib.util.spec_from_file_location('handover_test_collector',path)
            cls.m=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.m)

    def setUp(self): self.assertIsNotNone(self.m,'handover collector not implemented')

    def test_complete_original_two_faults_and_restored(self):
        for mode in ('normal','omit-increment','early-activation'):
            self.assertEqual(len(self.m.require_go_outcomes(stream(events(mode)),int(mode!='normal'),mode)),5)

    def test_missing_duplicate_skipped_unknown_identity_or_package(self):
        base=events()
        variants=[[],base[1:],base+[base[3]],base[:3]+base[8:]]
        for field,value in [('Action','skip'),('Test','TestOther'),('Package','other')]:
            variant=copy.deepcopy(base);variant[3][field]=value;variants.append(variant)
        for variant in variants:
            with self.subTest(variant=variant[:4]),self.assertRaises(ValueError): self.m.require_go_outcomes(stream(variant),0,'normal')

    def test_missing_transition_terminal_and_wrong_full_row(self):
        for mutate in (lambda r:r['observations'].pop(),lambda r:r.update(transitions=5),lambda r:r.update(inputUnchanged=False),lambda r:r['observations'][1].update(changeHeight=12),lambda r:r['observations'][2]['next']['proposer'].update(priority=999)):
            rows=events();receipt=json.loads(rows[5]['Output'].split('receipt=')[1]);mutate(receipt)
            rows[5]['Output']='    handover_test.go:100: receipt='+json.dumps(receipt)+'\n'
            with self.assertRaises(ValueError): self.m.require_go_outcomes(stream(rows),0,'normal')

    def test_wrong_fault_diagnostics_and_normal_receipt_cannot_pass(self):
        rows=events('omit-increment')
        for mutate in (lambda r:r[6].update(Output='    handover_test.go:101: compilation failed\n'),lambda r:r[5].update(Output=events()[5]['Output']),lambda r:r.insert(6,event('output',PARENT+'/'+NAMES[0],'unexpected\n'))):
            variant=copy.deepcopy(rows);mutate(variant)
            with self.assertRaises(ValueError): self.m.require_go_outcomes(stream(variant),1,'omit-increment')

    def test_returncode_unknown_mode_duplicate_json_and_utf8(self):
        for raw,rc,mode in [(stream(events()),1,'normal'),(stream(events()),0,'other'),(b'{"Action":"start","Action":"pass"}',0,'normal'),(b'\xff',0,'normal')]:
            with self.assertRaises(ValueError): self.m.require_go_outcomes(raw,rc,mode)

    def test_stream_chunks_supported_but_extra_diagnostics_rejected(self):
        rows=events(); original=rows[5]; payload=original['Output'];rows[5:6]=[event('output',original['Test'],payload[:100]),event('output',original['Test'],payload[100:])]
        self.m.require_go_outcomes(stream(rows),0,'normal')
        rows.insert(5,event('output',original['Test'],'wrong diagnostic\n'))
        with self.assertRaises(ValueError): self.m.require_go_outcomes(stream(rows),0,'normal')

if __name__=='__main__': unittest.main()
