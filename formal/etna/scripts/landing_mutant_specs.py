"""Closed, reviewed single-source mutations; no arbitrary dirty-source exception."""
import hashlib

INBOX = 'contracts/layer1/etna/impl/EtnaInbox.sol'
LIB = 'contracts/layer1/etna/libs/LibEtnaForcedInclusion.sol'
MUTANTS = {
 'recipient-omission': (INBOX, 'statement.feeRecipient = _input.feeRecipient;', 'statement.feeRecipient = address(0);', 'a95150b4a46d568019ec60f54685458a97befb65db3d0341e44a77d4b578236f', '[FAIL: normal: real statement bytes:', 'LAND-03'),
 'head-tail-bound': (INBOX, 'headBefore <= headAfter && headAfter <= _forcedInclusionStorage.tail', 'headBefore <= headAfter', '8daa12892c246aa24446a07ef179f260d27818742d0ce68ea95a9170bd2e2c0d', '[FAIL: successful head tail bound: 6 > 5]', 'LAND-01'),
 'fee-interval': (LIB, 'for (uint256 i = $.head; i < _newHead; ++i)', 'for (uint256 i = uint256($.head) + 1; i < _newHead; ++i)', '9c7e858ef73fc4481c6d723a06a30dd59b500b82cc954b0fd2ea9c6003a82f40', '[FAIL: actual consumed interval/fee:', 'LAND-02'),
 'verifier-bypass': (INBOX, '_proofVerifier.verifyProof(0, statementHash, _proof);', 'address(_proofVerifier).staticcall(abi.encodeCall(IProofVerifier.verifyProof, (uint256(0), statementHash, _proof)));', '8b50cf56b0cc4b246d66af360c1813be6201366a9c108a957c89cd16cf6bd420', '[FAIL: successful land requires normal verifier return]', 'LAND-04'),
}

def expected_bytes(name, original):
    if name not in MUTANTS:
        raise ValueError('unknown expected mutant')
    _, old, new, digest, _, _ = MUTANTS[name]
    if original.count(old.encode()) != 1:
        raise ValueError('mutant patch must match exactly once')
    result = original.replace(old.encode(), new.encode())
    if hashlib.sha256(result).hexdigest() != digest:
        raise ValueError('mutant does not match reviewed complete-file digest')
    return result

def semantic_kill(name, code, log):
    marker = MUTANTS[name][4]
    return (code > 0 and marker in log and 'test_land_LeanCorpus()' in log
            and 'Suite result: FAILED' in log and '1 failed' in log
            and not any(x in log for x in ['Compiler run failed', 'No tests found', 'MemoryOOG']))
