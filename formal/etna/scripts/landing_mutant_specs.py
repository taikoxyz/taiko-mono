"""Closed, reviewed single-source mutations; no arbitrary dirty-source exception."""
import hashlib

INBOX = 'contracts/layer1/etna/impl/EtnaInbox.sol'
LIB = 'contracts/layer1/etna/libs/LibEtnaForcedInclusion.sol'
MUTANTS = {
 'recipient-omission': (INBOX, 'statement.feeRecipient = _input.feeRecipient;', 'statement.feeRecipient = address(0);', 'ddb032033a2042a3c5ddc370f3b79d6b9cbd6f616dbb6e7fdc6d87db390f95df', '[FAIL: normal: real statement bytes:', 'LAND-03'),
 'head-tail-bound': (INBOX, 'headBefore <= headAfter && headAfter <= _forcedInclusionStorage.tail', 'headBefore <= headAfter', 'e3421169c715b3f218750b585d7d06211fb2c9a7eede95389c797270b90e2878', '[FAIL: successful head tail bound: 6 > 5]', 'LAND-01'),
 'fee-interval': (LIB, 'for (uint256 i = $.head; i < _newHead; ++i)', 'for (uint256 i = uint256($.head) + 1; i < _newHead; ++i)', '9c7e858ef73fc4481c6d723a06a30dd59b500b82cc954b0fd2ea9c6003a82f40', '[FAIL: actual consumed interval/fee:', 'LAND-02'),
 'verifier-bypass': (INBOX, '_proofVerifier.verifyProof(0, statementHash, _proof);', 'address(_proofVerifier).staticcall(abi.encodeCall(IProofVerifier.verifyProof, (uint256(0), statementHash, _proof)));', '0257a95b61c0e53af9710b816f13f7b628600a031c991a375e192b0ac725966b', '[FAIL: successful land requires normal verifier return]', 'LAND-04'),
 'reward-commitment': (INBOX, 'rewardCommitments[id] = LibEtnaRewards.commitment(receipt);', 'rewardCommitments[id] = id;', '0afc0f898e4eecfa74dfb517d4b4982172734730a6e4ebea2c3d56a3d969973d', '[FAIL: actual committed reward commitment:', 'LAND-09'),
 'reward-slot-check': (INBOX, '        require(rewardCommitments[id] == bytes32(0), RewardAlreadyRecorded());\n', '', 'a7e603defe91f8b07d4b73a3e4a88d7eb7fcd5e890a275504aea18376375121a', '[FAIL: successful land requires an empty reward slot:', 'LAND-10'),
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
