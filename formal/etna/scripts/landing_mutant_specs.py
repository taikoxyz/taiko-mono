"""Closed, reviewed single-source mutations; no arbitrary dirty-source exception."""
import hashlib

INBOX = 'contracts/layer1/etna/impl/EtnaInbox.sol'
LIB = 'contracts/layer1/etna/libs/LibEtnaForcedInclusion.sol'
MUTANTS = {
 'recipient-omission': (INBOX, 'statement.feeRecipient = _input.feeRecipient;', 'statement.feeRecipient = address(0);', '306f49fcd5e6c42140216948cce8e98f95efa5ac811d75701097da08ab4ca4d3', '[FAIL: normal: real statement bytes:', 'LAND-03'),
 'head-tail-bound': (INBOX, 'headBefore <= headAfter && headAfter <= _forcedInclusionStorage.tail', 'headBefore <= headAfter', '9f66ca515b2c770cc55221ad3f9637825f18f61503b9b0b491c313038495f1e9', '[FAIL: successful head tail bound: 6 > 5]', 'LAND-01'),
 'fee-interval': (LIB, 'for (uint256 i = $.head; i < _newHead; ++i)', 'for (uint256 i = uint256($.head) + 1; i < _newHead; ++i)', '9c7e858ef73fc4481c6d723a06a30dd59b500b82cc954b0fd2ea9c6003a82f40', '[FAIL: actual consumed interval/fee:', 'LAND-02'),
 'verifier-bypass': (INBOX, '_proofVerifier.verifyProof(0, statementHash, _proof);', 'address(_proofVerifier).staticcall(abi.encodeCall(IProofVerifier.verifyProof, (uint256(0), statementHash, _proof)));', '6109fcde6c10211ae35b2fe1214f35c935e994252fa9a2bb107e0e6049152a1c', '[FAIL: successful land requires normal verifier return]', 'LAND-04'),
 'reward-commitment': (INBOX, 'rewardCommitments[id] = LibEtnaRewards.commitment(receipt);', 'rewardCommitments[id] = id;', 'b06b7954467d32e7735c6da7f1a9fbe7b7a874c10c760c8169a859545b242c51', '[FAIL: actual committed reward commitment:', 'LAND-09'),
 'reward-slot-check': (INBOX, '        require(rewardCommitments[id] == bytes32(0), RewardAlreadyRecorded());\n', '', '2b2abd2cd5c0ac885d8a061a8411e3314d543935849a81937207eb22017f6a9e', '[FAIL: successful land requires an empty reward slot:', 'LAND-10'),
 'snapshot-regress': (INBOX, '_input.activeCommitteeSnapshot >= _activeCommitteeSnapshot\n                && ', '', 'b8d44a7a9b5aba1fc434e39c9993a83c5239617e1ab047a5b06d2bbc715b9a7f', '[FAIL: successful land never regresses the committee snapshot:', 'LAND-12'),
 'snapshot-epoch-stability': (INBOX, '            require(\n                _input.activeCommitteeSnapshot == _activeCommitteeSnapshot,\n                InvalidCommitteeSnapshot()\n            );\n', '', 'd8a7be5655628c4a36eb7f56d741d4ee1cd9a65f655d5cac58799f55635a65b4', '[FAIL: successful same-epoch land keeps the committee snapshot:', 'LAND-12'),
 'snapshot-not-stored': (INBOX, '        _activeCommitteeSnapshot = _input.activeCommitteeSnapshot;\n', '', '22b4a0688e5a2f59419de8506efc6f223b730342f11c59061dfcbdd099e2930a', '[FAIL: actual committed committee snapshot:', 'LAND-12'),
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
