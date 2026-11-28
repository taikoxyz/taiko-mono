#!/usr/bin/env python3
"""Export five actual M10 publication observations, without rebuilding transitions."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
MODEL = ROOT.parent / 'EtnaCheckpointImport.tla'
PARSER_SOURCE = ROOT / 'export_recovery.py'
PINS = ROOT / 'pins.json'
EXPORTER = Path(__file__).resolve()
INPUTS = (MODEL, PARSER_SOURCE, PINS, EXPORTER)
TLC_SHA = '936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88'
CASES = {'origin-base': (2, 0), 'origin-landed-alternate': (2, 11),
         'current-base': (4, 0), 'current-first-alternate': (4, 11),
         'current-second-alternate': (4, 20)}
ACTIONS = ('Check', 'Stage/el', 'Flush/el', 'Stage/app', 'Flush/app',
           'Stage/comet', 'Flush/comet', 'Stage/evidence', 'Flush/evidence', 'Publish')
STORES = ['app', 'comet', 'el', 'evidence']
BOUNDARIES = [
    'Symbolic commitments and selected window; valid STF/archive history is a premise',
    'Actual model publication, not a concrete importer, verified commit or signature',
    'Durable is the model marker, not a stock database power-loss guarantee',
]
LOADED_SOURCE_HASHES = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in (PARSER_SOURCE, EXPORTER)}
_spec = importlib.util.spec_from_file_location('etna_import_base_parser', PARSER_SOURCE)
_parser = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_parser)


class ImportValueParser(_parser.ValueParser):
    """Bounded M10 subset: inherited records/sequences plus signed ints/ranges/sets.

    Sets become arrays sorted by canonical JSON; sequence order is preserved.
    This deliberately does not implement a general TLA+ value parser.
    """
    token = re.compile(_parser.ValueParser.token.pattern.replace(
        '<<|>>', r'<<|>>|\.\.').replace(r'[\[\](),]', r'[\[\](),{}]').replace(r'\d+', r'-?\d+'))

    def value(self):
        token = self.peek()
        if token is not None and re.fullmatch(r'-?\d+', token):
            if len(token) > 12:
                raise ValueError('TLC integer exceeds receipt bounds')
            number = int(self.take())
            if self.peek() != '..':
                return number
            self.take('..')
            end = self.take()
            if not re.fullmatch(r'-?\d+', end) or len(end) > 12:
                raise ValueError('invalid TLC range bound')
            end = int(end)
            if abs(end - number) > 10000:
                raise ValueError('TLC range exceeds receipt bounds')
            return sorted(range(number, end + 1), key=canonical)
        if token == '{':
            self.take('{')
            items = {}
            if self.peek() != '}':
                while True:
                    value = self.value()
                    key = canonical(value)
                    if key in items:
                        raise ValueError('duplicate TLC set value')
                    items[key] = value
                    if len(items) > 10000:
                        raise ValueError('TLC set exceeds receipt bounds')
                    if self.peek() != ',':
                        break
                    self.take(',')
            self.take('}')
            return [items[key] for key in sorted(items)]
        return super().value()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def digest(value):
    return hashlib.sha256(value).hexdigest()


def content_digest(data):
    return digest(canonical({k: v for k, v in data.items() if k != 'content_sha256'}))


WRAPPER = r'''---------------- MODULE EtnaCheckpointImportExport ----------------
EXTENDS EtnaCheckpointImport, Sequences
CONSTANT CaseID
VARIABLES pc, attempts, initial
exportVars == <<vars, pc, attempts, initial>>
Observe == [phase |-> n.phase, event |-> event, published |-> n.published,
 staged |-> n.staged, durable |-> n.durable, trusted |-> n.trusted,
 connected |-> n.connected, hrs |-> n.hrs]
ActionName == CASE pc=0 -> "Check" [] pc=1 -> "Stage/el" [] pc=2 -> "Flush/el"
 [] pc=3 -> "Stage/app" [] pc=4 -> "Flush/app" [] pc=5 -> "Stage/comet"
 [] pc=6 -> "Flush/comet" [] pc=7 -> "Stage/evidence"
 [] pc=8 -> "Flush/evidence" [] OTHER -> "Publish"
BaseStep == CASE pc=0 -> Check [] pc=1 -> Stage("el") [] pc=2 -> Flush("el")
 [] pc=3 -> Stage("app") [] pc=4 -> Flush("app") [] pc=5 -> Stage("comet")
 [] pc=6 -> Flush("comet") [] pc=7 -> Stage("evidence")
 [] pc=8 -> Flush("evidence") [] pc=9 -> Publish [] OTHER -> FALSE
ExportInit == Init /\ pc=0 /\ attempts = <<>> /\ initial=Observe
Execute == /\ pc<10 /\ BaseStep /\ pc'=pc+1 /\ UNCHANGED initial
 /\ attempts'=Append(attempts,[ordinal |-> pc+1, action |-> ActionName,
     enabled |-> ENABLED BaseStep, before |-> Observe, after |-> Observe'])
Emit == /\ pc=10
 /\ PrintT(<<"ETNA_CHECKPOINT_IMPORT",CaseID,
  [raw |-> n.input, init |-> initial, steps |-> attempts,
   classification |-> seen.classification, publication |-> seen.publication,
   atPublication |-> [phase |-> n.phase, event |-> event, published |-> n.published,
    stores |-> n.stores, boundary |-> n.boundary, durable |-> n.durable,
    staged |-> n.staged, trusted |-> n.trusted, connected |-> n.connected,
    hrs |-> n.hrs], terminal |-> [pc |-> pc, actions |-> Len(attempts)]]>>)
 /\ pc'=11 /\ UNCHANGED <<vars,attempts,initial>>
ExportNext == Execute \/ Emit
ExportSpec == ExportInit /\ [][ExportNext]_exportVars
RequiredStepEnabled == pc<10 => ENABLED BaseStep
=============================================================================
'''


def config(case_id):
    height, raw = CASES[case_id]
    return '''SPECIFICATION ExportSpec
CHECK_DEADLOCK FALSE
CONSTANTS
ImportHeight=%d
TargetHeight=%d
RawCases={%d}
Mutant="None"
CaseID="%s"
INVARIANTS ImportTypeOK ClassificationCorrect PublishedStoresAligned PublicationDurable
 FixedGenesisPreserved TrustRequiresLatest NoImportAuthority ConnectedRequiresTrust
 SignerStatePreserved HaltSticky PositiveImportPremises RequiredStepEnabled
''' % (height, height, raw, case_id)


def read_inputs():
    inputs = {p: p.read_bytes() for p in INPUTS}
    for path, expected in LOADED_SOURCE_HASHES.items():
        if path in inputs and digest(inputs[path]) != expected:
            raise ValueError('loaded exporter/parser source changed')
    return inputs


def provenance(inputs):
    return {'sources_sha256': {p.name: digest(inputs[p]) for p in INPUTS},
            'spec': json.loads(inputs[PINS])['spec'], 'tlc_sha256': TLC_SHA,
            'wrapper_sha256': digest(WRAPPER.encode()),
            'configs_sha256': {name: digest(config(name).encode()) for name in CASES}}


def parse_receipts(log, case_id):
    if ('Model checking completed. No error has been found.' not in log
            or '0 states left on queue.' not in log or re.search(r'^Error:', log, re.M)):
        raise ValueError('TLC did not exhaust successfully')
    matches = list(re.finditer(r'<<\s*"ETNA_CHECKPOINT_IMPORT"\s*,', log))
    if len(matches) != 1 or log.count('"ETNA_CHECKPOINT_IMPORT"') != 1:
        raise ValueError('missing/duplicate publication receipt')
    parser = ImportValueParser(log[matches[0].start():])
    row = parser.value()
    if type(row) is not list or len(row) != 3 or row[:2] != ['ETNA_CHECKPOINT_IMPORT', case_id]:
        raise ValueError('wrong receipt envelope/identity')
    remainder = parser.text[parser.pos:]
    if not remainder.lstrip().startswith('Model checking completed. No error has been found.'):
        raise ValueError('trailing receipt tokens')
    if type(row[2]) is not dict:
        raise ValueError('wrong observation type')
    return row[2]


class Many:
    def __init__(self, member):
        self.member = member


class Either:
    def __init__(self, *choices):
        self.choices = choices


def shape(value, schema):
    """Exact JSON types and record fields; tuples describe ordered JSON arrays."""
    if isinstance(schema, Either):
        for option in schema.choices:
            try:
                shape(value, option)
                return
            except ValueError:
                pass
        raise ValueError('wrong observation variant')
    if isinstance(schema, Many):
        if type(value) is not list:
            raise ValueError('wrong observation array')
        for item in value:
            shape(item, schema.member)
    elif isinstance(schema, dict):
        if type(value) is not dict or set(value) != set(schema):
            raise ValueError('missing/unexpected observation fields')
        for key, item in schema.items():
            shape(value[key], item)
    elif isinstance(schema, tuple):
        if type(value) is not list or len(value) != len(schema):
            raise ValueError('wrong observation tuple')
        for item, expected in zip(value, schema):
            shape(item, expected)
    elif isinstance(schema, type):
        if type(value) is not schema:
            raise ValueError('wrong exact JSON type')
    elif type(value) is not type(schema) or value != schema:
        raise ValueError('wrong observation literal')


VECTOR = (int, int)
KP = (VECTOR, VECTOR)
VSET = dict(keys=VECTOR, powers=VECTOR, priorities=VECTOR, proposer=int)
PREIMAGE = dict(first=VSET, second=VSET)
EL = ('EL', int)
WINDOW = dict(ancestors=Many(int), evidence=Many(('Evidence', int)),
              validators=('WindowValidators', int), commits=('WindowCommits', int))
HEADER = dict(height=int, chain=('Chain', int), data=('Hash', dict(execution=EL)),
              next=('Validators', KP), appHash=EL, window=('Hash', WINDOW), time=int)
RAW = dict(l1=dict(height=int, generation=int, origin=int, originTime=int, recordGeneration=int,
                   finalized=bool, el=EL, state=('State', int), comet=('Hash', HEADER),
                   val=('Hash', PREIMAGE), fi=int, registry=('Hash', (KP, KP))),
           peer=dict(present=bool, header=HEADER, envelope=dict(execution=EL), el=EL,
                     state=('State', int), computedState=('State', int), preimage=PREIMAGE,
                     entries=(KP, KP), window=WINDOW, ancestors=Many(int), evidence=Many(('Evidence', int))))
STORE_SCHEMA = dict(
    el=dict(height=int, hash=EL, state=('State', int), ancestors=Many(int), fi=int),
    app=dict(height=int, appHash=EL, chain=('Chain', int), initialHeight=int, fi=int,
             active=KP, pending=KP, recorded=PREIMAGE),
    comet=dict(height=int, appHash=EL, chain=('Chain', int), initialHeight=int, validators=VSET,
               next=VSET, last=Either((), ('WindowValidators', int)), blockID=Either((), ('Hash', HEADER)),
               time=int, results=Either((), ('FixedExecTxResult',)), valChanged=int, paramsChanged=int),
    evidence=dict(markers=Many(('Evidence', int)), validators=Either((), ('WindowValidators', int)),
                  commits=Either((), ('WindowCommits', int))))
META = dict(phase=str, event=str, published=bool, staged=Many(str), durable=Many(str),
            trusted=bool, connected=bool, hrs=(int, int, int))
OBSERVATION = dict(raw=RAW, init=META,
                   steps=Many(dict(ordinal=int, action=str, enabled=bool, before=META, after=META)),
                   classification=dict(present=bool, input=RAW, result=str),
                   publication=dict(present=bool, input=RAW, stores=STORE_SCHEMA, durable=Many(str), crash=bool),
                   atPublication=dict(META, stores=STORE_SCHEMA, boundary=STORE_SCHEMA),
                   terminal=dict(pc=int, actions=int))


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def validate_observation(o, height):
    shape(o, OBSERVATION)
    raw = o['raw']
    publication = o['publication']
    actual = o['atPublication']
    require(raw['l1']['height'] == height, 'wrong raw import height')
    require(o['classification']['present'] and o['classification']['result'] == 'Verified', 'missing actual classification')
    require(canonical(o['classification']['input']) == canonical(raw), 'changed classified input')
    require(publication['present'] and not publication['crash'], 'missing actual publication')
    require(canonical(publication['input']) == canonical(raw), 'changed published input')
    require(publication['durable'] == STORES and actual['durable'] == STORES and actual['staged'] == STORES,
            'publication not fully durable/staged')
    require(canonical(actual['stores']) == canonical(publication['stores']) == canonical(actual['boundary']),
            'changed actual selected stores')
    require(actual['phase'] == 'Running' and actual['event'] == 'Published' and actual['published'], 'wrong publication boundary')
    require(not actual['trusted'] and not actual['connected'] and actual['hrs'] == [1, 9, 2], 'publication gained authority or reset signer HRS')
    require(o['terminal'] == {'pc': 10, 'actions': 10} and len(o['steps']) == 10, 'missing terminal actions')
    initial = o['init']
    require(initial['phase'] == 'Check' and initial['event'] == 'Init' and not initial['published']
            and initial['staged'] == [] and initial['durable'] == []
            and not initial['trusted'] and not initial['connected'] and initial['hrs'] == [1, 9, 2], 'wrong actual Init')
    previous = initial
    staged, durable = set(), set()
    for ordinal, (step, action) in enumerate(zip(o['steps'], ACTIONS), 1):
        require(step['ordinal'] == ordinal and step['action'] == action and step['enabled'], 'missing/disabled/reordered actual action')
        require(canonical(step['before']) == canonical(previous), 'disconnected action metadata')
        if action.startswith('Stage/'):
            staged.add(action.split('/')[1])
        if action.startswith('Flush/'):
            durable.add(action.split('/')[1])
        after = step['after']
        require(after['staged'] == sorted(staged) and after['durable'] == sorted(durable), 'wrong actual write/flush sequence')
        require(not after['trusted'] and not after['connected'] and after['hrs'] == [1, 9, 2], 'action gained authority or reset signer HRS')
        require(after['phase'] == ('Running' if action == 'Publish' else 'Verified'), 'wrong actual action phase')
        require(after['event'] == ('Classified' if action == 'Check' else 'Published' if action == 'Publish'
                                  else 'Staged' if action.startswith('Stage/') else 'Flushed'), 'wrong actual action event')
        require(after['published'] == (action == 'Publish'), 'wrong actual publication step')
        previous = after
    require(canonical(previous) == canonical({k: actual[k] for k in META}), 'wrong terminal metadata')


def validate(data):
    require(type(data) is dict and set(data) == {'schema', 'provenance', 'cases', 'boundaries', 'content_sha256'}, 'wrong outer fields')
    require(data['schema'] == 'etna-checkpoint-import-replay-1', 'wrong schema')
    require(data['content_sha256'] == content_digest(data), 'changed observations')
    require(canonical(data['provenance']) == canonical(provenance(read_inputs())), 'wrong source/tool provenance')
    require(canonical(data['boundaries']) == canonical(BOUNDARIES), 'changed boundaries')
    cases = data['cases']
    require(type(cases) is list and len(cases) == len(CASES), 'missing/duplicate cases')
    ids = []
    for case in cases:
        shape(case, dict(id=str, import_height=int, target_height=int, raw_case=int, observation=OBSERVATION))
        name = case['id']
        require(name in CASES and name not in ids, 'missing/duplicate/unexpected case')
        ids.append(name)
        height, raw = CASES[name]
        require((case['import_height'], case['target_height'], case['raw_case']) == (height, height, raw), 'wrong case context')
        validate_observation(case['observation'], height)
    require(set(ids) == set(CASES), 'missing/duplicate cases')


def copies_match(expected):
    try:
        return all(path.read_bytes() == value for path, value in expected.items())
    except OSError:
        return False


def generate(java, jar, log_dir=None):
    inputs = read_inputs()
    jar = Path(jar).resolve()
    require(digest(jar.read_bytes()) == TLC_SHA, 'wrong TLC binary')
    cases = []
    if log_dir is not None:
        Path(log_dir).mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='etna-checkpoint-import-') as directory:
        work = Path(directory)
        (work / MODEL.name).write_bytes(inputs[MODEL])
        (work / 'EtnaCheckpointImportExport.tla').write_text(WRAPPER)
        for name, (height, raw) in CASES.items():
            (work / 'Export.cfg').write_text(config(name))
            executed = {work / MODEL.name: inputs[MODEL],
                        work / 'EtnaCheckpointImportExport.tla': WRAPPER.encode(),
                        work / 'Export.cfg': config(name).encode()}
            require(copies_match(executed), 'TLC executed copies changed')
            result = subprocess.run([str(Path(java).resolve()), '-Xmx256m', '-XX:+UseParallelGC', '-cp', str(jar),
                                     'tlc2.TLC', '-workers', '1', '-seed', '1', '-config', 'Export.cfg',
                                     '-metadir', 'states-' + name, 'EtnaCheckpointImportExport'], cwd=work,
                                    capture_output=True, text=True, timeout=45,
                                    env={'PATH': '/usr/bin:/bin', 'LANG': 'C.UTF-8'})
            log = result.stdout + result.stderr
            if log_dir is not None:
                (Path(log_dir) / (name + '.log')).write_text(log)
            require(not any(p.read_bytes() != value for p, value in inputs.items())
                    and digest(jar.read_bytes()) == TLC_SHA, 'TLC inputs changed')
            require(copies_match(executed), 'TLC executed copies changed')
            require(result.returncode == 0, 'TLC failed: ' + log[-4000:])
            observation = parse_receipts(log, name)
            cases.append(dict(id=name, import_height=height, target_height=height, raw_case=raw, observation=observation))
    data = dict(schema='etna-checkpoint-import-replay-1', provenance=provenance(inputs), cases=cases, boundaries=BOUNDARIES)
    data['content_sha256'] = content_digest(data)
    validate(data)
    return data


def compare_fixture(actual, current):
    validate(actual)
    validate(current)
    require(canonical(actual) == canonical(current), 'fixture differs from actual model execution')


def load_fixture(path):
    """Read external receipt JSON without silently collapsing duplicate fields."""
    def unique_fields(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('duplicate JSON field: ' + key)
            result[key] = value
        return result
    return json.loads(Path(path).read_text(), object_pairs_hook=unique_fields)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--java', required=True)
    parser.add_argument('--jar', required=True)
    parser.add_argument('--output', type=Path, default=ROOT / 'checkpoint_import_cases.json')
    parser.add_argument('--log-dir', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = generate(args.java, args.jar, args.log_dir)
    if args.check:
        compare_fixture(data, load_fixture(args.output))
    else:
        args.output.write_text(json.dumps(data, sort_keys=True, indent=2) + '\n')
    print('5 actual checkpoint-import publications / 50 enabled base actions')


if __name__ == '__main__':
    main()
