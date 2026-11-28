"""Verify one reviewed exact-byte workspace SPEC correspondence.

Historical source and vector pins remain independently enforced by run_baseline.
This checked-in metadata records review, not normalization or a proof of semantics.
"""
import hashlib
import json
from pathlib import Path
import re


def load_spec_correspondence(path):
    """Read reviewed metadata without silently accepting duplicate JSON keys."""
    def unique(pairs):
        result = {}
        for name, value in pairs:
            if name in result:
                raise ValueError('duplicate SPEC correspondence key: ' + name)
            result[name] = value
        return result
    return json.loads(Path(path).read_text(), object_pairs_hook=unique)


def verify_workspace_spec(raw, authority, ledger):
    """Bind exact workspace bytes to canonical or one explicitly reviewed revision.

    The checked-in ledger records a separate source review; it does not establish
    compatibility by normalization or change any historical consumer source pin.
    """
    fields = {'schema', 'path', 'authority', 'reviewedWorkspace', 'classification', 'rationale'}
    if not isinstance(ledger, dict) or set(ledger) != fields:
        raise ValueError('invalid SPEC correspondence fields')
    if (ledger['schema'] != 'etna-spec-correspondence-1'
            or ledger['path'] != 'packages/protocol/docs/etna/SPEC.md'
            or ledger['classification'] != 'reviewed-scoped-correspondence'
            or not isinstance(ledger['rationale'], str) or not ledger['rationale'].strip()):
        raise ValueError('invalid SPEC correspondence metadata')
    for identity in (authority, ledger['authority'], ledger['reviewedWorkspace']):
        if not isinstance(identity, dict) or set(identity) != {'commit', 'blob', 'sha256'}:
            raise ValueError('invalid SPEC source identity fields')
        for name, size in (('commit', 40), ('blob', 40), ('sha256', 64)):
            if not isinstance(identity[name], str) or not re.fullmatch('[0-9a-f]{' + str(size) + '}', identity[name]):
                raise ValueError('invalid SPEC source identity hash')
    if ledger['authority'] != authority:
        raise ValueError('SPEC correspondence authority differs from historical pin')
    reviewed = ledger['reviewedWorkspace']
    if any(reviewed[name] == authority[name] for name in ('commit', 'blob', 'sha256')):
        raise ValueError('reviewed SPEC revision must be distinct from authority')
    if not isinstance(raw, bytes):
        raise ValueError('SPEC input must be raw bytes')
    actual = {'sha256': hashlib.sha256(raw).hexdigest(),
              'blob': hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()}
    for relation, expected in (('canonical', authority), ('reviewed-scoped', reviewed)):
        if all(actual[name] == expected[name] for name in actual):
            return {'status': 'SPEC_CORRESPONDENCE_VERIFIED', 'relation': relation,
                    'authorityCommit': authority['commit'], 'workspace': actual}
    raise ValueError('workspace SPEC bytes have no reviewed correspondence')
