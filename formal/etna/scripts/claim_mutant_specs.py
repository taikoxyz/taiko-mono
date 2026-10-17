"""Closed, reviewed single-source L2FeeVault mutations; no arbitrary dirty-source exception.

`assert` mutants must fail the actual harness's own input-derived business assertion;
`lean` mutants keep the harness green and must be caught by the Lean comparison at an exact
(case, field). Names are disjoint from the landing mutants.
"""
import hashlib

VAULT = 'contracts/layer2/core/L2FeeVault.sol'
MUTANTS = {
 'claim-flag-dropped': (VAULT, '        claimed[id] = true;\n', '', 'af32e07e356bfe723b437a144afc5b88993fa56e2700be18d7de9de182901b4a', 'assert', '[FAIL: successful claim marks its batch', 'CLAIM-02'),
 'empty-account-check': (VAULT, '        require(_accountProof.length != 0, EmptyAccountProof());\n', '', '355dbc143da627ddd1408ae39f858d476b3d4fc274d2ea474dbeeecda5ff1aa5', 'assert', '[FAIL: successful claim requires a nonempty account proof', 'CLAIM-01'),
 'reentrancy-guard': (VAULT, '        _entered = true;\n', '', '954bf584eb70eef8885727bc084f45e8fad2fc1e537f2d3cbeff600b149583dc', 'assert', '[FAIL: nested claim hits the guard', 'CLAIM-01'),
 'receipt-l2-chain': (VAULT, '_receipt.l2ChainId == block.chainid\n                && _receipt.inbox == l1Inbox', '_receipt.inbox == l1Inbox', '4dcbda2e3dc811565dba3110d83819d73e5cb1a2a0810cf7839038c45542a770', 'assert', '[FAIL: successful claim requires the configured receipt identity', 'CLAIM-01'),
 'zero-root-accepted': (VAULT, '        require(root != bytes32(0), InvalidAnchorRoot());\n', '', 'f2f596dd0efe4feb61670f5974cffbac11dd6f84464bf7d270cd438f56b43dee', 'lean', 'root-zero:error', 'CLAIM-01'),
 'zero-amount-call': (VAULT, '        if (_receipt.baseFeeAmount != 0) {', '        {', '84be7e75e79970f1356855b2b18068ddfe419a71361970b05ca7f08c7f103f0e', 'assert', '[FAIL: one recipient call, none for a zero amount', 'CLAIM-AUX-04'),
}


def expected_bytes(name, original):
    if name not in MUTANTS:
        raise ValueError('unknown expected mutant')
    _, old, new, digest, _, _, _ = MUTANTS[name]
    if original.count(old.encode()) != 1:
        raise ValueError('mutant patch must match exactly once')
    result = original.replace(old.encode(), new.encode())
    if hashlib.sha256(result).hexdigest() != digest:
        raise ValueError('mutant does not match reviewed complete-file digest')
    return result


def semantic_kill(name, code, log, failures=None):
    """An `assert` kill is the named Foundry assertion; a `lean` kill is a green harness whose
    complete observations differ from Lean at exactly the reviewed (case, field)."""
    _, _, _, _, kind, marker, _ = MUTANTS[name]
    clean = not any(x in log for x in ['Compiler run failed', 'No tests found', 'MemoryOOG'])
    if kind == 'assert':
        return (code > 0 and marker in log and 'test_claim_LeanCorpus()' in log
                and 'Suite result: FAILED' in log and '1 failed' in log and clean)
    case, field = marker.split(':')
    return (code == 0 and clean and 'Suite result: ok' in log and failures is not None
            and {'id':case, 'field':field} in [{'id':f['id'], 'field':f['field']} for f in failures])
