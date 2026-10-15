#!/usr/bin/env python3
"""Bind current verification sources and immutable client/protocol dependencies."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]
CLIENT='2af0f30485b9990eae87074037bede11c59e8883'
PROTOCOL='27777e9d7147e7b1d3543711f4d7370a0377fa53'
PROJECT='taikoxyz/taiko-mono'

def run(args,cwd=REPO):
    return subprocess.check_output(args,cwd=cwd,text=True).strip()

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def current_heads():
    return {key:json.loads(run(['gh','api',f'repos/{PROJECT}/pulls/{number}']))['head']['sha']
            for key,number in [('upstream_client',22280),('paired_protocol',22286)]}

def validate_heads(heads):
    if heads != {'upstream_client':CLIENT,'paired_protocol':PROTOCOL}:
        raise ValueError('paired PR head advanced; refresh reviewed pins and rerun')

def event_head():
    event=json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text()) if os.environ.get('GITHUB_EVENT_PATH') else {}
    return event.get('pull_request',{}).get('head',{}).get('sha',os.environ.get('GITHUB_SHA',run(['git','rev-parse','HEAD'])))

def verify_event(expected):
    if run(['git','rev-parse','HEAD']) != expected:
        raise ValueError('verification checkout is not event head')
    event=json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text()) if os.environ.get('GITHUB_EVENT_PATH') else {}
    if 'pull_request' in event:
        actual=json.loads(run(['gh','api',f"repos/{PROJECT}/pulls/{event['pull_request']['number']}"]))['head']['sha']
        if actual != expected:
            raise ValueError('verification PR advanced; rerun at new head')
    elif os.environ.get('GITHUB_EVENT_NAME') in {'push','schedule','workflow_dispatch'}:
        ref=os.environ['GITHUB_REF']
        if ref.startswith('refs/heads/'):
            actual=run(['git','ls-remote','https://github.com/'+PROJECT+'.git',ref]).split()[0]
            if actual != expected:
                raise ValueError('verification branch advanced; rerun at new head')

def tree(repo,scope):
    entries=run(['git','ls-files','--stage','-z','--',*scope],repo).split('\0')
    result={}
    for entry in entries:
        if not entry: continue
        metadata,name=entry.split('\t',1)
        mode,_,stage=metadata.split()
        path=repo/name
        if stage != '0' or mode not in {'100644','100755','120000'}:
            raise ValueError('unsupported/conflicted owned input: '+name)
        if mode == '120000':
            if not path.is_symlink(): raise ValueError('owned symlink replaced: '+name)
            digest=hashlib.sha256(os.readlink(path).encode()).hexdigest()
        else:
            if path.is_symlink() or not path.is_file(): raise ValueError('owned source replaced: '+name)
            if bool(path.stat().st_mode & 0o111) != (mode=='100755'):
                raise ValueError('owned source mode changed: '+name)
            digest=sha(path)
        result[name]={'sha256':digest,'mode':mode}
    return result

def merge_ownership(verification,protocol):
    combined=dict(verification)
    for name,digest in protocol.items():
        if name in combined and combined[name] != digest:
            raise ValueError('unexpected divergent ownership conflict: '+name)
        combined[name]=digest
    return combined

def snapshot(protocol,verification_sha):
    subprocess.run(['git','merge-base','--is-ancestor',CLIENT,verification_sha],cwd=REPO,check=True)
    if run(['git','rev-parse','HEAD'],protocol) != PROTOCOL:
        raise ValueError('protocol checkout does not match pin')
    subprocess.run(['git','diff','--quiet','HEAD','--','formal/etna','packages/taiko-client-rs','testdata/etna_vectors','.github/workflows/etna--formal.yml'],cwd=REPO,check=True)
    subprocess.run(['git','diff','--quiet','HEAD','--','packages/protocol','package.json','pnpm-lock.yaml','pnpm-workspace.yaml','testdata/etna_vectors'],cwd=protocol,check=True)
    # Keep its Git HEAD intact for strict source/fixture/compiler authentication.
    # F/C/I come from the event; P and its complete build context come from PIN.
    verification=tree(REPO,['formal/etna','packages/taiko-client-rs','testdata/etna_vectors','.github/workflows/etna--formal.yml'])
    dependency=tree(protocol,['packages/protocol','package.json','pnpm-lock.yaml','pnpm-workspace.yaml','testdata/etna_vectors'])
    combined=merge_ownership(verification,dependency)
    return {'schema_version':1,'verification_sha':verification_sha,'upstream_client':CLIENT,
            'paired_protocol':PROTOCOL,'verification_files':verification,'protocol_files':dependency,
            'assembled_sha256':hashlib.sha256(json.dumps(combined,sort_keys=True).encode()).hexdigest()}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--protocol',type=Path,required=True,help='immutable repository checkout root')
    p.add_argument('--report',type=Path,required=True)
    p.add_argument('--finish',action='store_true')
    a=p.parse_args()
    validate_heads(current_heads())
    revision=event_head()
    verify_event(revision)
    if not re.fullmatch('[a-f0-9]{40}',revision): raise ValueError('immutable verification SHA required')
    if not a.protocol.exists():
        if a.finish: raise ValueError('protocol checkout missing at finish')
        subprocess.run(['git','clone','--no-checkout','https://github.com/'+PROJECT+'.git',str(a.protocol)],check=True)
        subprocess.run(['git','checkout','--detach',PROTOCOL],cwd=a.protocol,check=True)
    report=snapshot(a.protocol,revision)
    if a.finish:
        if json.loads(a.report.read_text()) != report:
            raise ValueError('source/tool/compiler/manifest bytes changed during paired verification')
    else:
        a.report.parent.mkdir(parents=True,exist_ok=True)
        a.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if not k.endswith('_files')},indent=2))

if __name__=='__main__': main()
