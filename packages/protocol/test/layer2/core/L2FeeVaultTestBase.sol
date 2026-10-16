// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { RLPWriter } from "@optimism/packages/contracts-bedrock/src/libraries/rlp/RLPWriter.sol";
import { Test } from "forge-std/src/Test.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";
import { LibEtnaRewards } from "src/shared/libs/LibEtnaRewards.sol";
import { EtnaRewardProof } from "test/shared/EtnaRewardProof.sol";

// The only modeled external boundary is the trusted EIP-4788 system roots source.
contract MockEtnaRoots {
    mapping(uint256 timestamp => bytes32 root) private _roots;

    function setRoot(uint256 _timestamp, bytes32 _root) external {
        _roots[_timestamp] = _root;
    }

    fallback(bytes calldata _input) external returns (bytes memory output_) {
        return abi.encode(_roots[abi.decode(_input, (uint256))]);
    }
}

library EtnaVaultProof {
    struct Proof {
        bytes32 root;
        bytes[] account;
        bytes[] storageProof;
    }

    // Independent receipt encoding oracle: intentionally does not call LibEtnaRewards helpers.
    function batchId(LibEtnaRewards.Receipt memory _r) internal pure returns (bytes32 id_) {
        return keccak256(
            abi.encode(
                bytes32("ETNA_L2_REWARD_BATCH_V1"),
                _r.l1ChainId,
                _r.l2ChainId,
                _r.inbox,
                _r.generation,
                _r.parentHeight,
                _r.parentHash,
                _r.lastHeight,
                _r.lastBlockHash
            )
        );
    }

    function commitment(LibEtnaRewards.Receipt memory _r) internal pure returns (bytes32 value_) {
        return keccak256(
            abi.encode(
                bytes32("ETNA_L2_REWARD_RECEIPT_V1"),
                batchId(_r),
                _r.l2RewardRecipient,
                _r.baseFeeAmount
            )
        );
    }

    function proof(LibEtnaRewards.Receipt memory _r) internal pure returns (Proof memory p_) {
        (p_.root, p_.account, p_.storageProof) = EtnaRewardProof._proof(
            _r.inbox, keccak256(abi.encode(batchId(_r), uint256(283))), commitment(_r)
        );
    }

    // A later account state preserves the receipt while changing the authenticated state root.
    function newerProof(LibEtnaRewards.Receipt memory _r) internal pure returns (Proof memory p_) {
        p_ = proof(_r);
        bytes[] memory fields = new bytes[](4);
        fields[0] = RLPWriter.writeUint(0);
        fields[1] = RLPWriter.writeUint(1 ether);
        fields[2] = RLPWriter.writeBytes(abi.encodePacked(keccak256(p_.storageProof[0])));
        fields[3] = RLPWriter.writeBytes(abi.encodePacked(keccak256("")));
        bytes[] memory leaf = new bytes[](2);
        leaf[0] =
            RLPWriter.writeBytes(abi.encodePacked(hex"20", keccak256(abi.encodePacked(_r.inbox))));
        leaf[1] = RLPWriter.writeBytes(RLPWriter.writeList(fields));
        p_.account[0] = RLPWriter.writeList(leaf);
        p_.root = keccak256(p_.account[0]);
    }

    function receipt(
        uint64 _batch,
        address _recipient,
        uint256 _amount
    )
        internal
        pure
        returns (LibEtnaRewards.Receipt memory r_)
    {
        // Distinct non-overlapping ranges, including the raw epoch-zero/genesis boundary.
        r_ = LibEtnaRewards.Receipt({
            l1ChainId: 1,
            l2ChainId: 167_000,
            inbox: address(0x1111),
            generation: 0,
            parentHeight: _batch * 10,
            parentHash: bytes32(uint256(_batch) + 1),
            lastHeight: _batch * 10 + 10,
            lastBlockHash: bytes32(uint256(_batch) + 2),
            l2RewardRecipient: _recipient,
            baseFeeAmount: _amount
        });
    }
}

abstract contract EtnaVaultTestBase is Test {
    address internal constant ROOTS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    address internal constant INBOX = address(0x1111);
    address internal constant RECIPIENT = address(0x2222);
    L2FeeVault internal _vault;

    function setUp() public virtual {
        vm.chainId(167_000);
        vm.etch(ROOTS, address(new MockEtnaRoots()).code);
        _vault = new L2FeeVault(1, INBOX);
        // Models EL coinbase credits, which execute no vault code.
        vm.deal(address(_vault), 5 ether);
    }

    function _publish(
        LibEtnaRewards.Receipt memory _r,
        uint256 _timestamp
    )
        internal
        returns (EtnaVaultProof.Proof memory p_)
    {
        p_ = EtnaVaultProof.proof(_r);
        MockEtnaRoots(ROOTS).setRoot(_timestamp, p_.root);
    }

    function _claim(
        LibEtnaRewards.Receipt memory _r,
        uint256 _timestamp,
        EtnaVaultProof.Proof memory _p
    )
        internal
    {
        _vault.claim(_r, _timestamp, _p.account, _p.storageProof);
    }

    function _payload(
        LibEtnaRewards.Receipt memory _r,
        uint256 _timestamp,
        EtnaVaultProof.Proof memory _p
    )
        internal
        pure
        returns (bytes memory payload_)
    {
        return abi.encodeCall(L2FeeVault.claim, (_r, _timestamp, _p.account, _p.storageProof));
    }
}

contract EtnaClaimReceiver {
    L2FeeVault private _vault;
    bytes private _reentry;
    bytes32 private _claimId;
    bool private _reject;
    uint256 public calls;
    bool public observedClaimed;
    bool public nestedSuccess;
    bytes4 public nestedError;

    function configure(
        L2FeeVault _target,
        bytes32 _id,
        bytes memory _payload,
        bool _rejectValue
    )
        external
    {
        _vault = _target;
        _claimId = _id;
        _reentry = _payload;
        _reject = _rejectValue;
    }

    // Adversarial callbacks intentionally execute code to exercise the vault's CEI and lock.
    // solhint-disable-next-line no-complex-fallback
    receive() external payable {
        require(!_reject, "recipient rejected");
        calls++;
        observedClaimed = _vault.claimed(_claimId);
        if (_reentry.length != 0) {
            bytes memory reason;
            (nestedSuccess, reason) = address(_vault).call(_reentry);
            if (reason.length >= 4) nestedError = bytes4(reason);
        }
    }
}

contract ForceEtnaEther {
    constructor() payable { }

    function force(address _target) external {
        selfdestruct(payable(_target));
    }
}
