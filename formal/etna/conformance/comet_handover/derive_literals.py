"""Offline oracle derivation: elementary integer arithmetic and byte encoding only.

This script NEVER imports or runs Comet. It is not invoked by the native lane.
Freeze/review its JSON output before executing Go, rather than learning expectations
from production. Tiny positive powers keep protobuf varints one byte.
"""
import copy
import hashlib
import json
from pathlib import Path

PUBLIC = {
 'A': '5866666666666666666666666666666666666666666666666666666666666666',
 'B': '58666666666666666666666666666666666666666666666666666666666666e6',
 'C': 'c9a3f86aae465f0e56513864510f3997561fa2c9e85ea21dc2292309f3cd6022',
}
ADDRESS = {key: hashlib.sha256(bytes.fromhex(pub)).hexdigest()[:40] for key,pub in PUBLIC.items()}
PROGRAMS = {
 'unchanged': {},
 'unequal': {11: {'A':1,'B':3}},
 'add-remove': {11: {'B':0,'C':2}},
 'replacement': {11: {'A':0,'B':0,'C':4}},
 'overlapping': {11: {'A':1,'B':3},12: {'A':2,'B':1,'C':1}},
}

def canonical(values):
    return dict(sorted(values.items(),key=lambda pair:(-pair[1][0],ADDRESS[pair[0]])))

def center(values):
    if not values: return values
    total=sum(v[0] for v in values.values())
    spread=max(v[1] for v in values.values())-min(v[1] for v in values.values())
    divisor=(spread+2*total-1)//(2*total)
    if spread>2*total:
        # Go integer division truncates toward zero; subsequent average floors.
        values={k:[p,abs(q)//divisor * (-1 if q<0 else 1)] for k,(p,q) in values.items()}
    mean=sum(v[1] for v in values.values())//len(values)
    return {k:[p,q-mean] for k,(p,q) in values.items()}

def tick(values):
    values=center(values)
    sums={k:q+p for k,(p,q) in values.items()}
    selected=min(sums,key=lambda k:(-sums[k],ADDRESS[k]))
    total=sum(v[0] for v in values.values())
    return canonical({k:[p,sums[k]-(total if k==selected else 0)] for k,(p,q) in values.items()}),selected

def change(values,updates):
    total=sum(v[0] for v in values.values())+sum(p-values.get(k,[0,0])[0] for k,p in updates.items() if p)
    newcomer=-(total+total//8)
    values=copy.deepcopy(values)
    for k,p in updates.items():
        if p: values[k]=[p,values.get(k,[0,newcomer])[1]]
        else: del values[k]
    return canonical(center(values))

def merkle(blobs):
    if not blobs: return hashlib.sha256(b'').digest()
    if len(blobs)==1: return hashlib.sha256(b'\x00'+blobs[0]).digest()
    n=1<<((len(blobs)-1).bit_length()-1)
    return hashlib.sha256(b'\x01'+merkle(blobs[:n])+merkle(blobs[n:])).digest()

def set_hash(values):
    return merkle([b'\x0a\x22\x0a\x20'+bytes.fromhex(PUBLIC[k])+b'\x10'+bytes([p]) for k,(p,q) in values.items()]).hex()

def member(k,pq):
    return dict(identity=k,public=PUBLIC[k],address=ADDRESS[k],power=pq[0],priority=pq[1])

def view(values,proposer):
    return dict(members=[member(k,v) for k,v in values.items()],proposer=None if proposer is None else member(proposer,values[proposer]))

def rows(name,mode):
    current,cp=tick({'A':[3,0],'B':[1,0]})
    nxt,np=tick(current)
    last,lp={},None
    change_height=11
    out=[]
    def row(height):
        return dict(height=height,initialHeight=11,changeHeight=change_height,last=view(last,lp),current=view(current,cp),next=view(nxt,np),
                    headerHeight=11 if height==0 else height+1,validatorsHash=set_hash(current),nextValidatorsHash=set_hash(nxt))
    out.append(row(0))
    for height in range(11,17):
        updated=copy.deepcopy(nxt)
        if height in PROGRAMS[name]:
            updated=change(updated,PROGRAMS[name][height]);change_height=height+2
        if mode!='omit-increment': updated,up=tick(updated)
        else:
            # This faulty copy retains its old proposer POINTER even across updates.
            up=np
        old_next=copy.deepcopy(nxt)
        last,lp=current,cp
        current,cp=(updated,up) if mode=='early-activation' else (old_next,np)
        if mode=='omit-increment':
            # In this fault only: UpdateWithChangeSet retains a possibly removed,
            # stale proposer object. Preserve that separate object in raw views.
            old_proposer=out[-1]['next']['proposer']
        nxt,np=copy.deepcopy(updated),up
        if mode=='omit-increment':
            # Avoid view() indexing a removed proposer; build complete views below.
            def faulty_view(vals,prop):
                return dict(members=[member(k,v) for k,v in vals.items()],proposer=copy.deepcopy(prop))
            prev=out[-1]
            out.append(dict(height=height,initialHeight=11,changeHeight=change_height,last=copy.deepcopy(prev['current']),current=copy.deepcopy(prev['next']),next=faulty_view(nxt,old_proposer),headerHeight=height+1,validatorsHash=set_hash(old_next),nextValidatorsHash=set_hash(nxt)))
        else: out.append(row(height))
    return out

if __name__=='__main__':
    result=dict(schema='etna-comet-handover-literals-1',sourceCommit='0880b4d378f347ab16e54ec677ff50d803f37d62',public=PUBLIC,addresses=ADDRESS,
                programs={name:[dict(height=h,updates=u) for h,u in updates.items()] for name,updates in PROGRAMS.items()},
                observations={mode:{name:rows(name,mode) for name in PROGRAMS} for mode in ('normal','omit-increment','early-activation')})
    Path(__file__).with_name('literals.json').write_text(json.dumps(result,indent=2)+'\n')
